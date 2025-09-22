# Provider configuration for apqx-platform
# Configures k3d, Helm, and Kubernetes providers

# k3d provider for cluster management
provider "k3d" {}

# Kubernetes provider configuration
provider "kubernetes" {
  config_path = k3d_cluster.main.kubeconfig[0].config_path
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    config_path = k3d_cluster.main.kubeconfig[0].config_path
  }
}

# External data provider for local IP detection
data "external" "local_ip_check" {
  program = ["sh", "-c", "command -v ipconfig >/dev/null 2>&1 && echo '{\"available\":\"true\"}' || echo '{\"available\":\"false\"}'"]
}

# Time provider for cluster readiness delays
terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}