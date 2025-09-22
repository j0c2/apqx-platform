# Kyverno Helm Release
# Installs Kyverno for baseline Kubernetes security policies

resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = "3.1.4" # pin
  namespace        = "kyverno"
  create_namespace = true
  values           = [file("${path.module}/values/kyverno-values.yaml")]
  depends_on       = [null_resource.k3d_cluster]
}