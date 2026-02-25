output "resource_group_name" {
  value = azurerm_resource_group.shared.name
}

output "acr_id" {
  value = module.acr.acr_id
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "acr_name" {
  value = module.acr.acr_name
}

output "dns_zone_ids" {
  value = module.dns_zones.zone_ids
}

output "dns_zone_names" {
  value = module.dns_zones.zone_names
}
