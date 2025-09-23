# docs/README.md

This document enumerates all placeholders and environment-specific values used by apqx-platform, and how to set them safely for local development.

Overview
- No real secrets are committed to the repository.
- Development-only placeholders exist in specific dev overlays and must NOT be used for production.
- Use environment variables and/or external secret managers for real credentials.

Placeholders and how to set them
1) Tailscale Operator OAuth (optional, for MagicDNS)
- Variables (do not commit values):
  - TF_VAR_tailscale_client_id
  - TF_VAR_tailscale_client_secret
- Purpose: Authenticates the Tailscale Kubernetes operator to your tailnet.
- How to set:
  export TF_VAR_tailscale_client_id="<TAILSCALE_OAUTH_CLIENT_ID>"
  export TF_VAR_tailscale_client_secret="<TAILSCALE_OAUTH_CLIENT_SECRET>"
- Where used: Terraform creates the secret tailscale/operator-oauth with these values (base64-encoded) and installs the operator.

2) sslip.io dynamic hostnames
- The repository includes sslip.io host templates in:
  - gitops/infrastructure/cert-manager/certificates-sslip.yaml (dnsNames)
  - gitops/apps/ingresses/*.yaml (hosts)
  - gitops/apps/app/overlays/dev/* (hosts)
- Your current LOCAL_IP must be used to access via sslip.io.
- How to update:
  - make update-ingress-hosts
  - This runs scripts/setup/update-ingress-hosts.sh, which patches ingressClassName, rules.host, and TLS hosts/secrets using your current LOCAL_IP from ifconfig.
- During make up, certs are also applied with your LOCAL_IP substituted via a simple sed pipeline.

3) Tailscale external egress placeholder (optional)
- File: gitops/apps/app/overlays/dev/ts-egress-externalname.yaml
- Placeholder fields:
  - metadata.annotations["tailscale.com/tailnet-fqdn"]: "<FULL_MAGICDNS_NAME>"
  - spec.externalName: currently "placeholder" (set to your external DNS name if used)
- Purpose: Allow cluster workloads to access a target in your tailnet via DNS.
- For many setups this file can remain unused in dev; customize only if needed.

4) Development-only Kubernetes Secret
- File: gitops/apps/app/overlays/dev/secret.yaml
- Contains placeholder values (DB_* and API keys) for local development only.
- DO NOT promote to production. For production, use one of:
  - Sealed Secrets (preferred for GitOps),
  - SOPS, or
  - External Secrets Operator.

Operational notes
- TLS is self-signed (ClusterIssuer: selfsigned-cluster-issuer). Browsers will show a warning. curl requires -k.
- The platform expects Traefik to expose ports 80/443 from the k3d load balancer on your host. This is configured by Terraform.
- If endpoints 404 or 405 during first access, wait 10–20 seconds or run make update-ingress-hosts.

CI/CD and local testing with act
- The workflow is act-friendly:
  - A dedicated build_act job runs on ubuntu-latest when ACT == "true".
  - Deploy and scan jobs are skipped under act to avoid pushing to remote registry and repo.
- To run locally:
  act --container-architecture linux/amd64
- .actrc provides defaults for platforms and dummy tokens.

Security reminders
- Never echo secrets in logs.
- Prefer environment variables and external secret stores.
- All container references in manifests must be pinned by digest. The CI pipeline updates the digest in the dev overlay via kustomize edit set image.

Troubleshooting quick commands
- kubectl get nodes -o wide
- kubectl get applications -n argocd
- kubectl get certificates -A; kubectl describe certificate -n sample-app sample-app-cert
- kubectl get ingress -A; kubectl describe ingress -n sample-app sample-app
- make verify-deployment

