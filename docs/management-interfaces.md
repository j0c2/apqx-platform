# Management Interfaces via Traefik

This document explains how ArgoCD and Argo Rollouts are configured to be accessible through Traefik ingress.

## Overview

Both ArgoCD and Argo Rollouts dashboards are now accessible via Traefik ingress with sslip.io DNS and self-signed TLS certificates. This eliminates the need for manual port forwarding and provides a consistent access pattern across all platform services.

## Configuration Changes

### 1. ArgoCD Configuration Updates

**File**: `infra/terraform/values/argocd-values.yaml`
- Enabled insecure mode for ingress compatibility
- Configured proper base path handling (`/argocd`)
- Disabled built-in ingress (managed via GitOps)

### 2. Argo Rollouts Dashboard

**File**: `infra/terraform/values/rollouts-values.yaml`
- Enabled the dashboard component
- Configured ClusterIP service on port 3100

### 3. Ingress Resources

**ArgoCD Ingress**: `gitops/apps/management/argocd-ingress.yaml`
- Host: `argocd.localhost` and fallback path `/argocd`
- TLS certificate via cert-manager
- Traefik-specific annotations for proper routing

**Argo Rollouts Ingress**: `gitops/apps/management/argo-rollouts-ingress.yaml`
- Host: `rollouts.localhost` and fallback path `/rollouts`
- TLS certificate via cert-manager
- Routes to dashboard service on port 3100

### 4. TLS Certificates

Self-signed certificates managed by cert-manager:
- `argocd-certificate.yaml` - Certificate for ArgoCD
- `argo-rollouts-certificate.yaml` - Certificate for Argo Rollouts

Both use the `selfsigned-cluster-issuer` ClusterIssuer.

## Access Methods

### Via sslip.io (Recommended)

Replace `<TRAEFIK_IP>` with your actual LoadBalancer IP:

```bash
# Get Traefik IP
TRAEFIK_IP=$(kubectl get service -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access URLs
echo "ArgoCD: https://argocd.$TRAEFIK_IP.sslip.io"
echo "Argo Rollouts: https://rollouts.$TRAEFIK_IP.sslip.io"
echo "Sample App: https://app.$TRAEFIK_IP.sslip.io"
```

### Via localhost (requires /etc/hosts)

Add these entries to `/etc/hosts`:
```
<TRAEFIK_IP> argocd.localhost
<TRAEFIK_IP> rollouts.localhost  
<TRAEFIK_IP> app.localhost
```

Then access:
- ArgoCD: `https://argocd.localhost`
- Argo Rollouts: `https://rollouts.localhost`
- Sample App: `https://app.localhost`

### Via Makefile Commands

Convenient commands to open interfaces directly:

```bash
make argocd     # Opens ArgoCD UI and shows login credentials
make rollouts   # Opens Argo Rollouts dashboard
make app        # Opens Sample App
make status     # Shows all URLs and platform status
```

## ArgoCD Login

**Username**: `admin`

**Password**: Retrieved via:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Or simply run `make argocd` which displays the credentials automatically.

## GitOps Management

The ingress resources are managed as an ArgoCD application:

**Application**: `management-ingresses`
**Path**: `gitops/apps/management/`
**Auto-sync**: Enabled

This ensures ingress configurations are managed through GitOps and automatically deployed/updated.

## Architecture Benefits

1. **Consistent Access**: All services accessible via same ingress pattern
2. **No Port Forwarding**: Eliminates need for manual `kubectl port-forward`  
3. **TLS Everywhere**: All interfaces secured with TLS certificates
4. **GitOps Managed**: Ingress configurations tracked in Git
5. **Makefile Integration**: Quick access commands for development workflow

## Troubleshooting

### Check Ingress Status
```bash
kubectl get ingress -A
```

### Verify Certificate Status
```bash
kubectl describe certificate -n argocd argocd-tls
kubectl describe certificate -n argo-rollouts argo-rollouts-tls
```

### Check Service Status
```bash
kubectl get svc -n argocd argocd-server
kubectl get svc -n argo-rollouts argo-rollouts-dashboard
```

### View Traefik Routes
```bash
kubectl get ingressroutes -A  # If using Traefik CRDs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

## Next Steps

After deploying these changes:

1. **Terraform Apply**: Run `make up` to deploy ArgoCD/Rollouts configuration changes
2. **ArgoCD Sync**: The management-ingresses app should auto-sync the ingress resources
3. **Verify Access**: Use `make status` to get URLs and `make argocd`/`make rollouts` to test
4. **Update DNS**: Configure local DNS or /etc/hosts if using localhost pattern

The platform now provides a unified, web-accessible interface for all management tools via Traefik ingress.