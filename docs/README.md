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

## Cleanup

To tear down the platform:

```bash
make destroy
```