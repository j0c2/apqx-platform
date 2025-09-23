# Tailscale OAuth Setup Guide

This guide explains how to configure Tailscale OAuth credentials for the Tailscale K8s Operator to enable MagicDNS access to your services.

## Prerequisites

1. **Tailscale Account**: You need a Tailscale account and access to your tailnet
2. **Admin Access**: Admin privileges in your Tailscale tailnet to create OAuth clients

## Step 1: Create OAuth Application

1. Go to the [Tailscale Admin Console](https://login.tailscale.com/admin/)
2. Navigate to **Settings** > **OAuth clients**
3. Click **Add OAuth client**
4. Configure the OAuth client:
   - **Name**: `k8s-operator-<cluster-name>` (e.g., `k8s-operator-onprem`)
   - **Write access**: Check the following scopes:
     - `devices` - Allow the operator to register devices
     - `routes` - Allow the operator to advertise routes

5. Click **Generate client**
6. **Save the credentials** immediately:
   - **Client ID**: Copy this value
   - **Client Secret**: Copy this value (only shown once!)

## Step 2: Configure Terraform Variables

Create a `terraform.tfvars` file in `infra/terraform/` with your credentials:

```hcl
# Tailscale OAuth Configuration
tailscale_tailnet            = "yourname.gmail.com"  # Your tailnet name
tailscale_oauth_client_id     = "k1234567890abcdef"   # Your OAuth client ID
tailscale_oauth_client_secret = "ts_oauth_client_secret_1234567890abcdef"  # Your OAuth client secret
```

**Security Note**: Never commit `terraform.tfvars` to git as it contains sensitive credentials.

## Step 3: Apply Terraform Configuration

```bash
cd infra/terraform
terraform plan   # Verify the configuration
terraform apply  # Install Tailscale operator
```

## Step 4: Verify Installation

```bash
# Check operator pods
kubectl get pods -n tailscale

# Check operator logs
kubectl logs -n tailscale deployment/tailscale-operator

# Verify service exposure (after a few minutes)
kubectl get svc -n sample-app sample-app -o yaml | grep tailscale
```

## Step 5: Access via MagicDNS

Once the operator is running and has processed the service annotations:

1. **Check Tailscale devices**: In the Tailscale admin console, you should see a new device named `app-onprem`
2. **Access the service**: The service will be available at `https://app-onprem.<tailnet>.ts.net`
   - Example: `https://app-onprem.yourname-gmail.ts.net`

## Troubleshooting

### Common Issues

**OAuth authentication failed**:
```bash
# Check operator logs for authentication errors
kubectl logs -n tailscale deployment/tailscale-operator
```

**Service not appearing in Tailscale**:
```bash
# Verify service annotations
kubectl describe svc -n sample-app sample-app

# Check for tailscale proxy pod
kubectl get pods -n sample-app -l app=tailscale
```

**MagicDNS not resolving**:
- Ensure MagicDNS is enabled in your Tailscale tailnet settings
- Check that your tailnet has HTTPS certificates enabled
- Verify you're connected to the Tailscale network

### Required Permissions

The OAuth client needs these minimum permissions:
- **Devices**: To register the service as a Tailscale device
- **Routes**: To advertise service routes (if using subnet routing)

## Security Considerations

1. **OAuth Scope**: Use minimal required scopes for security
2. **Credential Storage**: Store OAuth credentials securely (never in git)
3. **Network Access**: Services exposed via Tailscale are accessible to your entire tailnet
4. **Certificate Management**: Tailscale automatically provides HTTPS certificates for MagicDNS

## Alternative: Manual Installation

If you prefer not to use OAuth credentials in Terraform, you can install the operator manually:

```bash
# Install via kubectl
kubectl apply -f https://github.com/tailscale/tailscale/releases/latest/download/tailscale-operator.yaml

# Create secret with OAuth credentials
kubectl create secret generic operator-oauth --from-literal=client_id=<CLIENT_ID> --from-literal=client_secret=<CLIENT_SECRET> -n tailscale
```

---

**Next Steps**: Once Tailscale is configured, your services with `tailscale.com/expose: "true"` annotations will be automatically accessible via MagicDNS!