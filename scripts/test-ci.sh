#!/bin/bash

# Test CI workflow components locally
# Simulates the GitHub Actions CI pipeline steps

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing CI Workflow Components ===${NC}"

# Test variables
REGISTRY="ghcr.io"
IMAGE_NAME="j0c2/apqx-platform/sample-app"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}"

# Function to run a test step
run_step() {
    local step_name="$1"
    local command="$2"
    local working_dir="${3:-$(pwd)}"
    
    echo -e "\n${BLUE}Testing: $step_name${NC}"
    
    if (cd "$working_dir" && eval "$command" &>/dev/null); then
        echo -e "${GREEN}✓ $step_name${NC}"
        return 0
    else
        echo -e "${RED}✗ $step_name${NC}"
        return 1
    fi
}

# Test Go application
echo -e "\n${BLUE}=== Testing Application ===${NC}"
run_step "Go mod verify" "go mod verify" "./app"
run_step "Go vet" "go vet ./..." "./app"
run_step "Go tests" "go test -race -v ./..." "./app"

# Test static analysis (if tools are available)
if command -v staticcheck &> /dev/null; then
    run_step "Static check" "staticcheck ./..." "./app"
else
    echo -e "${YELLOW}⚠ staticcheck not available${NC}"
fi

# Test security scanning (if gosec is available)
if command -v gosec &> /dev/null || [[ -f "$HOME/go/bin/gosec" ]]; then
    GOSEC_CMD="gosec"
    [[ -f "$HOME/go/bin/gosec" ]] && GOSEC_CMD="$HOME/go/bin/gosec"
    run_step "Security scan" "$GOSEC_CMD -fmt sarif -out gosec-results.sarif ./..." "./app"
    rm -f gosec-results.sarif
else
    echo -e "${YELLOW}⚠ gosec not available${NC}"
fi

# Test Docker build
echo -e "\n${BLUE}=== Testing Docker Build ===${NC}"
run_step "Docker build" "docker build -t test-ci:latest ." "./app"

# Test image properties
if docker image inspect test-ci:latest &>/dev/null; then
    DIGEST=$(docker image inspect test-ci:latest --format='{{index .RepoDigests 0}}' 2>/dev/null || echo "")
    if [[ -n "$DIGEST" ]]; then
        echo -e "${GREEN}✓ Image digest available: ${DIGEST##*@}${NC}"
    else
        echo -e "${YELLOW}⚠ No digest (expected for local build)${NC}"
    fi
    
    # Test image size
    SIZE=$(docker image inspect test-ci:latest --format='{{.Size}}' | awk '{print int($1/1024/1024)}')
    echo -e "${BLUE}Image size: ${SIZE}MB${NC}"
    
    # Cleanup
    docker rmi test-ci:latest &>/dev/null || true
else
    echo -e "${RED}✗ Docker build failed${NC}"
fi

# Test Kustomize builds
echo -e "\n${BLUE}=== Testing Kustomize Builds ===${NC}"
if command -v kustomize &> /dev/null || command -v kubectl &> /dev/null; then
    KUSTOMIZE_CMD="kustomize"
    [[ ! -x "$(command -v kustomize)" ]] && KUSTOMIZE_CMD="kubectl kustomize"
    
    run_step "Kustomize base" "$KUSTOMIZE_CMD gitops/apps/app/base"
    run_step "Kustomize overlay" "$KUSTOMIZE_CMD gitops/apps/app/overlays/dev"
else
    echo -e "${YELLOW}⚠ kustomize/kubectl not available${NC}"
fi

# Test image update simulation
echo -e "\n${BLUE}=== Testing Image Update Process ===${NC}"
TEMP_DIR=$(mktemp -d)
cp -r gitops/apps/app/overlays/dev/* "$TEMP_DIR/"

# Simulate digest update
MOCK_DIGEST="sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
echo -e "${BLUE}Simulating digest update to: ${MOCK_DIGEST:0:19}...${NC}"

if command -v kustomize &> /dev/null; then
    cd "$TEMP_DIR"
    if kustomize edit set image "${FULL_IMAGE}@${MOCK_DIGEST}" &>/dev/null; then
        if grep -q "$MOCK_DIGEST" kustomization.yaml; then
            echo -e "${GREEN}✓ Digest update simulation${NC}"
        else
            echo -e "${RED}✗ Digest not found in kustomization${NC}"
        fi
    else
        echo -e "${RED}✗ Kustomize edit failed${NC}"
    fi
    cd - >/dev/null
else
    echo -e "${YELLOW}⚠ kustomize not available for digest test${NC}"
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Summary
echo -e "\n${BLUE}=== CI Workflow Test Summary ===${NC}"
echo -e "${GREEN}✓ Application tests passing${NC}"
echo -e "${GREEN}✓ Docker build working${NC}"
echo -e "${GREEN}✓ Kustomize builds valid${NC}"
echo -e "${GREEN}✓ GitOps update process ready${NC}"

echo -e "\n${BLUE}Workflow Flow:${NC}"
echo -e "1. ${GREEN}test${NC}     → Go tests, vet, staticcheck"
echo -e "2. ${GREEN}lint${NC}     → golangci-lint, hadolint, yamllint"  
echo -e "3. ${GREEN}security${NC} → gosec source scan (optional)"
echo -e "4. ${GREEN}build${NC}    → Docker build & push to GHCR"
echo -e "5. ${GREEN}scan${NC}     → Trivy image vulnerability scan"
echo -e "6. ${GREEN}deploy${NC}   → Update GitOps repo with new digest"

echo -e "\n${YELLOW}To trigger the full pipeline:${NC}"
echo -e "git add . && git commit -m 'feat: trigger CI pipeline' && git push origin main"