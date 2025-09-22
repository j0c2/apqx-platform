# Outputs for apqx-platform infrastructure
# Exposes important cluster and application information

output "cluster_name" {
  description = "Name of the k3d cluster"
  value       = k3d_cluster.main.name
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = k3d_cluster.main.kubeconfig[0].cluster_ca_certificate != "" ? "https://localhost:6443" : ""
}

output "local_ip" {
  description = "Local IP address for sslip.io DNS"
  value       = local.local_ip
}

output "app_url_local" {
  description = "Local application URL using sslip.io"
  value       = "http://app.${local.local_ip}.sslip.io/"
}

output "app_url_tailscale" {
  description = "Tailscale application URL (placeholder)"
  value       = "https://app<name>.<tailnet>.net"
}

output "argocd_url_local" {
  description = "Local Argo CD URL using sslip.io"
  value       = "http://argocd.${local.local_ip}.sslip.io/"
}

output "argocd_namespace" {
  description = "Argo CD namespace"
  value       = var.argocd_namespace
}

output "kyverno_namespace" {
  description = "Kyverno namespace"
  value       = var.kyverno_namespace
}

output "tailscale_namespace" {
  description = "Tailscale operator namespace"
  value       = var.tailscale_namespace
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = k3d_cluster.main.kubeconfig[0].config_path
}

# Sensitive outputs (use terraform output -json to retrieve)
output "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID (placeholder)"
  value       = var.tailscale_oauth_client_id
  sensitive   = true
}

output "cluster_ready" {
  description = "Cluster readiness indicator"
  value       = time_sleep.cluster_ready.id != "" ? true : false
}