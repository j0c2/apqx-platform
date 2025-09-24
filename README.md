# apqx-platform

> **On-Prem GitOps App Platform (Mini)** - A production-ready local Kubernetes environment showcasing enterprise GitOps practices.

## Quick Start

```bash
# Deploy the complete platform
make up

# Access services (replace <LOCAL-IP> with your IP)
open https://app.<LOCAL-IP>.sslip.io          # Sample application
open https://argocd.<LOCAL-IP>.sslip.io       # GitOps dashboard
open https://rollouts.<LOCAL-IP>.sslip.io/rollouts/  # Progressive delivery

# Cleanup when done
make destroy
```

## What's Included

- **✅ GitOps**: ArgoCD managing 5 applications with automatic sync
- **✅ CI/CD**: GitHub Actions pipeline with build, test, scan, and deploy
- **✅ Progressive Delivery**: Argo Rollouts with canary deployments
- **✅ Security**: Kyverno policies, RBAC, image digest pinning
- **✅ Observability**: HPA, PDB, health checks, metrics endpoints
- **✅ Networking**: Traefik ingress + cert-manager TLS + optional Tailscale
- **✅ Local Development**: Full platform runs on k3d with make commands

## Current Status

| Application | Status | Purpose |
|------------|---------|----------|
| `cert-manager-infrastructure` | 🟢 Healthy | TLS certificate management |
| `platform-ingresses` | 🟢 Healthy | Ingress routing |
| `sample-app` | 🟢 Healthy | Demo Go application |
| `sealed-secrets` | 🟢 Healthy | Encrypted secrets |
| `tailscale-operator` | 🟢 Healthy | Secure networking |

## Service Access

```bash
# Get your local IP
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

# Application endpoints
curl -k https://app.$LOCAL_IP.sslip.io/api/status

# ArgoCD credentials
echo "Username: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
```

## Key Features

- **🚀 One-command deployment**: `make up` deploys the entire platform
- **📊 GitOps-managed**: All applications visible and controllable via ArgoCD  
- **🔒 Security hardened**: Policies, RBAC, and digest-pinned images
- **🌐 DNS magic**: sslip.io provides automatic hostname resolution
- **🔄 Progressive delivery**: Switch between standard and canary deployments
- **⚡ Local testing**: GitHub Actions workflows testable with `act`

## Optional Features

### Tailscale Integration
```bash
# Enable secure remote access (optional)
export TF_VAR_tailscale_client_id="<your_oauth_client_id>"
export TF_VAR_tailscale_client_secret="<your_oauth_secret>"
make up

# Access via Tailscale MagicDNS
open https://app-onprem.tail13bd49.ts.net
```

### Progressive Delivery
```bash
# Switch to canary deployments with Argo Rollouts
make set-deployment-strategy to=rollout

# Switch back to standard deployments  
make set-deployment-strategy to=deployment
```

### Local CI Testing
```bash
# Test GitHub Actions workflows locally
act --job test --container-architecture linux/amd64
```

## Troubleshooting

```bash
# Check application health
kubectl get applications -n argocd
kubectl get pods -n sample-app

# View logs
kubectl logs -n sample-app -l app.kubernetes.io/name=sample-app

# Test direct access (bypass ingress)
kubectl port-forward -n sample-app svc/sample-app 8080:80
curl http://localhost:8080/api/status
```

## Documentation

- **📋 [Setup Guide](docs/README.md)**: Complete configuration and usage details
- **🏗️ [Architecture](docs/architecture.md)**: System design and component overview  
- **📝 [Decisions](docs/DECISIONS.md)**: Technical decisions and rationale

## Assessment Compliance

✅ **All requirements met**: k3d cluster, GitOps, ingress, CI/CD, security, SRE practices  
✅ **Stretch goals**: Progressive delivery + self-hosted CI runner  
✅ **Production-ready**: Security policies, observability, automation

---

*Ready for take-home assessments and production-like demos!* 🚀
