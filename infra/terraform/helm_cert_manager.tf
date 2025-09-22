# cert-manager Helm Release
# Installs cert-manager for TLS certificate management

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.4" # pin
  namespace        = "cert-manager"
  create_namespace = true
  values           = [file("${path.module}/values/cert-manager-values.yaml")]
  depends_on       = [null_resource.k3d_cluster]
}