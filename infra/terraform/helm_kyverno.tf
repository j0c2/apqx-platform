# Kyverno Helm chart deployment for policy management
# Deploys Kyverno with security and governance policies

resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = var.kyverno_chart_version
  namespace        = var.kyverno_namespace
  create_namespace = false

  # Minimal configuration with pinned images
  values = [yamlencode({
    image = {
      repository = "ghcr.io/kyverno/kyverno"
      tag        = "v1.11.0@sha256:c37dd24a8a06afd6f5cc63a468f4b5c9e49984eb34d8d8b0b1d5e4dc90d4e4c5"
      pullPolicy = "IfNotPresent"
    }

    initImage = {
      repository = "ghcr.io/kyverno/kyvernopre"
      tag        = "v1.11.0@sha256:7b17b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0"
      pullPolicy = "IfNotPresent"
    }

    # Resource limits for local development
    resources = {
      limits = {
        cpu    = "1000m"
        memory = "512Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }

    # Webhook configuration
    webhooksTimeoutSeconds = 10

    # Generate default policies
    generatecontrollerExtraResources = [
      "NetworkPolicy",
      "Deployment"
    ]

    # Background controller configuration
    backgroundController = {
      enabled = true
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }
    }

    # Cleanup controller configuration
    cleanupController = {
      enabled = true
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }
    }

    # Reports controller configuration
    reportsController = {
      enabled = true
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }
    }
  })]

  depends_on = [kubernetes_namespace.kyverno]

  # Wait for deployment to be ready
  wait    = true
  timeout = 300
}

# Basic security policies
resource "kubernetes_manifest" "disallow_latest_tag_policy" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name   = "disallow-latest-tag"
      labels = local.common_labels
      annotations = {
        "policies.kyverno.io/title"       = "Disallow Latest Tag"
        "policies.kyverno.io/category"    = "Best Practices"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/description" = "Require container images to use specific digest or tag (not latest)"
      }
    }
    spec = {
      validationFailureAction = "enforce"
      background              = true
      rules = [
        {
          name  = "require-image-tag"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          validate = {
            message = "Using latest tag or no tag is not allowed. Please use a specific digest or version tag."
            pattern = {
              spec = {
                containers = [
                  {
                    image = "!*:latest | !*@*"
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}

# Require resource limits
resource "kubernetes_manifest" "require_pod_resources_policy" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name   = "require-pod-resources"
      labels = local.common_labels
      annotations = {
        "policies.kyverno.io/title"       = "Require Pod Resources"
        "policies.kyverno.io/category"    = "Best Practices"
        "policies.kyverno.io/severity"    = "medium"
        "policies.kyverno.io/description" = "Require CPU and memory resource limits on pods"
      }
    }
    spec = {
      validationFailureAction = "enforce"
      background              = true
      rules = [
        {
          name  = "validate-resources"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          exclude = {
            any = [
              {
                resources = {
                  namespaces = [var.argocd_namespace, var.kyverno_namespace, var.tailscale_namespace, "kube-system"]
                }
              }
            ]
          }
          validate = {
            message = "Resource requests and limits are required."
            pattern = {
              spec = {
                containers = [
                  {
                    resources = {
                      requests = {
                        memory = "?*"
                        cpu    = "?*"
                      }
                      limits = {
                        memory = "?*"
                        cpu    = "?*"
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.kyverno]
}