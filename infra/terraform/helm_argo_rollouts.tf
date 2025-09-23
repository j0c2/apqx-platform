# Argo Rollouts Helm Chart Installation
# Progressive delivery and canary deployments for Kubernetes

resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = "2.40.4" # pin specific version
  namespace        = "argo-rollouts"
  create_namespace = true
  
  values = [
    file("${path.module}/values/rollouts-values.yaml")
  ]
  
  depends_on = [null_resource.k3d_cluster]
}