# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Table of Contents
- [Project Overview](#project-overview)
- [Global Instructions](#global-instructions)
- [Repository Structure](#repository-structure)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Development Workflow](#development-workflow)
- [Common Commands](#common-commands)
- [GitOps Patterns](#gitops-patterns)
- [GitHub Actions](#github-actions)
- [AI Assistant Guidelines](#ai-assistant-guidelines)
- [Take Home Assessment Requirements](#take-home-assessment-requirements)

## Project Overview

**apqx-platform** is an On-Prem GitOps App Platform (Mini) designed for managing Kubernetes applications using GitOps principles. This repository contains infrastructure as code, application manifests, and automation tools for deploying and managing applications on-premises.

**Important Note**: Repository name is `apqx-platform` but references in code may use `onprem-gitops-platform` as the conceptual root.

## Global Instructions

**These instructions take precedence for all code generation and modifications:**

1. **Output Standards**:
   - Output fully working code/configurations in the exact file paths specified
   - Favor minimal, readable YAML/Terraform/Helm values
   - Pin every container by immutable digest (never use `:latest` tags)
   - Write concise comments at the top of each file explaining what it does

2. **Repository Assumptions**:
   - Assume repo root is `onprem-gitops-platform/` for path references
   - Current actual path is `/Users/jd0t/dev/apqx-platform/`
   - All manifests should be organized under `gitops/` directory using Kustomize or Helm values

3. **Configuration Management**:
   - Use placeholders for sensitive data (e.g., `<TAILSCALE_OAUTH_CLIENT_ID>`)
   - Document all placeholders in `docs/README.md`
   - Maintain environment-specific configurations through GitOps patterns

4. **Reproducibility Requirements**:
   - Every step should be reproducible with `make up`
   - Clean environments with `make destroy`
   - All automation must be idempotent and safe to re-run

## Repository Structure

Expected directory structure for this GitOps platform:

```
apqx-platform/                 # Current repo name
├── gitops/                    # All Kustomize/Helm manifests
│   ├── apps/                  # Application definitions
│   ├── infrastructure/        # Infrastructure components
│   ├── environments/          # Environment-specific configs
│   └── base/                  # Base configurations
├── terraform/                 # Infrastructure as Code
│   ├── modules/               # Reusable Terraform modules
│   └── environments/          # Environment-specific Terraform
├── scripts/                   # Automation scripts
│   ├── setup/                 # Initial setup scripts
│   └── utils/                 # Utility scripts
├── docs/                      # Documentation
│   └── README.md             # Placeholder documentation
├── .github/                   # GitHub Actions workflows
│   └── workflows/            # CI/CD pipelines
├── Makefile                   # Primary automation interface
├── README.md                  # Project overview
└── WARP.md                   # This context file
```

## Architecture

This GitOps platform follows these architectural principles:

- **GitOps-First**: All changes deployed through Git commits
- **Declarative Configuration**: Infrastructure and applications defined as code
- **Immutable Deployments**: Container images pinned by digest
- **Environment Promotion**: Changes flow through environments via Git
- **Observability**: Monitoring and logging built into the platform

Key components expected:
- **ArgoCD/Flux**: GitOps operator for Kubernetes
- **Kubernetes**: Target deployment platform
- **Terraform**: Infrastructure provisioning
- **Helm/Kustomize**: Application packaging and customization

## Technology Stack

Expected tools and technologies:

- **Container Runtime**: Docker/Podman
- **Orchestration**: Kubernetes
- **GitOps**: ArgoCD or Flux
- **IaC**: Terraform with provider-specific modules
- **Package Management**: Helm 3.x, Kustomize
- **CI/CD**: GitHub Actions
- **Secrets Management**: External secret operators, sealed-secrets, or similar
- **Networking**: Tailscale for secure connectivity (based on placeholder references)
- **Monitoring**: Prometheus, Grafana stack

## Development Workflow

1. **Local Development**:
   ```bash
   # Set up local environment
   make up
   
   # Validate configurations
   make validate
   
   # Clean up
   make destroy
   ```

2. **Configuration Changes**:
   - Modify YAML/Terraform in appropriate directories
   - Test locally before committing
   - Use placeholders for environment-specific values
   - Document changes in commit messages

3. **Deployment Flow**:
   - Commit changes to feature branch
   - CI/CD validates and tests changes
   - Merge to main triggers deployment
   - GitOps operator syncs changes to cluster

## Common Commands

Essential Makefile targets (implement these):

```bash
# Environment Management
make up           # Deploy/update the platform
make destroy      # Tear down the platform
make validate     # Validate all configurations

# Development
make lint         # Lint YAML, Terraform, scripts
make test         # Run all tests
make plan         # Show deployment plan (Terraform plan)

# GitOps Operations
make sync         # Manually sync GitOps applications
make diff         # Show differences between Git and cluster state
```

## GitOps Patterns

Follow these GitOps patterns:

1. **App of Apps**: Use ArgoCD/Flux application sets for managing multiple applications
2. **Environment Promotion**: Separate branches/directories for environments
3. **Secret Management**: Never commit secrets; use external secret management
4. **Rollback Strategy**: Use Git reverts for quick rollbacks
5. **Drift Detection**: Monitor and alert on configuration drift

## GitHub Actions

**Critical Requirement**: All GitHub Actions workflows must pass before any work is considered complete.

Workflow expectations:
- **Validation Pipeline**: Lint, test, security scan all code
- **Local Testing**: Workflows must be testable locally using act or similar tools
- **Optimization**: Continuously improve workflow performance and reliability
- **Security**: Use minimal permissions, secure secrets handling

When modifying workflows:
1. Create local test environment for workflow validation
2. Fix issues in both workflow files and project code
3. Ensure all checks pass before merging
4. Commit directly to main branch only after validation

## AI Assistant Guidelines

**For AI assistants working in this repository:**

1. **Instruction Priority** (highest to lowest):
   - WARP.md instructions (this file)
   - Project-specific rules in subdirectories
   - General development practices

2. **Output Requirements**:
   - Always provide fully functional, production-ready code
   - Include proper error handling and logging
   - Use the exact file paths specified in requests
   - Follow the global instructions above without exception

3. **Quality Standards**:
   - Code must be idempotent and safe to re-run
   - All configurations must be reproducible
   - Container images must use immutable digests
   - Sensitive data must use documented placeholders

4. **Workflow Integration**:
   - Ensure all changes integrate with existing Makefile targets
   - Maintain compatibility with GitOps patterns
   - Validate that GitHub Actions workflows pass
   - Document any new placeholders in `docs/README.md`


## Take Home Assessment Requirements

**Critical Requirement**: Make sure the project fulfills the assessment's deliverable goals, functional requirements, and stretch goals, nothing more, nothing less.

Constraints (simulate on-prem):
1. **Cluster**: Use of k3s
2. **Ingress Controller**: Any ingress controller you prefer (document your choice and
why)
3. **DNS**: Try to use a DNS / Magic DNS setup and not IP address to make the
application externally accessible. (Tailscale k8s operator would be nice to see here)
4. **GitOps**: Argo CD (preferred)
5. **CI/CD**: GitHub Actions
6. **Automation**: Use Terraform / config management for infra/bootstrap where
sensible
7. **Security**: Include basic hardening (see “Security requirements”)

Functional Requirements:
1. Cluster bootstrap
   - Infra automation brings up a local K8s cluster
   - Installs and configures an ingress controller
   - Installs and configures a GitOps deployment tool
2. Application deployment via GitOps
   - Deploy a simple web app serving JSON with:
      - app name
      - build SHA
      - current timestamp (from inside the pod)
      - Accessible via Ingress at `http://app.<LOCAL-IP>.sslip.io/`, `https://<app-name>.<tailnet-name>.net`
      - Include readiness/liveness probes, resource requests/limits, and a safe update strategy
3. CI/CD
   - GitHub Actions workflow to:
      - build container image
      - run basic test(s)
      - scan image (e.g., Trivy)
      - push image to a registry (GHCR or local)
      - update GitOps layer by digest, not :latest
4. Security requirements (minimum)
   - Pin container images by digest in manifests
   - RBAC: app runs under a dedicated ServiceAccount with least privilege
   - Secrets handled securely (no plaintext in repo)
5. SRE/operability (minimum)
   - HPA with safe min/max
   - Basic observability (metrics, annotations, or alerts)
6. DNS/Ingress
   - Functional hostname using magic DNS service (document exact URL).

Stretch goals:
   - TLS with cert-manager (self-signed OK)
   - Policy enforcement (OPA Gatekeeper, Kyverno)
   - Progressive delivery (Argo Rollouts or similar)
   - Self-hosted CI runner
---

*Last updated: 2025-09-22*
*Repository: apqx-platform (On-Prem GitOps App Platform)*