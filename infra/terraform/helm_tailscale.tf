# Installs Tailscale K8s Operator for MagicDNS access to services
# Only deploys when enable_tailscale is true and credentials are provided

# Auto-detect if Tailscale should be enabled based on provided credentials
locals {
  tailscale_enabled = var.enable_tailscale && var.tailscale_client_id != "" && var.tailscale_client_secret != ""
}

# Ensure namespace exists explicitly (before creating secret)
resource "kubernetes_namespace" "tailscale" {
  count      = local.tailscale_enabled ? 1 : 0
  depends_on = [null_resource.k3d_cluster]
  metadata {
    name = "tailscale"
  }
}

# Create OAuth secret without committing credentials to code
# Pass via TF_VAR_tailscale_client_id and TF_VAR_tailscale_client_secret
resource "kubernetes_secret" "tailscale_operator_oauth" {
  count      = local.tailscale_enabled ? 1 : 0
  depends_on = [null_resource.k3d_cluster, kubernetes_namespace.tailscale]
  metadata {
    name      = "operator-oauth"
    namespace = kubernetes_namespace.tailscale[0].metadata[0].name
  }
  type = "Opaque"

  # Kubernetes provider automatically base64-encodes data for Secrets
  data = {
    client_id     = var.tailscale_client_id
    client_secret = var.tailscale_client_secret
  }
}

resource "helm_release" "tailscale_operator" {
  count = local.tailscale_enabled ? 1 : 0
  depends_on = [
    null_resource.k3d_cluster,
    kubernetes_namespace.tailscale,
    kubernetes_secret.tailscale_operator_oauth
  ]
  name       = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = "1.88.2"
  namespace  = kubernetes_namespace.tailscale[0].metadata[0].name

  values = [templatefile("${path.module}/values/tailscale-values.yaml.tmpl", {
    tailnet = var.tailscale_tailnet
  })]
}
