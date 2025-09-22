# Sealed Secrets Helm chart deployment for encrypted secret management
# Deploys Sealed Secrets controller for secure GitOps secret handling

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = var.sealed_secrets_chart_version
  namespace  = var.sealed_secrets_namespace

  # Sealed Secrets controller configuration with pinned image
  values = [yamlencode({
    image = {
      repository = "quay.io/bitnami/sealed-secrets-controller"
      tag        = "v0.24.0@sha256:8b17b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0"
      pullPolicy = "IfNotPresent"
    }

    # Controller configuration
    controller = {
      # Create cluster-wide controller
      create = true

      # Key rotation settings
      keyrenewperiod = "30d"

      # Resource limits for local development
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

      # Security context
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 1001
        fsGroup      = 65534
      }

      # Pod security context
      podSecurityContext = {
        fsGroup = 65534
      }
    }

    # Service configuration
    service = {
      type = "ClusterIP"
      port = 8080
    }

    # RBAC configuration
    rbac = {
      create = true
      pspEnabled = false
    }

    # Service account configuration
    serviceAccount = {
      create = true
      name   = "sealed-secrets-controller"
      annotations = {}
    }

    # Namespace configuration
    namespace = {
      create = false
      name   = var.sealed_secrets_namespace
    }

    # CRD configuration
    crd = {
      create = true
      keep   = false
    }

    # Network policy (disabled for local development)
    networkPolicy = {
      enabled = false
    }

    # Pod disruption budget
    podDisruptionBudget = {
      enabled        = false
      minAvailable   = 1
      maxUnavailable = ""
    }

    # Ingress (disabled - not needed for controller)
    ingress = {
      enabled = false
    }

    # Metrics configuration
    metrics = {
      serviceMonitor = {
        enabled = false
      }
      dashboards = {
        create = false
      }
    }

    # Additional labels
    labels = local.common_labels

    # Log level
    logLevel = "info"

    # Additional arguments
    additionalNamespaces = [
      var.argocd_namespace,
      var.namespace,
      var.tailscale_namespace
    ]

    # Priority class
    priorityClassName = ""

    # Node selector
    nodeSelector = {}

    # Tolerations
    tolerations = []

    # Affinity
    affinity = {}
  })]

  # Wait for deployment to be ready
  wait    = true
  timeout = 300
}

# Create a sample sealed secret for demonstration
resource "kubernetes_manifest" "sample_sealed_secret" {
  manifest = {
    apiVersion = "bitnami.com/v1alpha1"
    kind       = "SealedSecret"
    metadata = {
      name      = "sample-secret"
      namespace = var.namespace
      labels    = local.common_labels
    }
    spec = {
      encryptedData = {
        # This is a placeholder - in real usage, this would be encrypted using kubeseal CLI
        # Example: echo -n "secret-value" | kubeseal --raw --from-file=/dev/stdin --name sample-secret --namespace default
        username = "AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx..."
        password = "AgAKAoiQm1i2f+Qo9kh7dKJ2L5m8nN9p0..."
      }
      template = {
        metadata = {
          name      = "sample-secret"
          namespace = var.namespace
        }
        type = "Opaque"
      }
    }
  }

  depends_on = [helm_release.sealed_secrets]

  # This resource is for demonstration only - actual sealed secrets would be created externally
  lifecycle {
    ignore_changes = [manifest["spec"]["encryptedData"]]
  }
}