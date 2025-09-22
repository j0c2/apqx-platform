#!/bin/bash

# Local validation script for apqx-platform
# This script runs the same checks as the CI pipeline locally

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}Running local validation for apqx-platform...${NC}"

# Function to run a command and report results
run_check() {
    local description="$1"
    local command="$2"
    local working_dir="${3:-$PROJECT_DIR}"
    
    echo -n "  [$description] "
    
    if (cd "$working_dir" && eval "$command" &>/dev/null); then
        echo -e "${GREEN}✓ PASS${NC}"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "${YELLOW}    Command: $command${NC}"
        echo -e "${YELLOW}    Working dir: $working_dir${NC}"
        return 1
    fi
}

# Check dependencies
echo -e "\n${BLUE}Checking dependencies...${NC}"
run_check "Go installed" "go version"
run_check "Docker available" "docker version"

# Go tests
echo -e "\n${BLUE}Running Go tests...${NC}"
run_check "Go mod verify" "go mod verify" "$PROJECT_DIR/app"
run_check "Go vet" "go vet ./..." "$PROJECT_DIR/app"
run_check "Go tests" "go test -race -v ./..." "$PROJECT_DIR/app"

# Go static analysis
echo -e "\n${BLUE}Running static analysis...${NC}"
if command -v staticcheck &> /dev/null; then
    run_check "staticcheck" "staticcheck ./..." "$PROJECT_DIR/app"
else
    echo "  [staticcheck] ${YELLOW}SKIP - not installed${NC}"
fi

if [[ -f "$HOME/go/bin/gosec" ]]; then
    run_check "gosec security scan" "$HOME/go/bin/gosec -severity medium ./..." "$PROJECT_DIR/app"
else
    echo "  [gosec] ${YELLOW}SKIP - not installed${NC}"
fi

# Docker build
echo -e "\n${BLUE}Testing Docker build...${NC}"
run_check "Docker build" "docker build -t test-app:latest ." "$PROJECT_DIR/app"

# YAML validation
echo -e "\n${BLUE}Validating YAML files...${NC}"

# Basic YAML syntax check using Python
if command -v python3 &> /dev/null; then
    for yaml_file in $(find "$PROJECT_DIR" -name "*.yaml" -o -name "*.yml" | grep -v node_modules); do
        filename=$(basename "$yaml_file")
        run_check "YAML syntax: $filename" "python3 -c 'import yaml; yaml.safe_load(open(\"$yaml_file\"))'"
    done
else
    echo "  [YAML syntax] ${YELLOW}SKIP - python3 not available${NC}"
fi

# Kubernetes manifest validation (if kubectl available)
if command -v kubectl &> /dev/null; then
    echo -e "\n${BLUE}Validating Kubernetes manifests...${NC}"
    for k8s_file in $(find "$PROJECT_DIR/gitops" -name "*.yaml" 2>/dev/null | grep -v kustomization || true); do
        filename=$(basename "$k8s_file")
        run_check "K8s manifest: $filename" "kubectl apply --dry-run=client -f \"$k8s_file\""
    done
else
    echo -e "\n${YELLOW}Skipping Kubernetes validation - kubectl not available${NC}"
fi

# Test kustomize builds
if command -v kustomize &> /dev/null; then
    echo -e "\n${BLUE}Testing kustomize builds...${NC}"
    if [[ -d "$PROJECT_DIR/gitops/apps/app/overlays/dev" ]]; then
        run_check "Kustomize build dev overlay" "kustomize build gitops/apps/app/overlays/dev" "$PROJECT_DIR"
    fi
    if [[ -d "$PROJECT_DIR/gitops/apps/app/base" ]]; then
        run_check "Kustomize build base" "kustomize build gitops/apps/app/base" "$PROJECT_DIR"
    fi
else
    echo -e "\n${YELLOW}Skipping kustomize validation - kustomize not available${NC}"
fi

# Terraform validation
if command -v terraform &> /dev/null && [[ -d "$PROJECT_DIR/infra/terraform" ]]; then
    echo -e "\n${BLUE}Validating Terraform...${NC}"
    run_check "Terraform fmt check" "terraform fmt -check" "$PROJECT_DIR/infra/terraform"
    run_check "Terraform init" "terraform init -backend=false" "$PROJECT_DIR/infra/terraform"
    run_check "Terraform validate" "terraform validate" "$PROJECT_DIR/infra/terraform"
else
    echo -e "\n${YELLOW}Skipping Terraform validation - terraform not available or no terraform dir${NC}"
fi

echo -e "\n${GREEN}Local validation complete!${NC}"
echo -e "${BLUE}To run the full CI pipeline locally, use: act --container-architecture linux/amd64${NC}"