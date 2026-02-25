locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes

  dynamic "delegation" {
    for_each = each.value.delegations
    content {
      name = "delegation-${delegation.value}"
      service_delegation {
        name = delegation.value
      }
    }
  }
}

resource "azurerm_network_security_group" "subnets" {
  for_each = var.subnets

  name                = "nsg-${each.key}-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "subnets" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.subnets[each.key].id
}

# Allow Container Apps subnet -> Private Endpoints subnet
resource "azurerm_network_security_rule" "container_apps_to_pe" {
  count = contains(keys(var.subnets), "private-endpoints") && contains(keys(var.subnets), "container-apps") ? 1 : 0

  name                        = "AllowContainerAppsToPE"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.subnets["container-apps"].address_prefixes[0]
  destination_address_prefix  = var.subnets["private-endpoints"].address_prefixes[0]
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["private-endpoints"].name
}

# Allow Cloudflare subnet -> Container Apps subnet
resource "azurerm_network_security_rule" "cloudflare_to_ca" {
  count = contains(keys(var.subnets), "cloudflare") && contains(keys(var.subnets), "container-apps") ? 1 : 0

  name                        = "AllowCloudflareToCApps"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.subnets["cloudflare"].address_prefixes[0]
  destination_address_prefix  = var.subnets["container-apps"].address_prefixes[0]
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["container-apps"].name
}

# Link private DNS zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each = var.dns_zone_names

  name                  = "link-${var.environment}-${each.key}"
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# VNet peering (for DR <-> Prod)
resource "azurerm_virtual_network_peering" "peer" {
  count = var.peer_vnet_id != null ? 1 : 0

  name                         = "peer-to-${var.peer_vnet_name}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.main.name
  remote_virtual_network_id    = var.peer_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
