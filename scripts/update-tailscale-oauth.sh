#!/bin/bash
# Update Tailscale OAuth credentials script
# Run this if you need to update the OAuth client ID and secret

set -e

echo "🔧 Updating Tailscale OAuth credentials..."

# Check if terraform.tfvars exists
if [[ ! -f "infra/terraform/terraform.tfvars" ]]; then
    echo "❌ terraform.tfvars not found. Please create it first with your OAuth credentials."
    echo "   Copy infra/terraform/terraform.tfvars.example to infra/terraform/terraform.tfvars"
    exit 1
fi

# Re-apply Terraform to update the OAuth secret
echo "📝 Applying Terraform with updated OAuth credentials..."
cd infra/terraform
terraform apply -target=helm_release.tailscale_operator -auto-approve

# Wait a moment for the new secret to propagate
echo "⏳ Waiting for secret propagation..."
sleep 5

# Restart the operator deployment to pick up new credentials
echo "🔄 Restarting Tailscale operator..."
kubectl rollout restart deployment/operator -n tailscale

# Wait for the restart to complete
echo "⏳ Waiting for operator to restart..."
kubectl rollout status deployment/operator -n tailscale --timeout=300s

# Check the operator status
echo "✅ Checking operator status..."
kubectl get pods -n tailscale
kubectl logs -n tailscale deployment/operator --tail=20

echo ""
echo "🎉 Tailscale operator update complete!"
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for the operator to process services"
echo "2. Check for new Tailscale devices in your admin console"
echo "3. Verify service exposure: kubectl get svc -n sample-app sample-app -o yaml | grep tailscale"