# Architecture

High-level architecture overview of the On-Prem GitOps App Platform.

## CI/CD Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Developer │    │   GitHub    │    │    GHCR     │    │     Git     │    │   Argo CD   │
│             │    │   Actions   │    │  Registry   │    │ Repository  │    │             │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │                  │                  │
       │ git push         │                  │                  │                  │
       ├─────────────────▶│                  │                  │                  │
       │                  │ build & push     │                  │                  │
       │                  ├─────────────────▶│                  │                  │
       │                  │                  │ digest@sha256... │                  │
       │                  │                  ├─────────────────▶│                  │
       │                  │                  │                  │ detect changes   │
       │                  │                  │                  ├─────────────────▶│
       │                  │                  │                  │                  │
       │                  │                  │                  │                  ▼
   ┌─────────────────────────────────────────────────────────────────────────────────────────┐
   │                              Kubernetes Cluster (k3d)                                  │
   │                                                                                         │
   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
   │  │   Traefik   │  │     App     │  │   Kyverno   │  │  Tailscale  │  │   Sealed    │  │
   │  │   Ingress   │  │ Workloads   │  │  Policies   │  │  Operator   │  │  Secrets    │  │
   │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │
   │                                                                                         │
   └─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Component Overview

### CI Pipeline (GitHub Actions)
- **Trigger**: Code push to main branch
- **Build**: Multi-stage Docker build with security scanning
- **Push**: Container image to GitHub Container Registry
- **Update**: Automatic digest update commit to Git repository

### GitOps Flow
- **Argo CD** monitors Git repository for manifest changes
- **Immutable deployments** using container image digests
- **Automatic sync** from Git state to cluster state
- **Drift detection** and correction

### Infrastructure Components
- **k3d**: Lightweight Kubernetes distribution for local development
- **Traefik**: Ingress controller and load balancer (included with k3d)
- **Argo CD**: GitOps continuous delivery
- **Kyverno**: Policy engine for security and governance
- **Tailscale Operator**: Secure networking and remote access
- **Sealed Secrets**: Encrypted secret management

### Networking
- **Local access**: sslip.io for wildcard DNS resolution
- **Remote access**: Tailscale MagicDNS for secure connectivity
- **TLS termination**: Handled by Traefik with automatic certificates