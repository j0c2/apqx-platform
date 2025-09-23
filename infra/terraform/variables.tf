variable "tailscale_tailnet" {
  description = "Tailscale tailnet name (e.g., yourname.gmail.com)"
  type        = string
  default     = ""
}

# Recommended variable names for operator OAuth credentials
variable "tailscale_client_id" {
  description = "Tailscale OAuth client ID for the Tailscale operator"
  type        = string
  sensitive   = true
}

variable "tailscale_client_secret" {
  description = "Tailscale OAuth client secret for the Tailscale operator"
  type        = string
  sensitive   = true
}
