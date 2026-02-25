variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_id" {
  description = "Container Apps infrastructure subnet ID (/21 minimum)"
  type        = string
}

variable "acr_id" {
  description = "Container Registry resource ID"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server URL"
  type        = string
}

variable "tunnel_token" {
  description = "Cloudflare tunnel token"
  type        = string
  sensitive   = true
}

# Admin app secrets
variable "rails_master_key" {
  type      = string
  sensitive = true
}

variable "entra_client_secret" {
  type      = string
  sensitive = true
}

variable "sendlayer_api_key" {
  type      = string
  sensitive = true
}

# Admin app config
variable "entra_tenant_id" {
  type = string
}

variable "entra_tenant_domain" {
  type = string
}

variable "entra_client_id" {
  type = string
}

variable "sendlayer_sender_email" {
  type    = string
  default = "noreply@systrends.com"
}

variable "sendlayer_sender_name" {
  type    = string
  default = "The Portal"
}
