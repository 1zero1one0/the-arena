locals {
  environment   = "shared"
  naming_suffix = "${var.project}-${local.environment}-${var.location}-001"
  tags = {
    project     = var.project
    environment = local.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-${local.naming_suffix}"
  location = var.location
  tags     = local.tags
}

module "acr" {
  source = "../../modules/acr"

  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  project             = var.project
}

module "dns_zones" {
  source = "../../modules/dns-zones"

  resource_group_name = azurerm_resource_group.shared.name
}
