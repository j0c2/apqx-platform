# apqx-platform Documentation

Bootstrap documentation for the On-Prem GitOps App Platform (Mini).

## Required Tools

Before running the platform, ensure you have the following tools installed:

- **Docker** - Container runtime for k3d and local development
- **Terraform** - Infrastructure as Code for cluster provisioning
- **kubectl** - Kubernetes command-line tool
- **Helm** - Kubernetes package manager (Helm 3.x)
- **Tailscale** - Secure networking (must be logged in)

## Bootstrap Instructions

1. **Clone and setup**:
   ```bash
   git clone <repository-url>
   cd apqx-platform
   ```

2. **Configure Tailscale** (required):
   ```bash
   tailscale login
   # Ensure you're connected to your tailnet
   tailscale status
   ```

3. **Deploy the platform**:
   ```bash
   make up
   ```

4. **Validate deployment**:
   ```bash
   make validate
   ```

## Expected URLs

Once deployed, the application will be available at:

- **Local Access**: `http://app.<LOCAL-IP>.sslip.io/`
  - Replace `<LOCAL-IP>` with your machine's local IP address
  - Uses sslip.io for local DNS resolution

- **Tailscale Access**: `https://app<name>.<tailnet>.net`
  - Replace `<name>` with your application identifier
  - Replace `<tailnet>` with your Tailscale tailnet name
  - Uses Tailscale MagicDNS for secure remote access

## Configuration Placeholders

The following placeholders need to be configured:

| Placeholder | Description | Location |
|-------------|-------------|----------|
| `<TAILSCALE_OAUTH_CLIENT_ID>` | Tailscale OAuth client ID | `infra/terraform/helm_tailscale.tf` |
| `<TAILSCALE_OAUTH_CLIENT_SECRET>` | Tailscale OAuth client secret | `infra/terraform/helm_tailscale.tf` |
| `<LOCAL-IP>` | Your machine's local IP address | Auto-detected during deployment |
| `<tailnet>` | Your Tailscale tailnet name | Auto-detected from Tailscale status |

## GitOps Workflow

This platform uses a **immutable base + overlay** pattern for GitOps:

- **Base manifests** (`gitops/apps/app/base/`): Immutable, never modified by CI
- **Overlay** (`gitops/apps/app/overlays/dev/`): Updated by CI with image digests
- **Platform controllers**: Managed via Helm chart versions, not automated updates

### CI/CD Flow

1. **Code push** triggers CI pipeline
2. **Build & push** creates container image with immutable digest
3. **GitOps update** modifies overlay with new digest using kustomize
4. **Argo CD** auto-syncs from overlay to deploy new version

## GitHub Actions Setup

For the CI/CD workflows to work properly, ensure your repository has:

1. **Actions permissions**: Go to Settings → Actions → General → Workflow permissions
   - Select "Read and write permissions"
   - Check "Allow GitHub Actions to create and approve pull requests"

2. **Container registry access**: GitHub Container Registry (GHCR) access is automatic

## Validation

After CI runs on main, validate the deployment:

### Check GitOps Sync
```bash
# Verify Argo CD picked up the new digest
kubectl -n argocd get applications

# Check application deployment
kubectl -n default describe deploy/sample-app
# Should show: image: ghcr.io/<repo>/sample-app@sha256:...
```

### Verify Application Access
- **Local**: `http://app.<LOCAL-IP>.sslip.io/`
- **Tailscale**: `https://app<name>.<tailnet>.net`

### Check Overlay Structure
```bash
# Verify overlay applies correctly
cd gitops/apps/app/overlays/dev
kustomize build .
```

## Cleanup

To tear down the platform:

```bash
make destroy
```
