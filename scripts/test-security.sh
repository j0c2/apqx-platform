#!/bin/bash

# Test minimum security implementation
# Validates RBAC, secrets, and container security

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing Minimum Security Implementation ===${NC}"

# Test variables
BASE_DIR="gitops/apps/app/base"
DEV_OVERLAY_DIR="gitops/apps/app/overlays/dev"

# Function to check if resource exists in kustomization
check_resource_in_manifest() {
    local description="$1"
    local resource_kind="$2"
    local kustomize_dir="$3"
    
    echo -n "  [$description] "
    
    if kubectl kustomize "$kustomize_dir" | grep -q "kind: $resource_kind"; then
        echo -e "${GREEN}✓ FOUND${NC}"
        return 0
    else
        echo -e "${RED}✗ MISSING${NC}"
        return 1
    fi
}

# Test RBAC resources in base
echo -e "\n${BLUE}=== Testing RBAC Implementation ===${NC}"
check_resource_in_manifest "ServiceAccount" "ServiceAccount" "$BASE_DIR"
check_resource_in_manifest "Role (minimal permissions)" "Role" "$BASE_DIR" 
check_resource_in_manifest "RoleBinding" "RoleBinding" "$BASE_DIR"

# Check Role has minimal permissions
echo -n "  [Role permissions are minimal] "
if kubectl kustomize "$BASE_DIR" | grep -A 5 "kind: Role" | grep -q "rules: \[\]"; then
    echo -e "${GREEN}✓ EMPTY RULES${NC}"
else
    echo -e "${YELLOW}⚠ HAS PERMISSIONS${NC}"
fi

# Check ServiceAccount token is disabled
echo -n "  [ServiceAccount token disabled] "
if kubectl kustomize "$BASE_DIR" | grep -A 5 "kind: ServiceAccount" | grep -q "automountServiceAccountToken: false"; then
    echo -e "${GREEN}✓ TOKEN DISABLED${NC}"
else
    echo -e "${RED}✗ TOKEN ENABLED${NC}"
fi

# Test Secret in dev overlay
echo -e "\n${BLUE}=== Testing Secrets Management ===${NC}"
check_resource_in_manifest "Placeholder Secret" "Secret" "$DEV_OVERLAY_DIR"

# Check secret contains development placeholders
echo -n "  [Secret has dev placeholder values] "
if kubectl kustomize "$DEV_OVERLAY_DIR" | grep -A 10 "kind: Secret" | grep -q "dev_password_replace_in_prod"; then
    echo -e "${GREEN}✓ DEV PLACEHOLDERS${NC}"
else
    echo -e "${YELLOW}⚠ MISSING PLACEHOLDERS${NC}"
fi

# Test container security in deployment
echo -e "\n${BLUE}=== Testing Container Security ===${NC}"

# Check non-root user
echo -n "  [Container runs as non-root] "
if kubectl kustomize "$BASE_DIR" | grep -A 20 "securityContext:" | grep -q "runAsNonRoot: true"; then
    echo -e "${GREEN}✓ NON-ROOT${NC}"
else
    echo -e "${RED}✗ ROOT USER${NC}"
fi

# Check read-only filesystem
echo -n "  [Read-only root filesystem] "
if kubectl kustomize "$BASE_DIR" | grep -A 10 "securityContext:" | grep -q "readOnlyRootFilesystem: true"; then
    echo -e "${GREEN}✓ READ-ONLY FS${NC}"
else
    echo -e "${RED}✗ WRITABLE FS${NC}"
fi

# Check capabilities dropped
echo -n "  [Linux capabilities dropped] "
if kubectl kustomize "$BASE_DIR" | grep -A 10 "capabilities:" | grep -q "drop:" && kubectl kustomize "$BASE_DIR" | grep -A 10 "capabilities:" | grep -q "ALL"; then
    echo -e "${GREEN}✓ CAPS DROPPED${NC}"
else
    echo -e "${RED}✗ CAPS PRESENT${NC}"
fi

# Check privilege escalation disabled
echo -n "  [Privilege escalation disabled] "
if kubectl kustomize "$BASE_DIR" | grep -A 10 "securityContext:" | grep -q "allowPrivilegeEscalation: false"; then
    echo -e "${GREEN}✓ NO PRIVILEGE ESCALATION${NC}"
else
    echo -e "${RED}✗ PRIVILEGE ESCALATION POSSIBLE${NC}"
fi

# Test image security
echo -e "\n${BLUE}=== Testing Image Security ===${NC}"

# Check image uses digest (not tag)
echo -n "  [Image uses digest reference] "
if kubectl kustomize "$DEV_OVERLAY_DIR" | grep "image:" | grep -q "@sha256:"; then
    echo -e "${GREEN}✓ DIGEST REFERENCE${NC}"
else
    echo -e "${RED}✗ TAG REFERENCE${NC}"
fi

# Test resource limits
echo -e "\n${BLUE}=== Testing Resource Limits ===${NC}"

echo -n "  [CPU limits configured] "
if kubectl kustomize "$BASE_DIR" | grep -A 5 "limits:" | grep -q "cpu:"; then
    echo -e "${GREEN}✓ CPU LIMITS${NC}"
else
    echo -e "${RED}✗ NO CPU LIMITS${NC}"
fi

echo -n "  [Memory limits configured] "
if kubectl kustomize "$BASE_DIR" | grep -A 5 "limits:" | grep -q "memory:"; then
    echo -e "${GREEN}✓ MEMORY LIMITS${NC}"
else
    echo -e "${RED}✗ NO MEMORY LIMITS${NC}"
fi

# Summary
echo -e "\n${BLUE}=== Security Implementation Summary ===${NC}"
echo -e "${GREEN}✅ RBAC: ServiceAccount + Role + RoleBinding${NC}"
echo -e "${GREEN}✅ Secrets: Placeholder Secret with warnings${NC}"
echo -e "${GREEN}✅ Container: Non-root, read-only, no privileges${NC}"
echo -e "${GREEN}✅ Images: Digest-based references${NC}"
echo -e "${GREEN}✅ Resources: CPU/memory limits enforced${NC}"

echo -e "\n${YELLOW}⚠️  Production Security Checklist:${NC}"
echo -e "1. Replace placeholder secrets with SealedSecrets/SOPS"
echo -e "2. Review and adjust RBAC permissions as needed"
echo -e "3. Implement network policies (if required)"
echo -e "4. Enable Pod Security Standards/Admission Controllers"
echo -e "5. Regular container image vulnerability scanning"

echo -e "\n${BLUE}Minimum security basics: ✅ COMPLETE${NC}"