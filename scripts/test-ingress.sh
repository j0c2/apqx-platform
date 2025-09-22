#!/bin/bash

# Test ingress configuration and sslip.io access
# Verifies that the platform is accessible via external DNS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing Ingress & DNS Configuration ===${NC}"

# Find local IP
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
HOSTNAME="app.$LOCAL_IP.sslip.io"

echo -e "\n${BLUE}Local IP Address:${NC} $LOCAL_IP"
echo -e "${BLUE}Test Hostname:${NC} $HOSTNAME"

# Test DNS resolution
echo -e "\n${BLUE}Testing sslip.io DNS resolution...${NC}"
RESOLVED_IP=$(dig +short "$HOSTNAME" 2>/dev/null || nslookup "$HOSTNAME" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || echo "")

if [[ "$RESOLVED_IP" == "$LOCAL_IP" ]]; then
    echo -e "${GREEN}✓ DNS Resolution: $HOSTNAME → $RESOLVED_IP${NC}"
else
    echo -e "${RED}✗ DNS Resolution Failed${NC}"
    echo -e "${YELLOW}Expected: $LOCAL_IP, Got: $RESOLVED_IP${NC}"
fi

# Check Traefik status
echo -e "\n${BLUE}Checking Traefik status...${NC}"
if kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers | grep -q "Running"; then
    echo -e "${GREEN}✓ Traefik is running${NC}"
else
    echo -e "${RED}✗ Traefik is not running${NC}"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
fi

# Check ingress status
echo -e "\n${BLUE}Checking ingress configuration...${NC}"
if kubectl get ingress -n sample-app sample-app >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Ingress exists${NC}"
    
    # Show current host configuration
    CURRENT_HOST=$(kubectl get ingress -n sample-app sample-app -o jsonpath='{.spec.rules[0].host}')
    echo -e "${BLUE}Current Host:${NC} $CURRENT_HOST"
    
    if [[ "$CURRENT_HOST" == "$HOSTNAME" ]]; then
        echo -e "${GREEN}✓ Ingress host matches expected hostname${NC}"
    else
        echo -e "${YELLOW}! Ingress host differs from expected${NC}"
        echo -e "${YELLOW}  This is normal if changes haven't been committed to Git yet${NC}"
    fi
else
    echo -e "${RED}✗ Ingress not found${NC}"
fi

# Check application pods
echo -e "\n${BLUE}Checking application status...${NC}"
POD_STATUS=$(kubectl get pods -n sample-app -l app.kubernetes.io/name=sample-app --no-headers | awk '{print $3}' | head -1)
if [[ "$POD_STATUS" == "Running" ]]; then
    echo -e "${GREEN}✓ Application pods are running${NC}"
elif [[ "$POD_STATUS" == "InvalidImageName" ]]; then
    echo -e "${YELLOW}! Application pods have InvalidImageName (expected with placeholder)${NC}"
else
    echo -e "${YELLOW}! Application pod status: $POD_STATUS${NC}"
fi

# Test direct k3d access
echo -e "\n${BLUE}Testing direct k3d access...${NC}"
if curl -s --connect-timeout 5 http://localhost/ >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Direct k3d access working (http://localhost/)${NC}"
else
    echo -e "${YELLOW}! Direct k3d access not responding${NC}"
fi

# Summary
echo -e "\n${BLUE}=== Access Methods ===${NC}"
echo -e "${GREEN}1. External DNS (after Git commit):${NC} http://$HOSTNAME"
echo -e "${GREEN}2. Port Forward:${NC} kubectl port-forward -n sample-app svc/sample-app 8080:80"
echo -e "${GREEN}3. Direct k3d:${NC} http://localhost/"
echo -e "${GREEN}4. Argo CD UI:${NC} kubectl port-forward svc/argocd-server -n argocd 8080:80"

echo -e "\n${BLUE}To apply ingress changes:${NC}"
echo -e "git add . && git commit -m 'Update ingress for sslip.io' && git push"
echo -e "\n${YELLOW}Argo CD will sync the changes automatically within 3 minutes.${NC}"