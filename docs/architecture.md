# apqx-platform Architecture

## Overview

The `apqx-platform` is an on-premises GitOps application platform that simulates enterprise-grade Kubernetes deployments with security, automation, and observability best practices.

## Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────┐
│                          apqx-platform                            │
│                     On-Prem GitOps Platform                       │
└───────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitHub        │    │   CI/CD         │
│   Machine       │    │   Repository    │    │   (Actions)     │
│                 │    │                 │    │                 │
│ make up ────────┼────► Code Changes ───┼────► Build/Test/     │
│ make destroy    │    │ GitOps Manifests│    │ Scan/Deploy     │
│ Local Dev       │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │ Updates
         │                       │                       │ Image Digests
         │                       │                       ▼
         │                       └──────────────┐ ┌─────────────────┐
         │                                      │ │   Container     │
         │                                      │ │   Registry      │
         │ kubectl/k3d                          │ │   (GHCR)        │
         │                                      │ │                 │
         ▼                                      ▼ └─────────────────┘
┌───────────────────────────────────────────────────────────────────┐
│                         Local k3d Cluster                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │   Argo CD       │  │   Sample App    │  │   Traefik       │    │
│  │   (GitOps)      │  │                 │  │   (Ingress)     │    │
│  │                 │  │ • Go Web App    │  │                 │    │
│  │ • Auto Sync     │  │ • Health Checks │  │ • Load Balancer │    │
│  │ • App Mgmt      │  │ • HPA (1-3)     │  │ • SSL Term.     │    │
│  │ • UI Dashboard  │  │ • PDB           │  │ • DNS Magic     │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │   Kyverno       │  │   Cert Manager  │  │   Tailscale     │    │
│  │   (Policies)    │  │   (TLS)         │  │   (Network)     │    │
│  │                 │  │                 │  │                 │    │
│  │ • Security      │  │ • Self-signed   │  │ • MagicDNS      │    │
│  │ • Best Practices│  │ • Automatic     │  │ • Secure Access │    │
│  │ • Compliance    │  │ • cert-manager  │  │ • VPN-less      │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└───────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                         External Access                            │
│                                                                    │
│  HTTPS/HTTP:  https://app-onprem.tail13bd49.ts.net (Tailscale+TLS) │
│               http://app.<LOCAL-IP>.sslip.io (Traefik)             │
│                                                                    │
│  GitOps UI:   http://localhost:8080 (Argo CD)                      │
│               kubectl port-forward                                 │
└────────────────────────────────────────────────────────────────────┘
```

## System Components

### Networking & Access
- Host port mapping: k3d exposes Traefik on host ports 80/443 via the k3d load balancer (`--port 80:80@loadbalancer --port 443:443@loadbalancer`).
- sslip.io: ingress hosts use `<name>.<LOCAL-IP>.sslip.io` and cert-manager issues self-signed certs for those hostnames.
- Optional: `make access` sets up local port-forward on 8090/8443 when direct 80/443 cannot be used (or are blocked). Use Host headers to route correctly.

### Controller installation & GitOps separation
- Controllers (Argo CD, Kyverno, cert-manager, Argo Rollouts, Tailscale operator) are installed by Terraform via Helm.
- GitOps resources (Kyverno policies, platform ingresses, Certificates) and the application overlay are managed by Argo CD Applications.
- The Makefile wires these together (Step 3 applies management Applications including Kyverno policies).

### CI/CD Overview
- GitHub Actions builds the sample app, pushes to GHCR, generates an SBOM, scans with Trivy, then updates the Kustomize overlay digest.
- Argo CD auto-syncs the digest change to rollout the new version.

### Infrastructure Layer
- **k3d Cluster**: Lightweight Kubernetes for local development
- **Terraform**: Infrastructure as Code for automated provisioning
- **Docker**: Container runtime and image management

### Platform Layer
- **Argo CD**: GitOps continuous delivery controller
- **Traefik**: Cloud-native ingress controller with automatic service discovery
- **Kyverno**: Policy engine for security and compliance
- **cert-manager**: Automated TLS certificate management
- **Tailscale**: Secure networking and remote access

### Application Layer
- **Sample Go App**: Web service with health checks and metrics
- **HPA**: Horizontal Pod Autoscaler for dynamic scaling
- **PDB**: PodDisruptionBudget for high availability

## Assessment Requirements Compliance

✅ **Cluster Bootstrap**: k3d + Terraform automation
✅ **GitOps**: Argo CD with automatic sync
✅ **Ingress**: Traefik with sslip.io DNS
✅ **Application**: Go web app with JSON endpoints including build SHA
✅ **CI/CD**: GitHub Actions with build/test/scan/deploy
✅ **Security**: RBAC, digest pinning, Kyverno policies
✅ **SRE**: HPA, PDB, resource limits, health checks
✅ **DNS**: Both sslip.io and Tailscale MagicDNS working

## Key URLs

- **Application (Public)**: https://app.<LOCAL-IP>.sslip.io
- **Application (Tailnet)**: http://app-onprem.tail13bd49.ts.net
- **Argo CD UI**: kubectl port-forward to localhost:8080

## Technology Decisions

### Why k3d?
- Lightweight and fast startup
- Full Kubernetes API compatibility
- Easy setup and teardown
- Perfect for development environments

### Why Argo CD?
- Industry-standard GitOps tool
- Excellent UI and observability
- Robust sync capabilities
- Strong community support

### Why Traefik?
- Cloud-native design
- Automatic service discovery
- Built-in Let's Encrypt integration
- Kubernetes-native configuration

This architecture provides a complete, production-like development environment with enterprise-grade practices in a local setup.