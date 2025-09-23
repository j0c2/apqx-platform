variable "tailscale_tailnet" {
  description = "Tailscale tailnet name (e.g., yourname.gmail.com)"
  type        = string
  default     = ""
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID for the Tailscale operator"
  type        = string
  default     = ""
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret for the Tailscale operator"
  type        = string
  sensitive   = true
  default     = ""
}
