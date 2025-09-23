#!/usr/bin/env bash
set -euo pipefail

# Updates ingress hosts and TLS hosts to current LOCAL_IP for sslip.io
# Usage: scripts/setup/update-ingress-hosts.sh

LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [[ -z "${LOCAL_IP:-}" ]]; then
  echo "Could not determine LOCAL_IP" >&2
  exit 1
fi

echo "Updating ingress hosts to *.${LOCAL_IP}.sslip.io"

# ArgoCD
kubectl patch ingress argocd-server-ingress -n argocd --type=json -p="[
  {"op":"add","path":"/spec/ingressClassName","value":"traefik"},
  {"op":"replace","path":"/spec/rules/0/host","value":"argocd.${LOCAL_IP}.sslip.io"},
  {"op":"replace","path":"/spec/tls/0/hosts/0","value":"argocd.${LOCAL_IP}.sslip.io"},
  {"op":"add","path":"/spec/tls/0/secretName","value":"argocd-sslip-tls"}
]" >/dev/null

# Sample App (stable service)
kubectl patch ingress sample-app -n sample-app --type=json -p="[
  {"op":"add","path":"/spec/ingressClassName","value":"traefik"},
  {"op":"replace","path":"/spec/rules/0/host","value":"app.${LOCAL_IP}.sslip.io"},
  {"op":"replace","path":"/spec/tls/0/hosts/0","value":"app.${LOCAL_IP}.sslip.io"},
  {"op":"add","path":"/spec/tls/0/secretName","value":"app-sslip-tls"}
]" >/dev/null

# Argo Rollouts Dashboard
kubectl patch ingress argo-rollouts-dashboard-ingress -n argo-rollouts --type=json -p="[
  {"op":"add","path":"/spec/ingressClassName","value":"traefik"},
  {"op":"replace","path":"/spec/rules/0/host","value":"rollouts.${LOCAL_IP}.sslip.io"},
  {"op":"replace","path":"/spec/tls/0/hosts/0","value":"rollouts.${LOCAL_IP}.sslip.io"},
  {"op":"add","path":"/spec/tls/0/secretName","value":"rollouts-sslip-tls"}
]" >/dev/null

echo "Ingress hosts updated to current LOCAL_IP (${LOCAL_IP})"
