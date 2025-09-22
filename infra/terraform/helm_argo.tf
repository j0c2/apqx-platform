resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true
  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]
  depends_on = [null_resource.k3d_cluster]
}