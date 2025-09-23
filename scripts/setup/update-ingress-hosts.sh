#!/usr/bin/env bash
set -euo pipefail

# Updates ingress hosts and TLS hosts to current LOCAL_IP for sslip.io
# Usage: scripts/setup/update-ingress-hosts.sh

# Allow override via env var
if [[ -n "${LOCAL_IP:-}" ]]; then
  DETECTED_IP="$LOCAL_IP"
else
  # Prefer default route interface on macOS, fallback to Linux, finally generic
  DETECTED_IP=$( \
    (route -n get default 2>/dev/null | awk '/interface:/{print $2}' | xargs -I{} ipconfig getifaddr {} 2>/dev/null) || \
    (ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}') || \
    (ifconfig | awk '/inet /{print $2}' | grep -Ev '^(127\.|169\.254\.|100\.)' | head -1) \
  )
fi

if [[ -z "${DETECTED_IP:-}" ]]; then
  echo "Could not determine LOCAL_IP" >&2
  exit 1
fi
LOCAL_IP="$DETECTED_IP"

echo "Updating ingress hosts to *.${LOCAL_IP}.sslip.io"

# ArgoCD (merge patch)
kubectl patch ingress argocd-server-ingress -n argocd --type=merge -p '{
  "spec": {
    "ingressClassName": "traefik",
    "tls": [{"hosts": ["argocd.'"${LOCAL_IP}"'.sslip.io"], "secretName": "argocd-sslip-tls"}],
    "rules": [{"host": "argocd.'"${LOCAL_IP}"'.sslip.io", "http": {"paths": [{"path": "/", "pathType": "Prefix", "backend": {"service": {"name": "argocd-server", "port": {"number": 80}}}}]}}]
  }
}' >/dev/null

# Sample App (stable service)
kubectl patch ingress sample-app -n sample-app --type=merge -p '{
  "spec": {
    "ingressClassName": "traefik",
    "tls": [{"hosts": ["app.'"${LOCAL_IP}"'.sslip.io"], "secretName": "app-sslip-tls"}],
    "rules": [{"host": "app.'"${LOCAL_IP}"'.sslip.io", "http": {"paths": [{"path": "/", "pathType": "Prefix", "backend": {"service": {"name": "sample-app-stable", "port": {"number": 80}}}}]}}]
  }
}' >/dev/null

# Argo Rollouts Dashboard
kubectl patch ingress argo-rollouts-dashboard-ingress -n argo-rollouts --type=merge -p '{
  "spec": {
    "ingressClassName": "traefik",
    "tls": [{"hosts": ["rollouts.'"${LOCAL_IP}"'.sslip.io"], "secretName": "rollouts-sslip-tls"}],
    "rules": [{"host": "rollouts.'"${LOCAL_IP}"'.sslip.io", "http": {"paths": [{"path": "/rollouts/", "pathType": "Prefix", "backend": {"service": {"name": "argo-rollouts-dashboard", "port": {"number": 3100}}}}]}}]
  }
}' >/dev/null

echo "Ingress hosts updated to current LOCAL_IP (${LOCAL_IP})"
