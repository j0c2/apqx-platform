variable "server_count" {
  description = "Number of k3d server nodes"
  type        = number
  default     = 1
}

variable "agent_count" {
  description = "Number of k3d agent nodes"
  type        = number
  default     = 1
}

variable "http_host_port" {
  description = "Host port mapped to the k3d load balancer's port 80"
  type        = number
  default     = 80
}

variable "https_host_port" {
  description = "Host port mapped to the k3d load balancer's port 443"
  type        = number
  default     = 443
}

locals {
  cluster_name    = "k3d-onprem"
  kubeconfig_path = pathexpand("~/.kube/config")

  # Fingerprint of critical cluster config to force recreation when changed
  cluster_config_fingerprint = sha1(jsonencode({
    servers = var.server_count
    agents  = var.agent_count
    ports   = {
      http  = var.http_host_port
      https = var.https_host_port
    }
  }))
}

resource "null_resource" "k3d_cluster" {
  # Create cluster (parameterized counts; expose HTTP/HTTPS on load balancer)
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if ! k3d cluster list | grep -q "^${local.cluster_name}\\b"; then
        k3d cluster create ${local.cluster_name} \
          --servers ${var.server_count} \
          --agents ${var.agent_count} \
          --port "${var.http_host_port}:80@loadbalancer" \
          --port "${var.https_host_port}:443@loadbalancer" \
          --wait
      else
        echo "Cluster ${local.cluster_name} already exists; skipping create"
      fi
    EOT
  }

  # Merge kubeconfig & switch context
  provisioner "local-exec" {
    command = "k3d kubeconfig merge ${local.cluster_name} --kubeconfig-switch-context"
  }

  # Wait for nodes Ready
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Ready nodes --all --timeout=300s"
  }

  # Destroy cluster
  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name} || true"
  }

triggers = {
    cluster_name = local.cluster_name
    fp           = local.cluster_config_fingerprint
  }
}
