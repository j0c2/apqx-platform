# Design Decisions

Architectural decisions and technology choices for the On-Prem GitOps App Platform.

## Technology Stack Decisions

### k3d (Kubernetes Distribution)
**Decision**: Use k3d for local Kubernetes clusters
**Rationale**:
- **Reproducibility**: Consistent dev/test environments with minimal resource usage
- **Speed**: Fast cluster creation/destruction for iterative development
- **GitOps Quality**: Full Kubernetes API compatibility for realistic testing
- **Simplicity**: Single binary with Docker as only dependency

### Traefik (Ingress Controller)
**Decision**: Use Traefik as the primary ingress controller
**Rationale**:
- **DNS/Ingress**: Built into k3d, automatic TLS, excellent wildcard DNS support
- **Configuration**: Dynamic configuration via Kubernetes CRDs
- **Integration**: Native Docker and Kubernetes service discovery

### Argo CD (GitOps Operator)
**Decision**: Use Argo CD for GitOps continuous delivery
**Rationale**:
- **GitOps Quality**: Industry-standard GitOps implementation with drift detection
- **Visibility**: Comprehensive UI for deployment status and troubleshooting
- **Security**: RBAC, SSO integration, secure by default
- **App-of-Apps**: Native support for managing multiple applications

### GitHub Container Registry (GHCR)
**Decision**: Use GHCR for container image storage
**Rationale**:
- **CI/CD**: Integrated with GitHub Actions, no additional authentication
- **Security**: Built-in vulnerability scanning with Trivy integration
- **Cost**: Free for public repositories, reasonable pricing for private
- **Immutability**: Strong digest-based image referencing

### Kyverno (Policy Engine)
**Decision**: Use Kyverno for Kubernetes policy management
**Rationale**:
- **Security**: YAML-based policies for security and governance
- **Code Quality**: Policies as code with version control
- **Validation**: Admission control for resource validation
- **Mutation**: Dynamic configuration injection and modification

### Tailscale Operator
**Decision**: Use Tailscale for secure networking
**Rationale**:
- **DNS/Ingress**: MagicDNS provides automatic internal DNS resolution
- **Security**: Zero-trust networking with WireGuard encryption
- **Simplicity**: No VPN server setup, automatic mesh networking
- **Remote Access**: Secure access from anywhere without port forwarding

### Trivy (Security Scanning)
**Decision**: Integrate Trivy for vulnerability scanning
**Rationale**:
- **Security**: Comprehensive vulnerability database with OS and language scanning
- **CI/CD**: Fast scanning suitable for CI pipeline integration
- **Code Quality**: Security-first development practices
- **Open Source**: No licensing costs, community-driven updates

## Architecture Principles

### Reproducibility & Documentation
- **Infrastructure as Code**: Everything defined in version-controlled manifests
- **Immutable Deployments**: Container images pinned by digest
- **Automated Setup**: Single `make up` command for complete environment
- **Self-Documenting**: Minimal but comprehensive documentation

### GitOps Quality
- **Declarative Configuration**: All desired state defined in Git
- **Automated Sync**: Argo CD maintains cluster state from Git
- **Drift Detection**: Automatic correction of configuration drift
- **Audit Trail**: All changes tracked through Git history

### DNS & Ingress
- **Local Development**: sslip.io for wildcard DNS without configuration
- **Production-like**: Traefik ingress with TLS termination
- **Remote Access**: Tailscale MagicDNS for secure connectivity
- **Certificate Management**: Automatic TLS certificate provisioning

### Security
- **Policy Enforcement**: Kyverno policies for security governance
- **Secret Management**: Sealed Secrets for encrypted configuration
- **Network Isolation**: Tailscale zero-trust networking
- **Vulnerability Scanning**: Trivy integration in CI pipeline

### CI/CD
- **Automated Testing**: GitHub Actions with security scanning
- **Immutable Artifacts**: Container images with digest-based references
- **GitOps Integration**: Automatic manifest updates with image digests
- **Quality Gates**: Required security and policy checks

### Code Quality
- **Static Analysis**: Built into CI pipeline
- **Security Scanning**: Trivy for vulnerabilities, Kyverno for policies
- **Minimal Dependencies**: Focused technology stack
- **Documentation**: Architecture decisions captured in code