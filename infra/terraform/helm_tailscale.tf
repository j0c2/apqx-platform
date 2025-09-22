# Tailscale operator Helm chart deployment for secure networking
# Deploys Tailscale operator with OAuth credentials for MagicDNS

resource "helm_release" "tailscale_operator" {
  name       = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = var.tailscale_chart_version
  namespace  = var.tailscale_namespace

  # Tailscale operator configuration with OAuth
  values = [yamlencode({
    operatorConfig = {
      image = {
        repository = "tailscale/tailscale"
        tag        = "v1.56.1@sha256:8b17b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0"
        pullPolicy = "IfNotPresent"
      }

      # OAuth credentials for Tailscale API access
      oauth = {
        clientId     = var.tailscale_oauth_client_id
        clientSecret = var.tailscale_oauth_client_secret
      }

      # Default tags for all Tailscale resources
      defaultTags = ["k8s", "apqx-platform"]

      # Resource limits for local development
      resources = {
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }

    # Proxy configuration
    proxyConfig = {
      image = {
        repository = "tailscale/tailscale"
        tag        = "v1.56.1@sha256:8b17b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0"
        pullPolicy = "IfNotPresent"
      }

      # Default proxy configuration
      defaultTags = ["k8s-proxy", "apqx-platform"]
      
      # Resource limits for proxies
      resources = {
        limits = {
          cpu    = "250m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }
    }
  })]

  depends_on = [kubernetes_namespace.tailscale]

  # Wait for deployment to be ready
  wait    = true
  timeout = 300
}

# Tailscale ingress for the sample application
resource "kubernetes_manifest" "app_tailscale_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "${var.app_name}-tailscale"
      namespace = var.namespace
      labels    = local.common_labels
      annotations = {
        "tailscale.com/expose"      = "true"
        "tailscale.com/hostname"    = "app"
        "tailscale.com/tags"        = "k8s,apqx-platform,app"
        "tailscale.com/tailnet-fqdn" = "app.<tailnet>.ts.net"
      }
    }
    spec = {
      ingressClassName = "tailscale"
      tls = [
        {
          hosts = ["app.<tailnet>.ts.net"]
        }
      ]
      rules = [
        {
          host = "app.<tailnet>.ts.net"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = var.app_name
                    port = {
                      number = 8080
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [helm_release.tailscale_operator]
}

# Tailscale ingress for Argo CD
resource "kubernetes_manifest" "argocd_tailscale_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "argocd-tailscale"
      namespace = var.argocd_namespace
      labels    = local.common_labels
      annotations = {
        "tailscale.com/expose"        = "true"
        "tailscale.com/hostname"      = "argocd"
        "tailscale.com/tags"          = "k8s,apqx-platform,argocd"
        "tailscale.com/tailnet-fqdn" = "argocd.<tailnet>.ts.net"
      }
    }
    spec = {
      ingressClassName = "tailscale"
      tls = [
        {
          hosts = ["argocd.<tailnet>.ts.net"]
        }
      ]
      rules = [
        {
          host = "argocd.<tailnet>.ts.net"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "argocd-server"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [helm_release.tailscale_operator]
}