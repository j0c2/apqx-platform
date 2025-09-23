# Tailscale Operator Helm Release
# Installs Tailscale K8s Operator for MagicDNS access to services

resource "helm_release" "tailscale_operator" {
  name             = "tailscale-operator"
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  version          = "1.66.3" # pin to a known-good version for the operator
  namespace        = "tailscale"
  create_namespace = true

  values = [templatefile("${path.module}/values/tailscale-values.yaml.tmpl", {
    tailnet        = var.tailscale_tailnet
    client_id      = var.tailscale_oauth_client_id
    client_secret  = var.tailscale_oauth_client_secret
  })]

  depends_on = [null_resource.k3d_cluster]
}