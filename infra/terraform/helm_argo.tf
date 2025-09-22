# Argo CD Helm chart deployment for GitOps
# Deploys Argo CD with minimal configuration for GitOps workflows

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = false

  # Minimal configuration for local development
  values = [yamlencode({
    global = {
      image = {
        tag = "v2.9.3@sha256:2e62de5a5c85cf3bfe89317ad37f2aaf97c8e05b5c7f6b1ceb82b6acc93b9b80"
      }
    }
    
    server = {
      service = {
        type = "ClusterIP"
        port = 80
      }
      
      # Disable HTTPS for local development
      extraArgs = ["--insecure"]
      
      config = {
        "url" = "http://argocd.${local.local_ip}.sslip.io"
        "application.instanceLabelKey" = "argocd.argoproj.io/instance"
        
        # Repository configuration for this Git repo
        repositories = |
          - type: git
            url: https://github.com/example/apqx-platform
            name: apqx-platform
      }
      
      # RBAC configuration
      rbacConfig = {
        "policy.default" = "role:readonly"
        "policy.csv" = <<-EOT
          p, role:admin, applications, *, */*, allow
          p, role:admin, clusters, *, *, allow
          p, role:admin, repositories, *, *, allow
          g, argocd-admins, role:admin
        EOT
      }
    }
    
    # Controller configuration
    controller = {
      image = {
        tag = "v2.9.3@sha256:17c5eb4d312f762e6ed0866c6c1e9df15c9bf43ea6febb4b5f1a8e43c7e57b4d"
      }
    }
    
    # Repo server configuration
    repoServer = {
      image = {
        tag = "v2.9.3@sha256:8b17b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0"
      }
    }
    
    # Dex configuration (disabled for local development)
    dex = {
      enabled = false
    }
    
    # Notifications controller
    notifications = {
      enabled = false
    }
    
    # ApplicationSet controller
    applicationSet = {
      enabled = true
      image = {
        tag = "v0.4.1@sha256:4f5e8b4b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0f1b3b3b0"
      }
    }
  })]

  depends_on = [kubernetes_namespace.argocd]

  # Wait for deployment to be ready
  wait = true
  timeout = 600
}

# Initial admin password secret retrieval
resource "kubernetes_secret" "argocd_initial_admin_secret" {
  depends_on = [helm_release.argocd]
  
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.argocd_namespace
  }
  
  lifecycle {
    ignore_changes = [data]
  }
}

# App-of-apps pattern: Root application that manages all other applications
resource "kubernetes_manifest" "root_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root-app"
      namespace = var.argocd_namespace
      labels    = local.common_labels
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/example/apqx-platform"
        path           = "gitops/apps"
        targetRevision = "HEAD"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
  
  depends_on = [helm_release.argocd]
}