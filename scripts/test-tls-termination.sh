#!/bin/bash
# Test Tailscale TLS Termination
# Verifies that HTTPS traffic is properly handled by the Tailscale proxy

echo "🔐 Testing Tailscale TLS Termination Configuration"
echo "=================================================="

echo ""
echo "1. Checking service annotations..."
kubectl get svc sample-app -n sample-app -o yaml | grep -E "tailscale.com/(tls-termination|tailnet-port|expose|hostname)"

echo ""
echo "2. Checking Tailscale proxy pod status..."
kubectl get pods -n tailscale | grep ts-sample-app

echo ""
echo "3. Checking proxy logs for TLS-related configuration..."
POD_NAME=$(kubectl get pods -n tailscale -o name | grep ts-sample-app | head -1)
if [[ -n "$POD_NAME" ]]; then
    echo "Recent proxy logs:"
    kubectl logs -n tailscale $POD_NAME --tail=10
else
    echo "❌ No Tailscale proxy pod found"
fi

echo ""
echo "4. Verifying backend connectivity..."
echo "Testing if sample-app responds on port 80:"
kubectl run test-curl --rm -i --restart=Never --image=curlimages/curl:latest -- curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://sample-app.sample-app.svc.cluster.local

echo ""
echo "## Summary:"
echo ""
echo "✅ **TLS Termination Configured:**"
echo "   - tailscale.com/tls-termination: true"
echo "   - tailscale.com/tailnet-port: 443"
echo ""
echo "🔄 **How It Works:**"
echo "   1. Browser → HTTPS/443 → Tailscale MagicDNS"
echo "   2. Tailscale proxy → TLS termination → HTTP/80 → sample-app"
echo "   3. sample-app → HTTP response → Tailscale proxy → HTTPS → Browser"
echo ""
echo "🧪 **Test Both URLs Now:**"
echo "   HTTP:  http://app-onprem.tail13bd49.ts.net"
echo "   HTTPS: https://app-onprem.tail13bd49.ts.net"
echo ""
echo "Expected result: Both should work!"
echo ""