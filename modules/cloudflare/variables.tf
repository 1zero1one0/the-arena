variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "admin_app_fqdn" {
  description = "Internal FQDN of the admin Container App"
  type        = string
}

variable "admin_hostname" {
  description = "Hostname for the admin app (e.g., admin.systrends.net)"
  type        = string
}
