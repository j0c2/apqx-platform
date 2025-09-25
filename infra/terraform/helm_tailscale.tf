# Installs Tailscale K8s Operator for MagicDNS access to services
# Only deploys when enable_tailscale is true and credentials are provided

# Auto-detect if Tailscale should be enabled based on provided credentials
locals {
  tailscale_enabled = var.enable_tailscale && var.tailscale_client_id != "" && var.tailscale_client_secret != ""
}

resource "helm_release" "tailscale_operator" {
  count = local.tailscale_enabled ? 1 : 0
  depends_on = [
    null_resource.k3d_cluster,
    helm_release.argocd
  ]
  name             = "tailscale-operator"
  create_namespace = true
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  version          = "1.88.2"
  namespace        = "tailscale"

  values = [templatefile("${path.module}/values/tailscale-values.yaml.tmpl", {
    tailnet       = var.tailscale_tailnet
    client_id     = var.tailscale_client_id
    client_secret = var.tailscale_client_secret
  })]
}
