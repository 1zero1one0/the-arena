variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "centralus"
}

variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "arena"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare DNS zone ID"
  type        = string
}

variable "acr_id" {
  description = "ACR resource ID from shared environment"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server URL from shared environment"
  type        = string
}

variable "dns_zone_ids" {
  description = "Map of private DNS zone IDs from shared environment"
  type        = map(string)
}

variable "dns_zone_names" {
  description = "Map of private DNS zone names from shared environment"
  type        = map(string)
}

variable "shared_resource_group_name" {
  description = "Name of the shared resource group (for DNS zone links)"
  type        = string
  default     = "rg-arena-shared-centralus-001"
}

variable "admin_hostname" {
  description = "Hostname for the admin app"
  type        = string
  default     = "admin.staging.systrends.net"
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
