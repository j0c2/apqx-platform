locals {
  cluster_name    = "k3d-onprem"
  kubeconfig_path = pathexpand("~/.kube/config")
}

resource "null_resource" "k3d_cluster" {
  # Create cluster (1 server, 1 agent; expose 80/443 on agent:0)
  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if ! k3d cluster list | grep -q "^${local.cluster_name}\\b"; then
        k3d cluster create ${local.cluster_name} \
          --servers 1 \
          --agents 1 \
          --port "80:80@agent:0" \
          --port "443:443@agent:0" \
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
    command = "k3d cluster delete k3d-onprem || true"
  }

  triggers = {
    cluster_name = local.cluster_name
  }
}
