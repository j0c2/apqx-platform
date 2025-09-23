#!/bin/bash
# Tailscale Diagnostics Script
# Identifies and helps fix Tailscale integration issues

set -e

echo "🔍 Tailscale Integration Diagnostics"
echo "===================================="
echo ""

# Check if Tailscale namespace exists
echo "1. Checking Tailscale namespace..."
if kubectl get namespace tailscale > /dev/null 2>&1; then
    echo "   ✅ tailscale namespace exists"
else
    echo "   ❌ tailscale namespace missing"
    exit 1
fi

# Check operator deployment status
echo ""
echo "2. Checking operator deployment..."
kubectl get deployment operator -n tailscale
echo ""

# Check operator pods status
echo "3. Checking operator pods..."
kubectl get pods -n tailscale
echo ""

# Check OAuth secret
echo "4. Checking OAuth secret..."
if kubectl get secret operator-oauth -n tailscale > /dev/null 2>&1; then
    echo "   ✅ operator-oauth secret exists"
    # Decode and show client ID (safe to show)
    CLIENT_ID=$(kubectl get secret operator-oauth -n tailscale -o jsonpath='{.data.client_id}' | base64 -d)
    echo "   📋 Client ID: $CLIENT_ID"
    # Don't show the secret, just confirm it exists
    if [[ -n $(kubectl get secret operator-oauth -n tailscale -o jsonpath='{.data.client_secret}') ]]; then
        echo "   ✅ Client secret is configured"
    else
        echo "   ❌ Client secret is missing"
    fi
else
    echo "   ❌ operator-oauth secret missing"
fi

echo ""
echo "5. Checking operator logs..."
echo "Recent operator logs:"
kubectl logs -n tailscale deployment/operator --tail=10 || echo "   ⚠️  Could not retrieve logs"

echo ""
echo "6. Checking sample-app service for Tailscale annotations..."
if kubectl get svc sample-app -n sample-app -o yaml | grep -q "tailscale.com/expose"; then
    echo "   ✅ Service has tailscale.com/expose annotation"
    kubectl get svc sample-app -n sample-app -o yaml | grep "tailscale.com"
else
    echo "   ❌ Service missing Tailscale annotations"
fi

echo ""
echo "## Diagnosis Summary:"
echo ""

# Check for common issues
POD_STATUS=$(kubectl get pods -n tailscale -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
RESTART_COUNT=$(kubectl get pods -n tailscale -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")

if [[ "$POD_STATUS" == "Running" ]]; then
    echo "✅ Tailscale operator is running normally"
    echo ""
    echo "Next steps:"
    echo "1. Wait 2-3 minutes for operator to process services"
    echo "2. Check Tailscale admin console for new devices"
    echo "3. Access via: https://app-onprem.<tailnet>.ts.net"
elif [[ "$RESTART_COUNT" -gt 3 ]]; then
    echo "❌ Tailscale operator is crash looping (restarts: $RESTART_COUNT)"
    echo ""
    echo "🔧 Most likely issue: OAuth client permissions"
    echo ""
    echo "Fix steps:"
    echo "1. Go to: https://login.tailscale.com/admin/settings/oauth"
    echo "2. Edit your OAuth client"
    echo "3. Enable ALL write permissions:"
    echo "   - ✅ devices:write"
    echo "   - ✅ routes:write"
    echo "   - ✅ acls:write"
    echo "   - ✅ all (if available)"
    echo "4. Save changes"
    echo "5. Run: kubectl rollout restart deployment/operator -n tailscale"
else
    echo "⚠️  Tailscale operator status unclear"
    echo "Pod status: $POD_STATUS"
    echo "Restart count: $RESTART_COUNT"
fi

echo ""
echo "For more details, check: docs/TAILSCALE_SETUP.md"