# Tailscale + CoreDNS Setup (Optional)

This document outlines an optional enhancement to improve name resolution for Tailscale-served services.

When you expose services through the Tailscale operator, MagicDNS provides names like:
- app-onprem.<tailnet>.ts.net

If you want cluster workloads to resolve external tailnet services via DNS:
- Add an ExternalName Service (see gitops/apps/app/overlays/dev/ts-egress-externalname.yaml)
- Optionally integrate CoreDNS stub domains for your tailnet FQDN.

Example ExternalName Service:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ts-egress
  namespace: sample-app
  annotations:
    tailscale.com/tailnet-fqdn: "<FULL_MAGICDNS_NAME>" # e.g., my-db.tail1234.ts.net
spec:
  externalName: placeholder
  type: ExternalName
```

Notes
- This is entirely optional for the take-home; most users won’t need it for the demo.
- Keep secrets and tailnet details out of Git; use placeholders.
