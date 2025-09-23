#!/bin/bash
# Test Tailscale Integration Fix
# Run this after updating your Tailscale ACL

echo "🧪 Testing Tailscale Integration Fix..."
echo "====================================="

echo ""
echo "1. Restarting Tailscale operator..."
kubectl rollout restart deployment/operator -n tailscale

echo ""
echo "2. Waiting for operator to restart..."
kubectl rollout status deployment/operator -n tailscale --timeout=120s

echo ""
echo "3. Checking operator status..."
kubectl get pods -n tailscale

echo ""
echo "4. Checking recent operator logs..."
sleep 5
echo "Recent logs (last 15 lines):"
kubectl logs -n tailscale deployment/operator --tail=15

echo ""
echo "5. Checking service annotations..."
if kubectl get svc sample-app -n sample-app -o yaml | grep -q "tailscale.com/expose"; then
    echo "✅ Service has Tailscale annotations"
    kubectl get svc sample-app -n sample-app -o yaml | grep "tailscale.com"
else
    echo "❌ Service missing Tailscale annotations"
fi

echo ""
echo "## Results Summary:"

# Check if operator is running successfully
POD_STATUS=$(kubectl get pods -n tailscale -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
RESTART_COUNT=$(kubectl get pods -n tailscale -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")

if [[ "$POD_STATUS" == "Running" ]]; then
    echo "✅ SUCCESS: Tailscale operator is running!"
    echo ""
    echo "Next steps:"
    echo "1. Wait 2-3 minutes for service processing"
    echo "2. Check Tailscale admin console for 'app-onprem' device"
    echo "3. Access your app via: https://app-onprem.<tailnet>.ts.net"
    echo "4. Run './scripts/tailscale-diagnostics.sh' for detailed status"
elif kubectl logs -n tailscale deployment/operator --tail=5 2>/dev/null | grep -q "tag:k8s-operator"; then
    echo "❌ STILL FAILING: ACL tag issue not resolved"
    echo ""
    echo "Action needed:"
    echo "1. Double-check your Tailscale ACL includes:"
    echo "   \"tagOwners\": {\"tag:k8s-operator\": [\"autogroup:admin\"]}"
    echo "2. Make sure you saved the ACL policy"
    echo "3. Go to: https://login.tailscale.com/admin/acls"
else
    echo "⚠️  Unknown status - check logs above"
fi

echo ""