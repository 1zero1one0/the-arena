output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "container_apps_environment_id" {
  value = module.container_apps.environment_id
}

output "container_apps_default_domain" {
  value = module.container_apps.default_domain
}

output "container_apps_identity_id" {
  value = module.container_apps.managed_identity_id
}

output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}

output "tunnel_id" {
  value = module.cloudflare.tunnel_id
}

output "tunnel_token" {
  value     = module.cloudflare.tunnel_token
  sensitive = true
}

output "tunnel_cname" {
  value = module.cloudflare.tunnel_cname
}

output "admin_app_fqdn" {
  value = module.container_apps.admin_app_fqdn
}

output "admin_url" {
  value = "https://admin.staging.systrends.net"
}
