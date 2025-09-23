# Automation targets for deploying and managing the On-Prem GitOps App Platform

.PHONY: help up destroy quick-destroy verify-deployment validate plan diff sync status clean dev test lint security bootstrap check-deps install-deps runner-config runner-up runner-down runner-status argocd rollouts app tailscale-apply update-ingress-hosts

# Default target
.DEFAULT_GOAL := help

# Variables
TERRAFORM_DIR := infra/terraform
CLUSTER_NAME := apqx-platform
KUBECONFIG_PATH := ~/.kube/config

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

## help: Show this help message
help:
	@echo "$(BLUE)apqx-platform - On-Prem GitOps App Platform$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Quick start:$(NC)"
	@echo "  1. make check-deps    # Check required dependencies"
	@echo "  2. make bootstrap     # Install missing dependencies"  
	@echo "  3. make up           # Deploy the complete platform"
	@echo "  4. make status       # Check deployment status"
	@echo "  5. make quick-destroy # Fast cleanup (for development)"
	@echo "  6. make destroy      # Safe cleanup with confirmation"

## check-deps: Check if required dependencies are installed
check-deps:
	@echo "$(BLUE)Checking required dependencies...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)✗ Docker is required but not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Docker$(NC)"
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)✗ Terraform is required but not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Terraform$(NC)"
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)✗ kubectl is required but not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ kubectl$(NC)"
	@command -v helm >/dev/null 2>&1 || { echo "$(RED)✗ Helm is required but not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Helm$(NC)"
	@command -v k3d >/dev/null 2>&1 || { echo "$(YELLOW)⚠ k3d not found, will be installed automatically$(NC)"; }
	@command -v tailscale >/dev/null 2>&1 || { echo "$(YELLOW)⚠ Tailscale not found, please install manually$(NC)"; }
	@echo "$(GREEN)✓ Dependency check complete$(NC)"

## install-deps: Install missing dependencies (macOS)
install-deps:
	@echo "$(BLUE)Installing missing dependencies...$(NC)"
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "$(RED)Homebrew is required for automatic dependency installation$(NC)"; \
		exit 1; \
	fi
	@command -v docker >/dev/null 2>&1 || { echo "$(YELLOW)Installing Docker...$(NC)"; brew install --cask docker; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(YELLOW)Installing Terraform...$(NC)"; brew install terraform; }
	@command -v kubectl >/dev/null 2>&1 || { echo "$(YELLOW)Installing kubectl...$(NC)"; brew install kubectl; }
	@command -v helm >/dev/null 2>&1 || { echo "$(YELLOW)Installing Helm...$(NC)"; brew install helm; }
	@command -v k3d >/dev/null 2>&1 || { echo "$(YELLOW)Installing k3d...$(NC)"; brew install k3d; }
	@echo "$(GREEN)✓ Dependencies installed$(NC)"
	@echo "$(YELLOW)Note: Please install Tailscale manually from https://tailscale.com/download$(NC)"

## bootstrap: Full bootstrap process including dependency check
bootstrap: check-deps
	@echo "$(BLUE)Bootstrapping apqx-platform...$(NC)"
	@if ! tailscale status >/dev/null 2>&1; then \
		echo "$(YELLOW)⚠ Tailscale not running. Please run 'tailscale login' first$(NC)"; \
	else \
		echo "$(GREEN)✓ Tailscale is running$(NC)"; \
	fi
	@echo "$(GREEN)✓ Bootstrap complete - ready to deploy!$(NC)"

## up: Deploy the complete platform (cluster + apps + GitOps)
up:
	@echo "$(BLUE)🚀 Deploying complete apqx-platform...$(NC)"
	@echo "$(BLUE)Step 1: Terraform infrastructure deployment...$(NC)"
	terraform -chdir=infra/terraform init
	terraform -chdir=infra/terraform apply -auto-approve
	@echo "$(GREEN)✅ Infrastructure deployed$(NC)"
	@echo "kubectl context:"
	@kubectl config current-context
	@echo "$(BLUE)Step 2: Waiting for ArgoCD to be ready...$(NC)"
	@kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
	@echo "$(GREEN)✅ ArgoCD is ready$(NC)"
	@echo "$(BLUE)Step 3: Deploying GitOps applications...$(NC)"
	@kubectl apply -f gitops/apps/management/cert-manager-infrastructure.yaml
	@kubectl apply -f gitops/apps/management/ingresses.yaml
	@kubectl apply -f gitops/apps/app/application.yaml || echo "$(YELLOW)Sample app application may already exist$(NC)"
	@echo "$(BLUE)Step 4: Applying ClusterIssuer and dynamic sslip.io Certificates...$(NC)"
	@kubectl apply -f gitops/infrastructure/cert-manager/cluster-issuer-selfsigned.yaml
	@kubectl get ns sample-app >/dev/null 2>&1 || kubectl create ns sample-app
	@LOCAL_IP=$$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $$2}' | head -1); \
	echo "Using LOCAL_IP=$$LOCAL_IP for sslip.io certs"; \
	sed -E 's/app\.[0-9\.-]+\.sslip\.io/app.'"$$LOCAL_IP"'.sslip.io/g; s/argocd\.[0-9\.-]+\.sslip\.io/argocd.'"$$LOCAL_IP"'.sslip.io/g; s/rollouts\.[0-9\.-]+\.sslip\.io/rollouts.'"$$LOCAL_IP"'.sslip.io/g' gitops/infrastructure/cert-manager/certificates-sslip.yaml | kubectl apply -f -
	@echo "$(BLUE)Step 5: Waiting for certificates to be Ready...$(NC)"
	@kubectl wait --for=condition=Ready certificate/app-sslip -n sample-app --timeout=120s || true
	@kubectl wait --for=condition=Ready certificate/argocd-sslip -n argocd --timeout=120s || true
	@kubectl wait --for=condition=Ready certificate/rollouts-sslip -n argo-rollouts --timeout=120s || true
	@echo "$(BLUE)Step 6: Updating Ingress hosts to current LOCAL_IP...$(NC)"
	@chmod +x scripts/setup/update-ingress-hosts.sh || true
	@scripts/setup/update-ingress-hosts.sh
	@echo "$(BLUE)Step 7: Waiting briefly for Traefik to pick up routes...$(NC)"
	@sleep 15
	@echo "$(GREEN)✅ Platform deployment complete$(NC)"
	@echo "$(BLUE)Step 8: Running verification...$(NC)"
	@$(MAKE) verify-deployment

## destroy: Tear down the complete platform (complete cleanup)
destroy:
	@echo "$(BLUE)🗑️  Complete platform teardown...$(NC)"
	@echo "$(YELLOW)This will destroy everything including k3d cluster$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || { echo "Cancelled"; exit 1; }
	@echo "$(BLUE)Stopping any port forwards...$(NC)"
	@pkill -f "kubectl port-forward.*traefik" 2>/dev/null || true
	@echo "$(BLUE)Destroying Terraform resources...$(NC)"
	@terraform -chdir=infra/terraform destroy -auto-approve || true
	@echo "$(BLUE)Force delete k3d cluster if it exists...$(NC)"
	@k3d cluster delete k3d-onprem 2>/dev/null || true
	@echo "$(BLUE)Cleaning up Terraform state...$(NC)"
	@rm -f infra/terraform/.terraform.lock.hcl
	@rm -rf infra/terraform/.terraform/
	@rm -f infra/terraform/tfplan
	@echo "$(BLUE)Cleaning Docker system...$(NC)"
	@docker system prune -f >/dev/null 2>&1 || true
	@echo "$(GREEN)✅ Complete teardown finished$(NC)"

## quick-destroy: Fast teardown without confirmation (for development)
quick-destroy:
	@echo "$(BLUE)🗑️  Quick platform teardown...$(NC)"
	@echo "$(BLUE)Stopping any port forwards...$(NC)"
	@pkill -f "kubectl port-forward.*traefik" 2>/dev/null || true
	@echo "$(BLUE)Destroying Terraform resources...$(NC)"
	@terraform -chdir=infra/terraform destroy -auto-approve || true
	@echo "$(BLUE)Force delete k3d cluster if it exists...$(NC)"
	@k3d cluster delete k3d-onprem 2>/dev/null || true
	@echo "$(GREEN)✅ Quick teardown finished$(NC)"

## validate: Validate all configurations without applying
validate: check-deps
	@echo "$(BLUE)Validating configurations...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) init -backend=false
	@terraform -chdir=$(TERRAFORM_DIR) validate
	@echo "$(GREEN)✓ Terraform validation passed$(NC)"
	@find gitops/ -name "*.yaml" -exec kubectl --dry-run=client apply -f {} \; >/dev/null 2>&1
	@echo "$(GREEN)✓ Kubernetes manifests validation passed$(NC)"
	@echo "$(GREEN)✓ All validations passed$(NC)"

## tailscale-apply: Apply only tailscale namespace, secret, and operator release\n tailscale-apply:\n\t@terraform -chdir=infra/terraform apply -target=kubernetes_namespace.tailscale -target=kubernetes_secret.tailscale_operator_oauth -target=helm_release.tailscale_operator -auto-approve\n\n## plan: Show Terraform deployment plan
plan: check-deps
	@echo "$(BLUE)Generating deployment plan...$(NC)"
	@terraform -chdir=$(TERRAFORM_DIR) init
	@terraform -chdir=$(TERRAFORM_DIR) plan

## diff: Show differences between Git and cluster state
diff:
	@echo "$(BLUE)Checking GitOps drift...$(NC)"
	@if ! kubectl get namespace argocd >/dev/null 2>&1; then \
		echo "$(YELLOW)Argo CD not deployed yet$(NC)"; \
	else \
		kubectl get applications -n argocd -o wide; \
		echo "$(GREEN)Use Argo CD UI for detailed diff information$(NC)"; \
	fi

## sync: Force sync of GitOps applications
sync:
	@echo "$(BLUE)Syncing GitOps applications...$(NC)"
	@if ! kubectl get namespace argocd >/dev/null 2>&1; then \
		echo "$(YELLOW)Argo CD not deployed yet$(NC)"; \
	else \
		kubectl patch application -n argocd sample-app -p '{"operation":{"sync":{}}}' --type merge || true; \
		kubectl patch application -n argocd root-app -p '{"operation":{"sync":{}}}' --type merge || true; \
		echo "$(GREEN)✓ Sync initiated$(NC)"; \
	fi

## verify-deployment: Verify complete platform deployment
verify-deployment:
	@echo "$(BLUE)🔍 Verifying platform deployment...$(NC)"
	@echo "$(BLUE)Checking cluster status...$(NC)"
	@kubectl get nodes -o wide
	@echo "$(BLUE)Checking ArgoCD applications...$(NC)"
	@kubectl get applications -n argocd
	@echo "$(BLUE)Checking certificates...$(NC)"
	@kubectl get certificates -A
	@echo "$(BLUE)Checking ingresses...$(NC)"
	@kubectl get ingress -A
	@echo "$(BLUE)Ensuring sample app is Ready...$(NC)"
	@kubectl rollout status -n sample-app deploy/sample-app --timeout=120s || true
	@echo "$(BLUE)Testing HTTPS endpoints...$(NC)"
	@TRAEFIK_IP=$$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	if [ -n "$$TRAEFIK_IP" ]; then \
		ATTEMPTS=5; SLEEP=5; \
		for i in $$(seq 1 $$ATTEMPTS); do \
		  echo "Attempt $$i/$${ATTEMPTS}..."; \
		  ok1=ok; ok2=ok; ok3=ok; \
		  curl -kI https://app.$$TRAEFIK_IP.sslip.io --max-time 10 >/dev/null 2>&1 || ok1=; \
		  curl -kI https://argocd.$$TRAEFIK_IP.sslip.io --max-time 10 >/dev/null 2>&1 || ok2=; \
		  curl -kI https://rollouts.$$TRAEFIK_IP.sslip.io/rollouts/ --max-time 10 >/dev/null 2>&1 || ok3=; \
		  [ -n "$$ok1$$ok2$$ok3" ] && break; \
		  sleep $$SLEEP; \
		done; \
		[ -n "$$ok1" ] && echo "$(GREEN)✅ Sample App HTTPS working$(NC)" || echo "$(YELLOW)⚠ Sample App HTTPS not ready$(NC)"; \
		[ -n "$$ok2" ] && echo "$(GREEN)✅ ArgoCD HTTPS working$(NC)" || echo "$(YELLOW)⚠ ArgoCD HTTPS not ready$(NC)"; \
		[ -n "$$ok3" ] && echo "$(GREEN)✅ Rollouts HTTPS working$(NC)" || echo "$(YELLOW)⚠ Rollouts HTTPS not ready$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Traefik IP not available yet$(NC)"; \
	fi
	@echo "$(GREEN)🎯 Verification complete - check above for any issues$(NC)"

## status: Show platform status
status:
	@echo "$(BLUE)apqx-platform Status$(NC)"
	@echo "===================="
	@echo ""
	@if k3d cluster list | grep -q k3d-onprem; then \
		echo "$(GREEN)✓ k3d cluster: k3d-onprem$(NC)"; \
	else \
		echo "$(RED)✗ k3d cluster not found$(NC)"; \
	fi
	@echo ""
	@if kubectl get nodes >/dev/null 2>&1; then \
		echo "$(GREEN)Kubernetes Nodes:$(NC)"; \
		kubectl get nodes -o wide; \
		echo ""; \
	fi
	@if kubectl get namespace argocd >/dev/null 2>&1; then \
		echo "$(GREEN)Argo CD Applications:$(NC)"; \
		kubectl get applications -n argocd -o wide || echo "$(YELLOW)No applications found$(NC)"; \
		echo ""; \
	fi
	@if kubectl get namespace kyverno >/dev/null 2>&1; then \
		echo "$(GREEN)Kyverno Policies:$(NC)"; \
		kubectl get clusterpolicies || echo "$(YELLOW)No policies found$(NC)"; \
		echo ""; \
	fi
	@if kubectl get certificates -A >/dev/null 2>&1; then \
		echo "$(GREEN)TLS Certificates:$(NC)"; \
		kubectl get certificates -A; \
		echo ""; \
	fi
	@echo "$(GREEN)Service URLs (HTTPS with TLS):$(NC)"
	@TRAEFIK_IP=$$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost"); \
	echo "🚀 Sample App: https://app.$$TRAEFIK_IP.sslip.io"; \
	echo "🎛️  ArgoCD: https://argocd.$$TRAEFIK_IP.sslip.io"; \
	echo "📊 Argo Rollouts: https://rollouts.$$TRAEFIK_IP.sslip.io/rollouts/"; \
	echo "🔒 Sample App (Tailscale): https://app-onprem.tail13bd49.ts.net"; \
	echo ""; \
	echo "$(YELLOW)💡 ArgoCD Login:$(NC)"; \
	echo "   Username: admin"; \
	echo "   Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo 'not-ready-yet')"

## dev: Start local development environment
dev:
	@echo "$(BLUE)Starting development environment...$(NC)"
	@cd app && go mod tidy
	@cd app && go run main.go

## test: Run all tests
test:
	@echo "$(BLUE)Running tests...$(NC)"
	@cd app && go test -v -race -coverprofile=coverage.out ./...
	@cd app && go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)✓ Tests complete - see app/coverage.html$(NC)"

## lint: Lint all code and configurations
lint:
	@echo "$(BLUE)Linting code and configurations...$(NC)"
	@command -v golangci-lint >/dev/null 2>&1 || { echo "$(YELLOW)Installing golangci-lint...$(NC)"; go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; }
	@cd app && golangci-lint run
	@echo "$(GREEN)✓ Go linting passed$(NC)"
	@command -v yamllint >/dev/null 2>&1 || { echo "$(YELLOW)Installing yamllint...$(NC)"; pip install yamllint; }
	@yamllint -d relaxed gitops/ || echo "$(YELLOW)⚠ YAML linting warnings$(NC)"
	@echo "$(GREEN)✓ YAML linting complete$(NC)"
	@cd $(TERRAFORM_DIR) && terraform fmt -check -recursive
	@echo "$(GREEN)✓ Terraform formatting check passed$(NC)"

## security: Run security scans
security:
	@echo "$(BLUE)Running security scans...$(NC)"
	@command -v gosec >/dev/null 2>&1 || { echo "$(YELLOW)Installing gosec...$(NC)"; go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest; }
	@cd app && gosec ./... || echo "$(YELLOW)⚠ Security scan completed with warnings$(NC)"
	@command -v trivy >/dev/null 2>&1 || { echo "$(YELLOW)Installing trivy...$(NC)"; brew install trivy; }
	@trivy fs . --severity HIGH,CRITICAL || echo "$(YELLOW)⚠ Trivy scan completed with warnings$(NC)"
	@echo "$(GREEN)✓ Security scans complete$(NC)"

## clean: Clean up temporary files and caches
clean:
	@echo "$(BLUE)Cleaning up...$(NC)"
	@rm -f $(TERRAFORM_DIR)/tfplan
	@rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	@rm -rf $(TERRAFORM_DIR)/.terraform/
	@rm -f app/coverage.out app/coverage.html
	@go clean -cache -modcache -testcache >/dev/null 2>&1 || true
	@docker system prune -f >/dev/null 2>&1 || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

## logs: Show platform logs
logs:
	@echo "$(BLUE)Platform logs...$(NC)"
	@if kubectl get namespace argocd >/dev/null 2>&1; then \
		echo "$(GREEN)Argo CD Controller logs:$(NC)"; \
		kubectl logs -n argocd -l app.kubernetes.io/component=application-controller --tail=50; \
	fi

## runner-up: Start self-hosted GitHub Actions runner
runner-up:
	@echo "$(BLUE)Starting self-hosted GitHub Actions runner...$(NC)"
	@if [ ! -f runner/.runner ]; then \
		echo "$(RED)✗ Runner not configured. Please run runner configuration first:$(NC)"; \
		echo "$(YELLOW)  1. cd runner$(NC)"; \
		echo "$(YELLOW)  2. ./config.sh --url https://github.com/j0c2/apqx-platform --token YOUR_PAT$(NC)"; \
		echo "$(YELLOW)  3. Run 'make runner-up' again$(NC)"; \
		exit 1; \
	fi
	@if pgrep -f "Runner.Listener" > /dev/null; then \
		echo "$(YELLOW)⚠ Runner is already running$(NC)"; \
	else \
		echo "$(GREEN)Starting GitHub Actions runner...$(NC)"; \
		nohup bash -c 'cd runner && ./run.sh' > runner/runner.log 2>&1 & \
		sleep 2; \
		if pgrep -f "Runner.Listener" > /dev/null; then \
			echo "$(GREEN)✓ Runner started - check GitHub repo Settings > Actions > Runners$(NC)"; \
		else \
			echo "$(RED)✗ Failed to start runner - check runner/runner.log$(NC)"; \
		fi; \
	fi

## runner-down: Stop self-hosted GitHub Actions runner
runner-down:
	@echo "$(BLUE)Stopping self-hosted GitHub Actions runner...$(NC)"
	@if pgrep -f "Runner.Listener" > /dev/null; then \
		echo "$(GREEN)Stopping runner processes...$(NC)"; \
		pkill -f "Runner.Listener" || true; \
		pkill -f "run-helper.sh" || true; \
		sleep 2; \
		if pgrep -f "Runner.Listener" > /dev/null; then \
			echo "$(YELLOW)⚠ Force killing runner processes...$(NC)"; \
			pkill -9 -f "Runner.Listener" || true; \
		fi; \
		echo "$(GREEN)✓ Runner stopped$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Runner is not running$(NC)"; \
	fi

## runner-config: Configure self-hosted runner (one-time setup)
runner-config:
	@echo "$(BLUE)Configuring self-hosted GitHub Actions runner...$(NC)"
	@if [ -f runner/.runner ]; then \
		echo "$(YELLOW)⚠ Runner already configured. To reconfigure, run 'cd runner && ./config.sh remove' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Instructions for runner configuration:$(NC)"
	@echo "  1. Create a GitHub PAT with 'repo' and 'workflow' scopes"
	@echo "  2. cd runner"
	@echo "  3. ./config.sh --url https://github.com/j0c2/apqx-platform --token YOUR_PAT"
	@echo "  4. Follow prompts (press Enter for defaults)"
	@echo "  5. Run 'make runner-up' to start the runner"
	@echo ""
	@echo "$(YELLOW)Note: Replace YOUR_PAT with your actual GitHub Personal Access Token$(NC)"

## runner-status: Check runner status
runner-status:
	@echo "$(BLUE)Self-hosted runner status:$(NC)"
	@if [ -f runner/.runner ]; then \
		echo "$(GREEN)Runner Configuration:$(NC)"; \
		grep -E "agentName|gitHubUrl" runner/.runner | sed 's/^/  /'; \
		echo ""; \
	else \
		echo "$(RED)✗ Runner not configured$(NC)"; \
	fi
	@if pgrep -f "Runner.Listener" > /dev/null; then \
		echo "$(GREEN)✓ Runner Process: Running (PID: $$(pgrep -f 'Runner.Listener'))$(NC)"; \
		echo "$(GREEN)Runner Logs: runner/runner.log$(NC)"; \
	@else \
		echo "$(RED)✗ Runner Process: Not running$(NC)"; \
	fi

## argocd: Open ArgoCD UI in browser
argocd:
	@echo "$(BLUE)Opening ArgoCD UI...$(NC)"
	@TRAEFIK_IP=$$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	if [ -n "$$TRAEFIK_IP" ]; then \
		echo "$(GREEN)🎛️  ArgoCD URL: https://argocd.$$TRAEFIK_IP.sslip.io$(NC)"; \
		open "https://argocd.$$TRAEFIK_IP.sslip.io" || true; \
	else \
		echo "$(YELLOW)Traefik IP not available, using localhost$(NC)"; \
		echo "$(GREEN)🎛️  ArgoCD URL: https://argocd.localhost$(NC)"; \
		open "https://argocd.localhost" || true; \
	fi
	@echo "$(YELLOW)Username: admin$(NC)"
	@ARGO_PASS=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "password-not-found"); \
	echo "$(YELLOW)Password: $$ARGO_PASS$(NC)"

## rollouts: Open Argo Rollouts UI in browser
rollouts:
	@echo "$(BLUE)Opening Argo Rollouts UI...$(NC)"
	@TRAEFIK_IP=$$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	if [ -n "$$TRAEFIK_IP" ]; then \
		echo "$(GREEN)📊 Rollouts URL: https://rollouts.$$TRAEFIK_IP.sslip.io$(NC)"; \
		open "https://rollouts.$$TRAEFIK_IP.sslip.io" || true; \
	else \
		echo "$(YELLOW)Traefik IP not available, using localhost$(NC)"; \
		echo "$(GREEN)📊 Rollouts URL: https://rollouts.localhost$(NC)"; \
		open "https://rollouts.localhost" || true; \
	fi

## app: Open Sample App in browser
app:
	@echo "$(BLUE)Opening Sample App...$(NC)"
	@TRAEFIK_IP=$$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	if [ -n "$$TRAEFIK_IP" ]; then \
		echo "$(GREEN)🚀 App URL: https://app.$$TRAEFIK_IP.sslip.io$(NC)"; \
		open "https://app.$$TRAEFIK_IP.sslip.io" || true; \
	else \
		echo "$(YELLOW)Traefik IP not available, using localhost$(NC)"; \
		echo "$(GREEN)🚀 App URL: https://app.localhost$(NC)"; \
		open "https://app.localhost" || true; \
	fi

# Local access targets for k3d environment
.PHONY: access start-access stop-access test-access

access: ## Start local platform access via port forwarding
	@echo "🚀 Starting platform access..."
	@echo "Note: This will start port forwards on 8090 (HTTP) and 8443 (HTTPS)"
	@echo "If ports are in use, please stop conflicting services first"
	@pkill -f "kubectl port-forward.*traefik" 2>/dev/null || true
	@kubectl port-forward -n kube-system svc/traefik 8090:80 &
	@kubectl port-forward -n kube-system svc/traefik 8443:443 &
	@sleep 2
	@TRAEFIK_IP=$$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}') && \
	echo "" && \
	echo "🌐 Platform Access URLs:" && \
	echo "======================================" && \
	echo "📱 Sample App:     http://localhost:8090 (Host: app.$$TRAEFIK_IP.sslip.io)" && \
	echo "🎯 ArgoCD:         http://localhost:8090 (Host: argocd.$$TRAEFIK_IP.sslip.io)" && \
	echo "📊 Argo Rollouts:  http://localhost:8090 (Host: rollouts.$$TRAEFIK_IP.sslip.io)" && \
	echo "" && \
	echo "🔐 HTTPS Access:" && \
	echo "📱 Sample App:     https://localhost:8443 (Host: app.$$TRAEFIK_IP.sslip.io)" && \
	echo "🎯 ArgoCD:         https://localhost:8443 (Host: argocd.$$TRAEFIK_IP.sslip.io)" && \
	echo "📊 Argo Rollouts:  https://localhost:8443 (Host: rollouts.$$TRAEFIK_IP.sslip.io)" && \
	echo "" && \
	echo "💡 Add to /etc/hosts for easier browser access:" && \
	echo "127.0.0.1 app.$$TRAEFIK_IP.sslip.io" && \
	echo "127.0.0.1 argocd.$$TRAEFIK_IP.sslip.io" && \
	echo "127.0.0.1 rollouts.$$TRAEFIK_IP.sslip.io" && \
	echo "" && \
	echo "✅ Port forwards active. Run 'make stop-access' to stop."

stop-access: ## Stop platform access port forwards
	@echo "🛑 Stopping platform access..."
	@pkill -f "kubectl port-forward.*traefik" 2>/dev/null || true
	@echo "✅ Port forwards stopped"

update-ingress-hosts: ## Update ingress hosts to current LOCAL_IP\n\t@chmod +x scripts/setup/update-ingress-hosts.sh || true\n\t@scripts/setup/update-ingress-hosts.sh\n\n\n test-access: ## Test platform access via localhost
	@echo "🧪 Testing platform access via localhost..."
	@TRAEFIK_IP=$$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}') && \
	echo "Testing Sample App..." && \
	curl -s -H "Host: app.$$TRAEFIK_IP.sslip.io" http://localhost:8090/api/status >/dev/null 2>&1 && echo "✅ Sample App accessible" || echo "❌ Sample App test failed" && \
	echo "Testing ArgoCD..." && \
	curl -s -H "Host: argocd.$$TRAEFIK_IP.sslip.io" http://localhost:8090/ >/dev/null 2>&1 && echo "✅ ArgoCD accessible" || echo "❌ ArgoCD test failed" && \
	echo "Testing Argo Rollouts..." && \
	curl -s -H "Host: rollouts.$$TRAEFIK_IP.sslip.io" http://localhost:8090/rollouts/ >/dev/null 2>&1 && echo "✅ Argo Rollouts accessible" || echo "❌ Rollouts test failed"

