# apqx-platform Documentation

> **On-Prem GitOps App Platform (Mini)** - A production-ready local development environment showcasing enterprise GitOps practices.

## Quick Start

```bash
# Deploy the complete platform
make up

# Access services
open https://app.<LOCAL-IP>.sslip.io     # Sample application
open https://argocd.<LOCAL-IP>.sslip.io  # ArgoCD GitOps dashboard
open https://rollouts.<LOCAL-IP>.sslip.io/rollouts/  # Argo Rollouts UI

# Cleanup
make destroy
```

## Platform Overview

This platform demonstrates enterprise-grade Kubernetes deployment practices including:

- **GitOps**: ArgoCD with automatic application sync
- **Progressive Delivery**: Argo Rollouts with canary deployments
- **Security**: Kyverno policies, RBAC, image digest pinning
- **Observability**: HPA, PDB, health checks, metrics
- **Networking**: Traefik ingress, Tailscale VPN, cert-manager TLS
- **CI/CD**: GitHub Actions with build, test, scan, and deploy pipeline

## Current Applications

The platform currently manages the following applications via ArgoCD:

| Application | Status | Purpose |
|------------|---------|----------|
| `cert-manager-infrastructure` | ✅ Synced/Healthy | TLS certificate management |
| `platform-ingresses` | ✅ Synced/Healthy | Ingress routing for platform services |
| `sample-app` | ✅ Synced/Healthy | Demo Go web application with progressive delivery |
| `sealed-secrets` | ✅ Synced/Healthy | Encrypted secrets management |
| `tailscale-operator` | ✅ Synced/Healthy | Secure networking and remote access |

## Configuration & Placeholders

### 1. Tailscale Integration (Optional)

For secure remote access via MagicDNS:

```bash
export TF_VAR_tailscale_client_id="<TAILSCALE_OAUTH_CLIENT_ID>"
export TF_VAR_tailscale_client_secret="<TAILSCALE_OAUTH_CLIENT_SECRET>"
```

- **Purpose**: Enables Tailscale operator to create secure tunnel endpoints
- **Access**: Applications available at `https://app-onprem.tail13bd49.ts.net`
- **Optional**: Platform works fully without Tailscale configuration

### 2. Dynamic DNS (sslip.io)

Automatic hostname resolution using your local IP:

```bash
make update-ingress-hosts  # Updates all ingress hosts with current LOCAL_IP
```

- **Hosts**: `https://{app,argocd,rollouts}.<LOCAL-IP>.sslip.io`
- **TLS**: Self-signed certificates via cert-manager
- **Automatic**: Updated during `make up` deployment

### 3. Development Secrets (Local Only)

The platform includes development-only secrets for local testing:

- **File**: `gitops/apps/app/overlays/dev/secret.yaml`
- **Content**: Placeholder database and API keys
- **⚠️ WARNING**: Never use these values in production
- **Production**: Use Sealed Secrets, SOPS, or External Secrets Operator

## Service Access

### Local Access (sslip.io)

```bash
# Application endpoints
curl -k https://app.<LOCAL-IP>.sslip.io/api/status

# Management interfaces
open https://argocd.<LOCAL-IP>.sslip.io      # GitOps dashboard
open https://rollouts.<LOCAL-IP>.sslip.io/rollouts/  # Progressive delivery UI
```

### Port Forwarding (Alternative)

When direct access isn't available:

```bash
make access  # Starts port-forwarding on 8090 (HTTP) and 8443 (HTTPS)

# Then use Host headers:
curl -sk -H "Host: app.<LOCAL-IP>.sslip.io" https://localhost:8443/api/status
```

### ArgoCD Credentials

```bash
# Username: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Progressive Delivery

Switch between deployment strategies:

```bash
# Switch to Argo Rollouts (canary deployments)
make set-deployment-strategy to=rollout

# Switch to standard Kubernetes Deployment
make set-deployment-strategy to=deployment
```

## CI/CD Pipeline

### GitHub Actions Workflow

The platform includes a complete CI/CD pipeline with:

- **✅ Test**: Go unit tests, race detection, coverage reporting
- **✅ Lint**: golangci-lint, hadolint (Dockerfile), yamllint
- **✅ Security**: gosec source scan, trivy image scan
- **✅ Build**: Multi-arch Docker builds with SBOM generation
- **✅ Deploy**: Automated GitOps digest updates

### Local Testing with Act

Test GitHub Actions workflows locally:

```bash
# Run specific job
act --job test --container-architecture linux/amd64

# Run full workflow
act push --container-architecture linux/amd64
```

Configuration is provided via `.actrc` for consistent local testing.

## Operational Notes

### TLS Certificates
- **Type**: Self-signed via cert-manager ClusterIssuer
- **Browser Warning**: Expected - click "Advanced" → "Proceed"
- **curl**: Use `-k` flag to skip certificate verification

### Networking
- **Traefik**: Exposes services on host ports 80/443 via k3d load balancer
- **First Access**: Allow 10-20 seconds for ingress propagation
- **Troubleshooting**: Run `make update-ingress-hosts` if endpoints return 404

### Security Best Practices
- **✅ Image Pinning**: All containers use immutable digests
- **✅ RBAC**: Least-privilege service accounts
- **✅ Network Policies**: Kyverno admission control
- **✅ Secret Management**: No plaintext secrets in Git

## Troubleshooting

### Quick Diagnostic Commands

```bash
# Cluster health
kubectl get nodes -o wide

# GitOps applications
kubectl get applications -n argocd

# Certificate status
kubectl get certificates -A
kubectl describe certificate -n sample-app sample-app-cert

# Ingress routing
kubectl get ingress -A
kubectl describe ingress -n sample-app sample-app

# Application logs
kubectl logs -n sample-app -l app.kubernetes.io/name=sample-app
```

### Platform Reset

```bash
# Complete teardown and rebuild
make destroy
make up
```

## Development Workflow

1. **Make Changes**: Edit code or GitOps manifests
2. **Local Testing**: Use `make dev` for local Go development
3. **CI Validation**: Push triggers GitHub Actions pipeline
4. **Automatic Deployment**: ArgoCD syncs approved changes
5. **Progressive Rollout**: Argo Rollouts manages canary deployments

For more architectural details, see [`architecture.md`](./architecture.md) and [`DECISIONS.md`](./DECISIONS.md).
