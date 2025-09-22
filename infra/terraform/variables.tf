# Variables for apqx-platform infrastructure
# Configurable parameters for cluster and application deployment

variable "cluster_name" {
  description = "Name of the k3d cluster"
  type        = string
  default     = "apqx-platform"
}

variable "namespace" {
  description = "Default namespace for applications"
  type        = string
  default     = "default"
}

variable "argocd_namespace" {
  description = "Namespace for Argo CD"
  type        = string
  default     = "argocd"
}

variable "kyverno_namespace" {
  description = "Namespace for Kyverno"
  type        = string
  default     = "kyverno"
}

variable "tailscale_namespace" {
  description = "Namespace for Tailscale operator"
  type        = string
  default     = "tailscale"
}

variable "sealed_secrets_namespace" {
  description = "Namespace for Sealed Secrets"
  type        = string
  default     = "kube-system"
}

# Tailscale configuration placeholders
variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID"
  type        = string
  default     = "<TAILSCALE_OAUTH_CLIENT_ID>"
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  default     = "<TAILSCALE_OAUTH_CLIENT_SECRET>"
  sensitive   = true
}

# Application configuration
variable "app_name" {
  description = "Name of the sample application"
  type        = string
  default     = "sample-app"
}

variable "app_image" {
  description = "Container image for the sample application"
  type        = string
  default     = "ghcr.io/example/sample-app@sha256:placeholder"
}

# Helm chart versions (pinned for reproducibility)
variable "argocd_chart_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "5.51.4"
}

variable "kyverno_chart_version" {
  description = "Kyverno Helm chart version"
  type        = string
  default     = "3.1.1"
}

variable "tailscale_chart_version" {
  description = "Tailscale operator Helm chart version"
  type        = string
  default     = "1.56.1"
}

variable "sealed_secrets_chart_version" {
  description = "Sealed Secrets Helm chart version"
  type        = string
  default     = "2.13.3"
}