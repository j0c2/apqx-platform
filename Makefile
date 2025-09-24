# ====================================================================================
#                           Configuration Variables
# ====================================================================================

# Docker & Kubernetes
CLUSTER_NAME    := k3d-onprem
KUBECONFIG_PATH := ~/.kube/config

# Terraform
TERRAFORM_DIR := infra/terraform

# Colors for output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m # No Color

# ====================================================================================
#                                Phony Targets
# ====================================================================================

.PHONY: help up destroy quick-destroy diff set-deployment-strategy access stop-access update-ingress-hosts ensure-access argocd rollouts app open-uis dev test lint security kyverno-test bootstrap check-deps install-deps clean runner-up runner-down runner-config runner-status


# ====================================================================================
#                                Help & Information
# ====================================================================================

.DEFAULT_GOAL := help

## help: Show this help message
help:
	@echo "$(BLUE)apqx-platform - On-Prem GitOps App Platform$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC)"
	@echo "  make [target]"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk -F':.*##' '/^[a-zA-Z_-]+:.*?##/ {printf "  $(YELLOW)%-25s$(NC) %s\\n", $$1, $$2}' $(MAKEFILE_LIST) | sort


# ====================================================================================
#                            Platform Lifecycle
# ====================================================================================

## up: Deploy the complete platform and open service UIs
up: bootstrap
	@echo "$(BLUE)🚀 Deploying complete apqx-platform...$(NC)"
	@echo "$(BLUE)Step 1: Checking Terraform configuration...$(NC)"
	@if [ -f $(TERRAFORM_DIR)/terraform.tfvars ]; then \
	    echo "$(GREEN)✓ Using terraform.tfvars for configuration$(NC)"; \
	else \
	    echo "$(YELLOW)ℹ️  No terraform.tfvars found - using defaults (Tailscale disabled)$(NC)"; \
	fi
	@echo "$(BLUE)Step 2: Deploying infrastructure via Terraform...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) apply -auto-approve
	@echo "$(GREEN)✅ Infrastructure deployed$(NC)"
	@echo "$(BLUE)Step 3: Waiting for ArgoCD to be ready...$(NC)"
	@kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
	@echo "$(GREEN)✅ ArgoCD is ready$(NC)"
	@echo "$(BLUE)Step 4: Deploying GitOps application definitions...$(NC)"
	@kubectl apply -f gitops/apps/management/cert-manager-infrastructure.yaml
	@kubectl apply -f gitops/apps/management/ingresses.yaml
	@kubectl apply -f gitops/apps/argocd/kyverno-app.yaml
	@kubectl apply -f gitops/apps/app/application.yaml || echo "$(YELLOW)Sample app already exists$(NC)"
	@echo "$(BLUE)Step 5: Updating ingress hosts with current IP...$(NC)"
	@$(MAKE) update-ingress-hosts
	@echo "$(BLUE)Step 6: Ensuring service access and port-forwarding...$(NC)"
	@$(MAKE) ensure-access
	@echo "$(BLUE)Step 7: Testing service connectivity...$(NC)"
	@echo "🧪 Testing service endpoint connectivity..."
	@LOCAL_IP=$$($(MAKE) --no-print-directory _get-local-ip); \
	curl -s -o /dev/null -w "%{http_code}" -H "Host: app.$$LOCAL_IP.sslip.io" http://localhost:8090/api/status | grep -q "200" && echo "  $(GREEN)✓ Sample App$(NC)" || echo "  $(RED)✗ Sample App$(NC)"; \
	curl -s -o /dev/null -w "%{http_code}" -H "Host: argocd.$$LOCAL_IP.sslip.io" http://localhost:8090/ | grep -q "200" && echo "  $(GREEN)✓ ArgoCD$(NC)" || echo "  $(RED)✗ ArgoCD$(NC)"; \
	curl -s -o /dev/null -w "%{http_code}" -H "Host: rollouts.$$LOCAL_IP.sslip.io" http://localhost:8090/rollouts/ | grep -q "200" && echo "  $(GREEN)✓ Argo Rollouts$(NC)" || echo "  $(RED)✗ Argo Rollouts$(NC)"
	@echo "$(GREEN)✅ All services are accessible$(NC)"
	@echo "$(BLUE)Step 8: Platform Status Summary...$(NC)"
	@echo ""
	@echo "$(BLUE)📊 apqx-platform Status$(NC)"
	@echo "========================"
	@k3d cluster list | grep -q '$(CLUSTER_NAME)' && echo "$(GREEN)✓ k3d cluster: $(CLUSTER_NAME)$(NC)" || echo "$(RED)✗ k3d cluster not found$(NC)"
	@echo ""
	@echo "$(GREEN)🕰 GitOps Applications:$(NC)"
	@kubectl get applications -n argocd --no-headers | awk '{printf "  %s: %s (%s)\n", $$1, $$2, $$3}' || echo "  $(RED)✗ ArgoCD applications not available$(NC)"
	@echo ""
	@echo "$(GREEN)🌐 Service URLs:$(NC)"
	@LOCAL_IP=$$($(MAKE) --no-print-directory _get-local-ip) ; \
	echo "  🚀 Sample App:    https://app.$$LOCAL_IP.sslip.io"; \
	echo "  🎛️  ArgoCD:          https://argocd.$$LOCAL_IP.sslip.io"; \
	echo "  📊 Argo Rollouts:   https://rollouts.$$LOCAL_IP.sslip.io/rollouts/"; \
	echo "  🔒 Tailscale App: https://app-onprem.tail13bd49.ts.net";
	@echo ""
	@echo "$(YELLOW)🔑 ArgoCD Login:$(NC)" \
	&& echo "  Username: admin" \
	&& echo "  Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo 'not-ready-yet')"
	@echo "$(BLUE)Step 9: Opening service UIs...$(NC)"
	@$(MAKE) open-uis
	@echo "$(GREEN)🎉 Platform deployment complete!$(NC)"

## destroy: Tear down the complete platform with confirmation
destroy:
	@echo "$(YELLOW)This will destroy everything including the k3d cluster.$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || { echo "Cancelled"; exit 1; }
	@$(MAKE) quick-destroy

## quick-destroy: Tear down the complete platform without confirmation
quick-destroy:
	@echo "$(BLUE)🗑️  Tearing down platform...$(NC)"
	@pkill -f "kubectl port-forward.*traefik" 2>/dev/null || true
	@terraform -chdir=$(TERRAFORM_DIR) destroy -auto-approve || true
	@k3d cluster delete $(CLUSTER_NAME) 2>/dev/null || true
	@echo "$(GREEN)✅ Teardown finished$(NC)"


# ====================================================================================
#                             Deployment & GitOps
# ====================================================================================

## set-deployment-strategy: Set app deployment strategy (e.g., make set-deployment-strategy to=rollout)
set-deployment-strategy:
	@if [ "$(to)" = "deployment" ]; then \
	    echo "$(BLUE)Switching to standard Deployment...$(NC)"; \
	    kubectl patch application -n argocd sample-app --type merge -p '{"spec":{"source":{"path":"gitops/apps/app/base"}}}'; \
	    echo "$(GREEN)✓ Switched. Syncing ArgoCD application...$(NC)"; \
	    kubectl patch application -n argocd sample-app -p '{"operation":{"sync":{}}}' --type merge || true; \
	elif [ "$(to)" = "rollout" ]; then \
	    echo "$(BLUE)Switching to Argo Rollout...$(NC)"; \
	    kubectl patch application -n argocd sample-app --type merge -p '{"spec":{"source":{"path":"gitops/apps/app/overlays/dev"}}}'; \
	    echo "$(GREEN)✓ Switched. Syncing ArgoCD application...$(NC)"; \
	    kubectl patch application -n argocd sample-app -p '{"operation":{"sync":{}}}' --type merge || true; \
	else \
	    echo "$(RED)Invalid strategy. Use 'deployment' or 'rollout' for the 'to' argument.$(NC)"; \
	fi

## diff: Show differences between Git and cluster state
diff:
	@echo "$(BLUE)Checking GitOps application drift...$(NC)"
	@kubectl get applications -n argocd -o wide


# ====================================================================================
#                             Service Access & Status
# ====================================================================================



## open-uis: Open all service UIs in the browser
open-uis: argocd rollouts app

## argocd: Open the ArgoCD UI
argocd: ensure-access
	@$(MAKE) --no-print-directory _open-url name="ArgoCD" host="argocd"

## rollouts: Open the Argo Rollouts UI
rollouts: ensure-access
	@$(MAKE) --no-print-directory _open-url name="Argo Rollouts" host="rollouts" path="/rollouts/"

## app: Open the Sample App UI
app: ensure-access
	@$(MAKE) --no-print-directory _open-url name="Sample App" host="app"


# ====================================================================================
#                             Development & Testing
# ====================================================================================

## dev: Start local Go development environment
dev:
	@echo "$(BLUE)Starting local Go development server...$(NC)"
	@cd app && go mod tidy && go run main.go

## test: Run all Go tests and generate coverage report
test:
	@echo "$(BLUE)Running Go tests...$(NC)"
	@cd app && go test -v -race -coverprofile=coverage.out ./... && go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)✓ Tests complete. Report: app/coverage.html$(NC)"


## lint: Lint all code and configurations
lint:
	@echo "$(BLUE)Linting all code...$(NC)"
	@golangci-lint run ./app/... && echo "$(GREEN)✓ Go lint passed$(NC)"
	@yamllint -d relaxed gitops/ && echo "$(GREEN)✓ YAML lint passed$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) fmt -check -recursive && echo "$(GREEN)✓ Terraform format check passed$(NC)"

## security: Run security scans
security:
	@echo "$(BLUE)Running security scans...$(NC)"
	@gosec ./app/... || echo "$(YELLOW)Gosec found issues$(NC)"
	@trivy fs . --severity HIGH,CRITICAL || echo "$(YELLOW)Trivy found issues$(NC)"

## kyverno-test: Run Kyverno admission policy tests
kyverno-test:
	@echo "$(BLUE)Testing Kyverno admission policies...$(NC)"
	@kubectl get clusterpolicy -o wide || true
	@printf "  deny mutable tag (nginx:latest): "; kubectl create deployment kyv-digest-deny -n sample-app --image=nginx:latest --dry-run=server >/dev/null 2>&1 && echo "$(RED)FAIL$(NC)" || echo "$(GREEN)OK$(NC)"
	@printf "  require probes/resources: "; kubectl create deployment kyv-probes-res -n sample-app --image=nginx@sha256:8b1e8d4a6f2c6f55f3c8d9a9ce7b3f2b5b0a4f0b0d867bd5e9e79f0d0b8a1f14 --dry-run=server >/dev/null 2>&1 && echo "$(RED)FAIL$(NC)" || echo "$(GREEN)OK$(NC)"


# ====================================================================================
#                             Dependencies & Cleanup
# ====================================================================================

## bootstrap: Check and install all required dependencies
bootstrap: check-deps install-deps
	@echo "$(GREEN)✓ Bootstrap complete - ready to deploy!$(NC)"

## check-deps: Check for required dependencies
check-deps:
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)✗ Docker not found$(NC)"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)✗ Terraform not found$(NC)"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)✗ kubectl not found$(NC)"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "$(RED)✗ Helm not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All core dependencies found.$(NC)"

## install-deps: Install missing dependencies using Homebrew
install-deps:
	@echo "$(BLUE)Installing any missing dependencies via Homebrew...$(NC)"
	@command -v brew >/dev/null 2>&1 || { echo "$(RED)Homebrew is required to auto-install dependencies$(NC)"; exit 1; }
	@brew install k3d terraform kubectl helm golangci-lint yamllint gosec trivy
	@echo "$(GREEN)✓ Dependencies installed.$(NC)"

## clean: Clean up temporary files and build caches
clean:
	@echo "$(BLUE)Cleaning up temporary files...$(NC)"
	@rm -f $(TERRAFORM_DIR)/tfplan $(TERRAFORM_DIR)/.terraform.lock.hcl
	@rm -rf $(TERRAFORM_DIR)/.terraform/ app/coverage.*
	@go clean -cache -modcache -testcache >/dev/null 2>&1
	@echo "$(GREEN)✓ Cleanup complete.$(NC)"


# ====================================================================================
#                             Self-Hosted Runner
# ====================================================================================

## runner-up: Start the self-hosted GitHub Actions runner
runner-up:
	@cd runner && ./run.sh

## runner-down: Stop the self-hosted GitHub Actions runner
runner-down:
	@pkill -f "Runner.Listener" || true

## runner-config: Configure the self-hosted runner
runner-config:
	@echo "$(YELLOW)Enter your GitHub PAT with 'repo' and 'workflow' scopes below:$(NC)"
	@read -s GITHUB_PAT; \
	cd runner && ./config.sh --url https://github.com/j0c2/apqx-platform --token $$GITHUB_PAT --unattended

## runner-status: Check the status of the self-hosted runner
runner-status:
	@pgrep -f "Runner.Listener" > /dev/null && echo "$(GREEN)Runner is running.$(NC)" || echo "$(RED)Runner is not running.$(NC)"


# ====================================================================================
#                           Internal Helper Targets
# ====================================================================================

## ensure-access: Ensure Traefik port-forwarding is active
ensure-access:
	@if ! pgrep -f "kubectl port-forward.*traefik" > /dev/null; then \
	    echo "$(YELLOW)Port forwarding not active. Starting now...$(NC)"; \
	    $(MAKE) --no-print-directory access; \
	fi

## access: Start Traefik port-forwarding in the background
access:
	@echo "$(BLUE)Starting Traefik port-forwarding on ports 8090 (HTTP) and 8443 (HTTPS)...$(NC)"
	@nohup kubectl port-forward -n kube-system svc/traefik 8090:80 >/dev/null 2>&1 &
	@nohup kubectl port-forward -n kube-system svc/traefik 8443:443 >/dev/null 2>&1 &
	@sleep 2 # Allow time for port-forward to establish

## stop-access: Stop Traefik port-forwarding
stop-access:
	@echo "$(BLUE)Stopping Traefik port-forwarding...$(NC)"
	@pkill -f "kubectl port-forward.*traefik" 2>/dev/null || true
	@echo "$(GREEN)✓ Port forwarding stopped.$(NC)"

## update-ingress-hosts: Update /etc/hosts with service domains
update-ingress-hosts:
	@echo "$(BLUE)Updating Ingress hosts file...$(NC)"
	@chmod +x scripts/setup/update-ingress-hosts.sh
	@scripts/setup/update-ingress-hosts.sh

# Internal helper to get the local IP for sslip.io (same logic as update-ingress-hosts.sh)
_get-local-ip:
	@if [ -n "$(LOCAL_IP)" ]; then \
	    echo "$(LOCAL_IP)"; \
	else \
	    LOCAL_IP=$$(( \
	        (route -n get default 2>/dev/null | awk '/interface:/{print $$2}' | xargs -I{} ipconfig getifaddr {} 2>/dev/null) || \
	        (ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($$i=="src") {print $$(i+1); exit}}') || \
	        (ifconfig | awk '/inet /{print $$2}' | grep -Ev '^(127\.|169\.254\.|100\.)' | head -1) \
	    ) 2>/dev/null); \
	    if [ -n "$$LOCAL_IP" ]; then \
	        echo "$$LOCAL_IP"; \
	    else \
	        echo "localhost"; \
	    fi; \
	fi


# Internal helper to open a URL
_open-url:
	@LOCAL_IP=$$($(MAKE) --no-print-directory _get-local-ip); \
	URL="https://$(host).$$LOCAL_IP.sslip.io$(path)"; \
	echo "$(GREEN)Opening $(name) at $$URL...$(NC)"; \
	open "$$URL" || true

