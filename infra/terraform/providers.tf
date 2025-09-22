# Provider configuration for apqx-platform
# Configures Helm, Kubernetes, and null providers for k3d management

terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Kubernetes provider configuration
# Uses local kubeconfig from k3d cluster
provider "kubernetes" {
  config_path = local.kubeconfig_path
}

# Helm provider configuration
# Uses local kubeconfig from k3d cluster
provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}
