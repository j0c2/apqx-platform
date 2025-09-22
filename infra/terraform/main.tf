# Main Terraform configuration for apqx-platform
# Provisions k3d cluster and deploys core platform components

terraform {
  required_providers {
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "~> 0.0.7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
  }
  required_version = ">= 1.6"
}

# Local variables for configuration
locals {
  cluster_name = var.cluster_name
  
  # Get local IP for sslip.io DNS
  local_ip = chomp(data.external.local_ip.result.ip)
  
  # Common labels
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"   = "apqx-platform"
  }
}

# Get local IP address for sslip.io DNS
data "external" "local_ip" {
  program = ["sh", "-c", "echo '{\"ip\":\"'$(ipconfig getifaddr en0 || hostname -I | cut -d' ' -f1)'\"}'"]
}

# Create k3d cluster
resource "k3d_cluster" "main" {
  name    = local.cluster_name
  servers = 1
  agents  = 0

  kubeconfig {
    update_default_kubeconfig = true
    switch_current_context     = true
  }

  k3d {
    disable_load_balancer = false
    disable_image_volume  = false
  }

  k3s {
    extra_args {
      arg          = "--disable=traefik"
      node_filters = ["server:*"]
    }
  }

  port {
    host_port      = 80
    container_port = 80
    node_filters   = ["loadbalancer"]
  }

  port {
    host_port      = 443
    container_port = 443
    node_filters   = ["loadbalancer"]
  }
}

# Wait for cluster to be ready
resource "time_sleep" "cluster_ready" {
  create_duration = "30s"
  depends_on      = [k3d_cluster.main]
}