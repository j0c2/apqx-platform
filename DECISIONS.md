# Architectural Decisions

This document explains the key architectural decisions made for the **apqx-platform** implementation, particularly for the stretch goal features.

## Progressive Delivery: Argo Rollouts

### Decision

Selected **Argo Rollouts** for progressive delivery implementation over alternatives like Flagger, Istio, or native Kubernetes deployments.

### Rationale

**Why Argo Rollouts:**

1. **GitOps Integration**: Native integration with Argo CD ecosystem
   - Unified GitOps workflow for both deployment and progressive delivery
   - Consistent YAML-based configuration management
   - Single control plane for observability and troubleshooting

2. **Kubernetes-Native**: 
   - Custom Resource Definitions (CRDs) that extend Kubernetes naturally
   - No service mesh dependency (unlike Istio/Linkerd-based solutions)
   - Works with existing Kubernetes ingress and service architecture

3. **Simplicity for Demo**:
   - Step-based canary configuration is intuitive and predictable
   - Visual progress tracking through kubectl commands
   - No additional networking complexity or mesh installation

4. **Production-Ready**:
   - Battle-tested by CNCF community
   - Active development and maintenance
   - Comprehensive traffic management and rollback capabilities

**Compared to alternatives:**

- **vs Flagger**: Requires Linkerd/Istio service mesh, adding complexity
- **vs Istio**: Heavy service mesh overhead for minimal demo environment  
- **vs Native Deployments**: No progressive traffic splitting or automated rollback
- **vs Jenkins X/Tekton**: Focus on GitOps rather than CI/CD pipeline tools

### Implementation Details

**Canary Strategy Chosen**:
```yaml
strategy:
  canary:
    steps:
    - setWeight: 20    # 20% → 50% → 100% progression
    - pause: 60s       # Human validation time
    - setWeight: 50    
    - pause: 60s
    - setWeight: 100   # Full promotion
```

**Why this progression**:
- **20% initial**: Low-risk exposure for quick issue detection
- **60s pauses**: Sufficient time for monitoring/validation in demo
- **50% intermediate**: Meaningful traffic split for performance testing  
- **Linear progression**: Simple, predictable, easy to explain

**Service Architecture**:
- **Stable Service** (`sample-app-stable`): Production traffic routing
- **Canary Service** (`sample-app-canary`): Test traffic routing
- **Ingress Integration**: Routes only to stable service for consistency
- **Traffic Splitting**: Managed automatically by Argo Rollouts controller

---

## Self-Hosted CI Runner: Docker Compose

### Decision

Implemented **self-hosted GitHub Actions runner** using Docker Compose with ephemeral configuration, rather than Kubernetes-based solutions.

### Rationale

**Why Docker Compose + Ephemeral Runner:**

1. **Stretch Goal Compliance**: 
   - Cleanly satisfies "self-hosted CI runner" requirement
   - Demonstrates CI/CD expertise without over-engineering
   - Easy to explain and validate during assessment review

2. **Operational Simplicity**:
   - Single command setup: `make runner-up` / `make runner-down`
   - No additional Kubernetes controllers or CRDs required
   - Completely reversible - no traces when stopped

3. **Security Best Practices**:
   - **Ephemeral registration**: Auto-unregisters when stopped
   - **Scoped PAT**: Only `repo` and `workflow` permissions needed
   - **Container isolation**: Runner contained, not affecting host system
   - **No persistent state**: Fresh environment for each session

4. **Resource Efficiency**:
   - Runs outside cluster, preserving k8s resources for platform
   - Uses host Docker daemon (Docker-in-Docker) for efficient builds
   - Minimal resource overhead compared to K8s-based alternatives

**Compared to alternatives:**

- **vs actions-runner-controller**: Requires additional K8s operator, CRDs, complexity
- **vs Persistent runner**: Security risk with long-lived registration tokens
- **vs Jenkins**: Different technology stack, heavier footprint
- **vs GitLab Runner**: Platform mismatch (GitHub Actions specific)

### Implementation Details  

**Configuration Choices**:

```yaml
environment:
  EPHEMERAL: "1"              # Auto-unregister on stop
  RUNNER_WORKDIR: /tmp/runner # Temporary workspace
  GITHUB_TOKEN: ${GITHUB_TOKEN} # Scoped PAT from .env
  RUNNER_LABELS: self-hosted,linux,x64 # Targeting labels
```

**Why these settings**:
- **EPHEMERAL=1**: Prevents accumulation of dead runners in GitHub UI
- **Temp workdir**: Ensures clean state, no persistent build artifacts
- **Specific labels**: Precise targeting for CI job assignment
- **Environment isolation**: Via Docker networking and filesystem

**CI Integration Strategy**:
```yaml
# Only build job uses self-hosted
jobs:
  build:
    runs-on: [self-hosted, linux, x64]  # Demonstration
    
  test:
    runs-on: ubuntu-latest              # Reliability
```

**Why hybrid approach**:
- **Demonstrates capability** without making entire pipeline dependent on local runner
- **Maintains reliability** - other jobs continue if self-hosted runner is down
- **Best of both worlds** - GitHub-hosted for standard tasks, self-hosted for builds
- **Easy rollback** - remove labels to fall back to GitHub-hosted entirely

### Security Considerations

**GitHub PAT Scoping**:
- **repo**: Required for repository access and runner registration  
- **workflow**: Required for updating workflow status and artifacts
- **No admin scopes**: Minimal permission principle

**Container Security**:
- **Docker socket mounting**: Required for builds but contained within runner container
- **No privileged mode**: Standard container security boundaries  
- **Network isolation**: Runner in dedicated Docker network
- **Temporary filesystem**: No persistent state or sensitive data retention

**Token Management**:
- **Environment file**: `.env` excluded from git via `.gitignore`
- **Template approach**: `.env.example` provides safe defaults
- **User responsibility**: Clear instructions for token generation and rotation

---

## Summary

Both stretch goal implementations prioritize:

1. **Simplicity**: Minimal setup complexity for assessment demonstration
2. **Best Practices**: Production-ready patterns and security considerations  
3. **Reversibility**: Easy to enable/disable without affecting core platform
4. **Documentation**: Clear rationale and instructions for evaluation

These choices directly align with take-home assessment goals: demonstrating technical depth while maintaining clean, explainable architectures that showcase real-world DevOps and platform engineering skills.

---

**Last Updated**: 2025-09-23  
**Platform Version**: v1.0 with Progressive Delivery + Self-Hosted CI