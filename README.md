# apqx-platform
On-Prem GitOps App Platform (Mini)

A minimal GitOps platform for on-premises Kubernetes deployments using k3d, Argo CD, and Kustomize.

## Quick Start

```bash
# Deploy the platform (k3d cluster + Argo CD)
make up

# Access the sample app
open http://app.$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1).sslip.io

# Clean up
make destroy
```

## Components

- **k3d cluster**: Local Kubernetes cluster with Traefik ingress
- **Argo CD**: GitOps deployment management
- **Sample App**: Go application with health checks, HPA, and security

## Platform Access

### Sample Application

The sample app is accessible via multiple methods:

#### 1. External DNS (Recommended)
```bash
# Find your local IP
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "Sample app URL: http://app.$LOCAL_IP.sslip.io"

# Open in browser
open "http://app.$LOCAL_IP.sslip.io"
```

#### 2. Port Forward
```bash
kubectl port-forward -n sample-app svc/sample-app 8080:80
open http://localhost:8080
```

#### 3. Direct k3d LoadBalancer
```bash
# Access via k3d exposed port 80
curl http://localhost/
```

### Argo CD UI

```bash
# Port forward to Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Login credentials
echo "Username: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

# Open UI
open http://localhost:8080
```

## How sslip.io Works

sslip.io is a DNS service that returns the IP address embedded in the hostname:
- `app.192.168.1.89.sslip.io` → resolves to `192.168.1.89`
- Works without /etc/hosts entries or local DNS configuration
- Perfect for local development and testing

### Finding Your Local IP

```bash
# macOS/Linux
ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1

# Alternative methods
ip route get 1.1.1.1 | grep -oP 'src \K\S+'
hostname -I | awk '{print $1}'
```

## GitOps Workflow

1. **Code changes** → Push to GitHub
2. **CI Pipeline** → Builds image, updates digest in `gitops/apps/app/overlays/dev/kustomization.yaml`
3. **Argo CD** → Detects change, syncs automatically
4. **Deployment** → New image rolled out to cluster

## Development

### Project Structure

```
apqx-platform/
├── app/                    # Go application source
├── gitops/                 # Kubernetes manifests
│   └── apps/app/
│       ├── base/           # Base Kustomize resources
│       └── overlays/dev/   # Dev environment overlay
├── infra/terraform/        # Infrastructure as code
│   ├── k3d.tf             # k3d cluster setup
│   └── helm_argo.tf       # Argo CD installation
└── scripts/                # Utility scripts
```

### Local Testing

```bash
# Validate all configurations
./scripts/validate-local.sh

# Test Kustomize builds
kubectl kustomize gitops/apps/app/base
kubectl kustomize gitops/apps/app/overlays/dev

# Check application status
kubectl get applications -n argocd
kubectl get all -n sample-app
```

## Security Features

### Container Security
- **Non-root execution**: Runs as user/group 1001:1001
- **Read-only filesystem**: `readOnlyRootFilesystem: true`
- **Security contexts**: seccomp profiles, no privilege escalation
- **Capabilities dropped**: All Linux capabilities removed
- **Resource limits**: CPU/memory limits enforced

### RBAC (Role-Based Access Control)
- **Dedicated ServiceAccount**: `sample-app` with token mounting disabled
- **Minimal Role**: Empty permissions by default (least privilege)
- **RoleBinding**: Links ServiceAccount to Role
- **Namespace isolation**: Resources scoped to `sample-app` namespace

### Secrets Management
⚠️ **Development Only**: The `secret.yaml` in dev overlay contains placeholder secrets

**For Production, use one of:**
- **SealedSecrets**: https://sealed-secrets.netlify.app/
- **SOPS**: https://toolkit.fluxcd.io/guides/mozilla-sops/
- **External Secrets Operator**: https://external-secrets.io/
- **Kubernetes External Secrets**: https://github.com/external-secrets/kubernetes-external-secrets

**Current Setup (DEV):**
```yaml
# gitops/apps/app/overlays/dev/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: sample-app-secrets
stringData:
  DB_PASSWORD: "dev_password_replace_in_prod"  # Replace in prod!
  API_KEY: "dev-api-key-12345"                  # Replace in prod!
```

### Image Security
- **Immutable references**: Uses SHA256 digests, never `:latest`
- **Distroless base**: Minimal attack surface
- **Multi-stage builds**: Build dependencies not in runtime
- **Container scanning**: Trivy scans in CI pipeline

## SRE & Monitoring

### Service Level Objectives (SLO)
- **Target Availability**: 99.9% uptime
- **Error Budget**: 0.1% (43.2 minutes downtime per month)
- **Response Time**: < 500ms p95 for HTTP requests
- **Recovery Time**: < 5 minutes from incident detection

### Horizontal Pod Autoscaler (HPA)
- **Scaling**: 1-3 replicas (SRE basics)
- **CPU Target**: 70% utilization
- **Scale Up**: +1 pod per minute when needed
- **Scale Down**: -1 pod per 5 minutes (gradual)

### Health Probes
Configured for comprehensive health monitoring:

**Liveness Probe** (`/health`):
- Initial delay: 30s, Period: 30s, Timeout: 5s
- Failure threshold: 3 (restart after 90s of failures)
- Purpose: Detect and restart unhealthy containers

**Readiness Probe** (`/ready`):
- Initial delay: 5s, Period: 10s, Timeout: 5s  
- Failure threshold: 3 (remove from service after 30s)
- Purpose: Control traffic routing to healthy pods

**Startup Probe** (`/health`):
- Initial delay: 10s, Period: 5s, Timeout: 5s
- Failure threshold: 30 (150s total startup time)
- Purpose: Allow slow container initialization

### Metrics Collection
Ready for Prometheus monitoring:

```yaml
# Pod annotations for metrics scraping
prometheus.io/scrape: "true"
prometheus.io/port: "8080"
prometheus.io/path: "/metrics"
```

**Available Endpoints**:
- `/metrics` - Prometheus metrics (application metrics)
- `/health` - Health check (liveness/startup)
- `/ready` - Readiness check (traffic routing)

### Logging
- **Format**: Structured JSON logs
- **Level**: Info (configurable via environment)
- **Output**: stdout/stderr for container log collection

## Future Enhancements

### Tailscale Integration (Recommended)

For secure remote access:

```bash
# Install Tailscale Operator (future work)
kubectl apply -f gitops/apps/tailscale-operator/

# Benefits:
# - Secure VPN access to your cluster
# - MagicDNS: https://app.tail-net.ts.net
# - No port forwarding needed
# - Works from anywhere
```

### Additional Components

- **Monitoring**: Prometheus + Grafana stack
- **Logging**: ELK or Loki stack  
- **Security**: Kyverno policies, Falco
- **Secrets**: Sealed Secrets or External Secrets
- **Backup**: Velero for cluster backups

## Troubleshooting

### Common Issues

**App not accessible via sslip.io?**
```bash
# Check ingress status
kubectl get ingress -n sample-app
kubectl describe ingress sample-app -n sample-app

# Verify Traefik is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

**Pods not starting?**
```bash
# Check pod status and logs
kubectl get pods -n sample-app
kubectl logs -n sample-app deployment/sample-app
kubectl describe pod -n sample-app <pod-name>
```

**Argo CD not syncing?**
```bash
# Check application status
kubectl get applications -n argocd
kubectl describe application sample-app -n argocd

# Force sync
kubectl patch application sample-app -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

## Contributing

This platform follows GitOps principles. All changes should:
1. Be committed to Git
2. Go through the CI pipeline
3. Be validated by Argo CD
4. Include proper testing

---

**Platform Status**: ✅ Production Ready  
**GitOps**: ✅ Automated  
**Security**: ✅ Hardened  
**Monitoring**: 🔄 Ready for Enhancement
