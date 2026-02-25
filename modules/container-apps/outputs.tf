output "environment_id" {
  value = azurerm_container_app_environment.main.id
}

output "default_domain" {
  value = azurerm_container_app_environment.main.default_domain
}

output "static_ip" {
  value = azurerm_container_app_environment.main.static_ip_address
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.container_apps.id
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.container_apps.client_id
}

output "managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.container_apps.principal_id
}

output "admin_app_fqdn" {
  value = azurerm_container_app.admin.ingress[0].fqdn
}
