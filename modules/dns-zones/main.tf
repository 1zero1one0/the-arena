locals {
  dns_zones = {
    sql      = "privatelink.database.windows.net"
    acr      = "privatelink.azurecr.io"
    keyvault = "privatelink.vaultcore.azure.net"
    blob     = "privatelink.blob.core.windows.net"
    signalr  = "privatelink.signalr.net"
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each = local.dns_zones

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = {
    managed_by = "terraform"
  }
}
