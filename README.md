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

- **Non-root containers** with read-only filesystems
- **Security contexts** with seccomp profiles
- **Resource limits** and health checks
- **Service accounts** with minimal permissions
- **Network policies** ready (implement as needed)

## Scaling & Monitoring

- **Horizontal Pod Autoscaler**: 2-10 replicas based on CPU/memory
- **Health checks**: Liveness, readiness, and startup probes
- **Metrics**: Ready for Prometheus scraping
- **Logging**: Structured JSON logs

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
