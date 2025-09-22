# k3d cluster configuration for apqx-platform
# Manages k3d-specific cluster settings and networking

# Create required namespaces
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "argocd"
    })
  }
  depends_on = [time_sleep.cluster_ready]
}

resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = var.kyverno_namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "kyverno"
    })
  }
  depends_on = [time_sleep.cluster_ready]
}

resource "kubernetes_namespace" "tailscale" {
  metadata {
    name = var.tailscale_namespace
    labels = merge(local.common_labels, {
      "app.kubernetes.io/component" = "tailscale"
    })
  }
  depends_on = [time_sleep.cluster_ready]
}

# Traefik IngressRoute for routing
resource "kubernetes_manifest" "traefik_ingressroute" {
  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "app-ingressroute"
      namespace = var.namespace
      labels    = local.common_labels
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`app.${local.local_ip}.sslip.io`)"
          kind  = "Rule"
          services = [
            {
              name = var.app_name
              port = 8080
            }
          ]
        }
      ]
    }
  }
  depends_on = [time_sleep.cluster_ready]
}

# Traefik IngressRoute for Argo CD
resource "kubernetes_manifest" "argocd_ingressroute" {
  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "argocd-ingressroute"
      namespace = var.argocd_namespace
      labels    = local.common_labels
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`argocd.${local.local_ip}.sslip.io`)"
          kind  = "Rule"
          services = [
            {
              name = "argocd-server"
              port = 80
            }
          ]
        }
      ]
    }
  }
  depends_on = [kubernetes_namespace.argocd]
}