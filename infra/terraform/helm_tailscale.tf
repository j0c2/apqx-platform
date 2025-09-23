# Installs Tailscale K8s Operator for MagicDNS access to services

# Ensure namespace exists explicitly (before creating secret)
resource "kubernetes_namespace" "tailscale" {
  metadata {
    name = "tailscale"
  }
  depends_on = [null_resource.k3d_cluster]
}

# Create OAuth secret without committing credentials to code
# Pass via TF_VAR_tailscale_client_id and TF_VAR_tailscale_client_secret
resource "kubernetes_secret" "tailscale_operator_oauth" {
  metadata {
    name      = "operator-oauth"
    namespace = kubernetes_namespace.tailscale.metadata[0].name
  }
  type = "Opaque"

  string_data = {
    client_id     = var.tailscale_client_id
    client_secret = var.tailscale_client_secret
  }

  depends_on = [kubernetes_namespace.tailscale]
}

resource "helm_release" "tailscale_operator" {
  name       = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = "1.88.2"
  namespace  = kubernetes_namespace.tailscale.metadata[0].name

  values = [templatefile("${path.module}/values/tailscale-values.yaml.tmpl", {
    tailnet = var.tailscale_tailnet
  })]

  depends_on = [
    null_resource.k3d_cluster,
    kubernetes_secret.tailscale_operator_oauth
  ]
}
