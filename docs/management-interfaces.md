# Management Interfaces

This document summarizes ways to access core platform UIs in development.

Argo CD (GitOps UI)
- Port-forward method (recommended in dev):
  ```bash
  kubectl port-forward -n argocd svc/argocd-server 8080:80 &
  echo "URL: http://localhost:8080"
  echo "User: admin"
  echo "Pass: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
  ```
- Ingress method (sslip.io):
  ```bash
  LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
  open https://argocd.$LOCAL_IP.sslip.io
  ```

Argo Rollouts Dashboard
- Ingress (sslip.io):
  ```bash
  LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
  open https://rollouts.$LOCAL_IP.sslip.io/rollouts/
  ```

Sample App
- Ingress (sslip.io):
  ```bash
  LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
  curl -k https://app.$LOCAL_IP.sslip.io/api/status | jq
  ```
- Port-forward helper (when 80/443 are not available):
  ```bash
  make access
  # then:
  TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  curl -sk -H "Host: app.$TRAEFIK_IP.sslip.io" https://localhost:8443/api/status | jq
  ```
