locals {
  # ACR names must be alphanumeric only, 5-50 chars
  acr_name = "cr${var.project}${replace(var.location, "-", "")}001"
}

resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = {
    project    = var.project
    managed_by = "terraform"
  }
}
