locals {
  environment   = "stg"
  naming_suffix = "${var.project}-${local.environment}-${var.location}-001"
  tags = {
    project     = var.project
    environment = local.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.naming_suffix}"
  location = var.location
  tags     = local.tags
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = local.environment
  vnet_address_space  = ["10.2.0.0/16"]

  subnets = {
    container-apps = {
      address_prefixes = ["10.2.0.0/21"]
      delegations      = ["Microsoft.App/environments"]
    }
    private-endpoints = {
      address_prefixes = ["10.2.10.0/24"]
      delegations      = []
    }
    cloudflare = {
      address_prefixes = ["10.2.11.0/24"]
      delegations      = []
    }
  }

  # Link shared DNS zones to this VNet
  dns_zone_names               = var.dns_zone_names
  dns_zone_resource_group_name = var.shared_resource_group_name
}

module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = local.environment
  retention_days      = 30
}

module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = local.environment
  subnet_id           = module.networking.subnet_ids["private-endpoints"]
  dns_zone_id         = var.dns_zone_ids["keyvault"]
}

module "container_apps" {
  source = "../../modules/container-apps"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  project                    = var.project
  environment                = local.environment
  subnet_id                  = module.networking.subnet_ids["container-apps"]
  acr_id                     = var.acr_id
  key_vault_id               = module.keyvault.key_vault_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

module "cloudflare" {
  source = "../../modules/cloudflare"

  project               = var.project
  environment           = local.environment
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
}
