output "cluster_name" {
  value       = local.cluster_name
  description = "Name of the k3d cluster"
}

output "kubeconfig_path" {
  value       = local.kubeconfig_path
  description = "Path to kubeconfig file used by providers"
}
