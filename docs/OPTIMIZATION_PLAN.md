# apqx-platform Optimization & Compliance Plan

## Assessment Compliance Analysis

### ✅ COMPLIANT REQUIREMENTS

1. **Cluster Bootstrap** ✅
   - k3d cluster automated via Terraform
   - Traefik ingress controller installed
   - Argo CD GitOps deployed

2. **Application Deployment** ✅
   - Sample Go app serving JSON with app name, build SHA, timestamp
   - Accessible via ingress at sslip.io
   - Has readiness/liveness probes
   - Resource requests/limits configured
   - HPA with min/max scaling

3. **CI/CD** ✅
   - GitHub Actions workflow implemented
   - Builds, tests, scans with Trivy
   - Pushes to GHCR
   - Updates GitOps by digest

4. **Security** ✅
   - Images pinned by digest
   - RBAC with ServiceAccount
   - Kyverno policies enforced
   - No plaintext secrets

5. **SRE/Operability** ✅
   - HPA configured (1-3 replicas)
   - Prometheus metrics annotations

6. **DNS/Ingress** ✅
   - sslip.io working
   - Tailscale MagicDNS configured (HTTP working)

### ⚠️ PARTIAL COMPLIANCE

1. **HTTPS on Tailscale** ⚠️
   - HTTP works, HTTPS limited by operator v1.66.3

2. **Documentation** ⚠️
   - Needs architecture diagram
   - README needs updating

### ❌ MISSING REQUIREMENTS

1. **Build SHA in App Response** ❌
   - App doesn't include actual Git SHA

2. **PodDisruptionBudget** ❌
   - Not configured

## OPTIMIZATION PLAN

### Phase 1: Fix Critical Requirements (Priority 1)

1. **Add Build SHA to Application**
   - Modify app/main.go to include build SHA
   - Update Dockerfile to inject SHA at build time
   - Update CI to pass SHA to build

2. **Add PodDisruptionBudget**
   - Create PDB manifest
   - Add to kustomization

3. **Update Documentation**
   - Create architecture diagram
   - Update README with all URLs
   - Document Tailscale limitations

### Phase 2: Remove Bloat (Priority 2)

1. **Clean up unused manifests**
   - Remove test/experimental YAML files
   - Consolidate overlapping configurations

2. **Optimize Terraform**
   - Remove commented code
   - Consolidate variables
   - Clean up unused resources

3. **Streamline CI workflow**
   - Remove redundant steps
   - Optimize caching

### Phase 3: Enhancements (Priority 3)

1. **Improve security**
   - Add NetworkPolicy
   - Implement SecurityContext constraints

2. **Better observability**
   - Add proper metrics endpoint
   - Configure Prometheus scraping

3. **Stretch goals**
   - Implement cert-manager properly
   - Add progressive delivery

## IMPLEMENTATION CHECKLIST

### Immediate Actions (Must Do):
- [ ] Add build SHA to app response
- [ ] Create PodDisruptionBudget
- [ ] Update app to return proper JSON format
- [ ] Create architecture diagram
- [ ] Update README with complete setup instructions

### Cleanup Actions:
- [ ] Remove unused ReplicaSets
- [ ] Clean up test scripts
- [ ] Remove experimental Tailscale configurations
- [ ] Consolidate duplicate manifests

### Nice to Have:
- [ ] Add NetworkPolicy
- [ ] Improve HPA metrics
- [ ] Add better health checks
- [ ] Implement progressive delivery

## FILE CHANGES NEEDED

### 1. app/main.go
- Add buildSHA variable
- Include in JSON responses

### 2. app/Dockerfile
- Add ARG BUILD_SHA
- Pass to build

### 3. .github/workflows/ci.yml
- Pass Git SHA to Docker build

### 4. gitops/apps/app/base/pdb.yaml (NEW)
- Create PodDisruptionBudget

### 5. docs/architecture.md (NEW)
- Create architecture diagram
- Document design decisions

### 6. README.md
- Update with complete instructions
- Add troubleshooting guide
- List all access URLs

## VALIDATION CRITERIA

After implementation:
1. App returns JSON with: `{"app_name": "sample-app", "build_sha": "abc123...", "timestamp": "2025-09-23T00:00:00Z"}`
2. PDB prevents total unavailability
3. All manifests are clean and minimal
4. Documentation is complete
5. `make up` deploys everything successfully
6. CI/CD pipeline passes all checks
7. Both sslip.io and Tailscale URLs work (HTTP minimum)

## ESTIMATED TIME

- Phase 1: 30 minutes
- Phase 2: 20 minutes  
- Phase 3: Optional/future

Total: ~50 minutes for full compliance