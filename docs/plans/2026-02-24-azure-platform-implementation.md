# Azure Platform Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete Azure platform with Terraform modules, Cloudflare Zero Trust ingress, and CI/CD template applications for The Arena.

**Architecture:** Terraform modules in `modules/`, environment compositions in `environments/`, app scaffolds in `templates/`, helper scripts in `scripts/`. All resources internal-only, public access via Cloudflare Tunnel. DR in East US scaled to zero.

**Tech Stack:** Terraform (AzureRM + Cloudflare providers), GitHub Actions, Docker, .NET 8, Node.js, Ruby on Rails, Bash

**Design doc:** `docs/plans/2026-02-24-azure-platform-design.md`

---

## Task 1: Terraform Root Configuration

**Files:**
- Create: `modules/.gitkeep`
- Create: `environments/shared/main.tf`
- Create: `environments/shared/variables.tf`
- Create: `environments/shared/outputs.tf`
- Create: `environments/shared/providers.tf`
- Create: `environments/shared/backend.tf`
- Create: `environments/prod/main.tf`
- Create: `environments/prod/variables.tf`
- Create: `environments/prod/outputs.tf`
- Create: `environments/prod/providers.tf`
- Create: `environments/prod/backend.tf`
- Create: `environments/staging/main.tf`
- Create: `environments/staging/variables.tf`
- Create: `environments/staging/outputs.tf`
- Create: `environments/staging/providers.tf`
- Create: `environments/staging/backend.tf`
- Create: `environments/dr/main.tf`
- Create: `environments/dr/variables.tf`
- Create: `environments/dr/outputs.tf`
- Create: `environments/dr/providers.tf`
- Create: `environments/dr/backend.tf`
- Create: `.gitignore`

**Step 1: Create .gitignore for Terraform**

```gitignore
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfvars
!*.tfvars.example
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

**Step 2: Create shared environment providers.tf**

This sets up the AzureRM and Cloudflare providers. All environments share the same provider config structure.

```hcl
# environments/shared/providers.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id = var.subscription_id
}
```

**Step 3: Create shared environment backend.tf**

```hcl
# environments/shared/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-arena-tfstate-centralus-001"
    storage_account_name = "starenatfstate001"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
  }
}
```

**Step 4: Create shared environment variables.tf**

```hcl
# environments/shared/variables.tf
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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "shared"
}
```

**Step 5: Create shared environment main.tf**

```hcl
# environments/shared/main.tf
locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-${local.naming_suffix}"
  location = var.location

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
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
```

**Step 6: Create shared environment outputs.tf**

```hcl
# environments/shared/outputs.tf
output "resource_group_name" {
  value = azurerm_resource_group.shared.name
}

output "acr_id" {
  value = module.acr.acr_id
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "dns_zone_ids" {
  value = module.dns_zones.zone_ids
}
```

**Step 7: Create prod environment files**

```hcl
# environments/prod/providers.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id = var.subscription_id
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

```hcl
# environments/prod/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-arena-tfstate-centralus-001"
    storage_account_name = "starenatfstate001"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
  }
}
```

```hcl
# environments/prod/variables.tf
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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
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

variable "shared_resource_group_name" {
  description = "Name of the shared resource group"
  type        = string
  default     = "rg-arena-shared-centralus-001"
}

variable "acr_id" {
  description = "ACR resource ID from shared environment"
  type        = string
}

variable "dns_zone_ids" {
  description = "Map of private DNS zone IDs from shared environment"
  type        = map(string)
}

variable "sql_admin_object_id" {
  description = "Entra ID object ID for SQL admin"
  type        = string
}

variable "sql_admin_login" {
  description = "Entra ID display name for SQL admin"
  type        = string
}
```

```hcl
# environments/prod/main.tf
locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.naming_suffix}"
  location = var.location

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = var.environment
  vnet_address_space  = ["10.0.0.0/16"]

  subnets = {
    container-apps = {
      address_prefixes = ["10.0.0.0/21"]
      delegations      = ["Microsoft.App/environments"]
    }
    function = {
      address_prefixes = ["10.0.9.0/24"]
      delegations      = ["Microsoft.App/environments"]
    }
    private-endpoints = {
      address_prefixes = ["10.0.10.0/24"]
      delegations      = []
    }
    cloudflare = {
      address_prefixes = ["10.0.11.0/24"]
      delegations      = []
    }
  }

  dns_zone_ids = var.dns_zone_ids
}

module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = var.environment
  subnet_id           = module.networking.subnet_ids["private-endpoints"]
  dns_zone_id         = var.dns_zone_ids["keyvault"]
}

module "storage" {
  source = "../../modules/storage"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = var.environment
  subnet_id           = module.networking.subnet_ids["private-endpoints"]
  dns_zone_id         = var.dns_zone_ids["blob"]
}

module "sql_database" {
  source = "../../modules/sql-database"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  project              = var.project
  environment          = var.environment
  subnet_id            = module.networking.subnet_ids["private-endpoints"]
  dns_zone_id          = var.dns_zone_ids["sql"]
  admin_object_id      = var.sql_admin_object_id
  admin_login          = var.sql_admin_login
}

module "signalr" {
  source = "../../modules/signalr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = var.environment
  subnet_id           = module.networking.subnet_ids["private-endpoints"]
  dns_zone_id         = var.dns_zone_ids["signalr"]
}

module "container_apps" {
  source = "../../modules/container-apps"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = var.environment
  subnet_id           = module.networking.subnet_ids["container-apps"]
  acr_id              = var.acr_id
  key_vault_id        = module.keyvault.key_vault_id
  log_analytics_id    = module.monitoring.log_analytics_workspace_id
}

module "function_app" {
  source = "../../modules/function-app"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = var.environment
  subnet_id           = module.networking.subnet_ids["function"]
  pe_subnet_id        = module.networking.subnet_ids["private-endpoints"]
  key_vault_id        = module.keyvault.key_vault_id
  dns_zone_id         = var.dns_zone_ids["blob"]
}

module "cloudflare" {
  source = "../../modules/cloudflare"

  project                    = var.project
  environment                = var.environment
  cloudflare_account_id      = var.cloudflare_account_id
  cloudflare_zone_id         = var.cloudflare_zone_id
  container_apps_env_id      = module.container_apps.environment_id
  container_apps_env_fqdn    = module.container_apps.default_domain
  tunnel_replicas            = 2
}

module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project             = var.project
  environment         = var.environment
  retention_days      = 90
}

# environments/prod/outputs.tf
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "container_apps_environment_id" {
  value = module.container_apps.environment_id
}

output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}
```

**Step 8: Create staging environment files (same structure, different values)**

Staging mirrors prod with `10.2.0.0/16` address space, lower SKUs, 30-day retention. Copy prod structure with staging-specific variable defaults.

**Step 9: Create DR environment files**

DR mirrors prod with `10.1.0.0/16` address space in `eastus`. Only includes: networking, keyvault, container-apps (scaled to 0), cloudflare (standby tunnel), monitoring (log analytics only). Includes VNet peering to prod.

**Step 10: Commit**

```bash
git add .gitignore environments/ modules/.gitkeep
git commit -m "feat: add Terraform root configurations for all environments"
```

---

## Task 2: Networking Module

**Files:**
- Create: `modules/networking/main.tf`
- Create: `modules/networking/variables.tf`
- Create: `modules/networking/outputs.tf`

**Step 1: Create modules/networking/variables.tf**

```hcl
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "subnets" {
  type = map(object({
    address_prefixes = list(string)
    delegations      = list(string)
  }))
}

variable "dns_zone_ids" {
  description = "Map of private DNS zone IDs to link to this VNet"
  type        = map(string)
  default     = {}
}

variable "peer_vnet_id" {
  description = "VNet ID to peer with (for DR)"
  type        = string
  default     = null
}

variable "peer_vnet_name" {
  description = "Name of the peer VNet"
  type        = string
  default     = null
}
```

**Step 2: Create modules/networking/main.tf**

```hcl
locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name                = "snet-${each.key}"
  resource_group_name = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes    = each.value.address_prefixes

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

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnets" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.subnets[each.key].id
}

# NSG Rules - Default deny inbound is implicit in Azure NSGs
# Allow Container Apps <-> Private Endpoints
resource "azurerm_network_security_rule" "container_apps_to_pe" {
  count = contains(keys(var.subnets), "private-endpoints") ? 1 : 0

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

# Allow Function subnet -> Private Endpoints
resource "azurerm_network_security_rule" "function_to_pe" {
  count = contains(keys(var.subnets), "function") && contains(keys(var.subnets), "private-endpoints") ? 1 : 0

  name                        = "AllowFunctionToPE"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.subnets["function"].address_prefixes[0]
  destination_address_prefix  = var.subnets["private-endpoints"].address_prefixes[0]
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["private-endpoints"].name
}

# Link private DNS zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each = var.dns_zone_ids

  name                  = "link-${var.environment}-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.key
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# VNet peering (for DR <-> Prod)
resource "azurerm_virtual_network_peering" "peer" {
  count = var.peer_vnet_id != null ? 1 : 0

  name                      = "peer-to-${var.peer_vnet_name}"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.main.name
  remote_virtual_network_id = var.peer_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
```

**Step 3: Create modules/networking/outputs.tf**

```hcl
output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  value = { for k, v in azurerm_subnet.subnets : k => v.id }
}
```

**Step 4: Run terraform validate**

```bash
cd environments/shared && terraform init -backend=false && terraform validate
```

Expected: Success

**Step 5: Commit**

```bash
git add modules/networking/
git commit -m "feat: add networking module with VNet, subnets, NSGs, DNS links, peering"
```

---

## Task 3: Private DNS Zones Module

**Files:**
- Create: `modules/dns-zones/main.tf`
- Create: `modules/dns-zones/variables.tf`
- Create: `modules/dns-zones/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/dns-zones/variables.tf
variable "resource_group_name" {
  type = string
}

# modules/dns-zones/main.tf
locals {
  dns_zones = {
    sql     = "privatelink.database.windows.net"
    acr     = "privatelink.azurecr.io"
    keyvault = "privatelink.vaultcore.azure.net"
    blob    = "privatelink.blob.core.windows.net"
    signalr = "privatelink.signalr.net"
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

# modules/dns-zones/outputs.tf
output "zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
}

output "zone_names" {
  value = { for k, v in azurerm_private_dns_zone.zones : k => v.name }
}
```

**Step 2: Commit**

```bash
git add modules/dns-zones/
git commit -m "feat: add private DNS zones module for Azure private endpoints"
```

---

## Task 4: Key Vault Module

**Files:**
- Create: `modules/keyvault/main.tf`
- Create: `modules/keyvault/variables.tf`
- Create: `modules/keyvault/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/keyvault/variables.tf
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
}
variable "dns_zone_id" {
  description = "Private DNS zone ID for Key Vault"
  type        = string
}

# modules/keyvault/main.tf
locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "kv-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization   = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-kv-${local.naming_suffix}"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.dns_zone_id]
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Grant the deploying principal admin access
resource "azurerm_role_assignment" "deployer_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# modules/keyvault/outputs.tf
output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}
```

**Step 2: Commit**

```bash
git add modules/keyvault/
git commit -m "feat: add Key Vault module with RBAC, private endpoint, purge protection"
```

---

## Task 5: ACR Module

**Files:**
- Create: `modules/acr/main.tf`
- Create: `modules/acr/variables.tf`
- Create: `modules/acr/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/acr/variables.tf
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project" { type = string }

# modules/acr/main.tf
locals {
  # ACR names must be alphanumeric only
  acr_name = "cr${var.project}${var.location}001"
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

# modules/acr/outputs.tf
output "acr_id" {
  value = azurerm_container_registry.main.id
}

output "login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}
```

**Step 2: Commit**

```bash
git add modules/acr/
git commit -m "feat: add ACR module with Standard tier, admin disabled"
```

---

## Task 6: Storage Module

**Files:**
- Create: `modules/storage/main.tf`
- Create: `modules/storage/variables.tf`
- Create: `modules/storage/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/storage/variables.tf
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
}
variable "dns_zone_id" {
  description = "Private DNS zone ID for blob"
  type        = string
}

# modules/storage/main.tf
locals {
  # Storage names: alphanumeric, 3-24 chars
  location_short = {
    centralus = "cus"
    eastus    = "eus"
  }
  storage_name = "st${var.project}${var.environment}${local.location_short[var.location]}001"
}

resource "azurerm_storage_account" "main" {
  name                     = local.storage_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled = false
  min_tls_version               = "TLS1_2"

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-st-blob-${var.project}-${var.environment}-${var.location}-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-st-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.dns_zone_id]
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# modules/storage/outputs.tf
output "storage_account_id" {
  value = azurerm_storage_account.main.id
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}
```

**Step 2: Commit**

```bash
git add modules/storage/
git commit -m "feat: add storage module with private endpoint, no public access"
```

---

## Task 7: SQL Database Module

**Files:**
- Create: `modules/sql-database/main.tf`
- Create: `modules/sql-database/variables.tf`
- Create: `modules/sql-database/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/sql-database/variables.tf
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "subnet_id" { type = string }
variable "dns_zone_id" { type = string }
variable "admin_object_id" {
  description = "Entra ID object ID for the SQL admin"
  type        = string
}
variable "admin_login" {
  description = "Entra ID display name for the SQL admin"
  type        = string
}
variable "min_vcores" {
  type    = number
  default = 0.5
}
variable "max_vcores" {
  type    = number
  default = 2
}
variable "auto_pause_delay" {
  description = "Minutes of idle before auto-pause (-1 to disable)"
  type        = number
  default     = 60
}

# modules/sql-database/main.tf
locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
}

resource "azurerm_mssql_server" "main" {
  name                         = "sql-${local.naming_suffix}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  public_network_access_enabled = false

  azuread_administrator {
    login_username = var.admin_login
    object_id      = var.admin_object_id
    azuread_authentication_only = true
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_mssql_database" "main" {
  name      = "sqldb-${local.naming_suffix}"
  server_id = azurerm_mssql_server.main.id

  sku_name                    = "GP_S_Gen5_2"
  min_capacity                = var.min_vcores
  auto_pause_delay_in_minutes = var.auto_pause_delay
  max_size_gb                 = 32
  zone_redundant              = false

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-sql-${local.naming_suffix}"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.dns_zone_id]
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# modules/sql-database/outputs.tf
output "server_id" {
  value = azurerm_mssql_server.main.id
}

output "server_fqdn" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "database_id" {
  value = azurerm_mssql_database.main.id
}

output "database_name" {
  value = azurerm_mssql_database.main.name
}
```

**Step 2: Commit**

```bash
git add modules/sql-database/
git commit -m "feat: add SQL Database module with serverless tier, Entra ID auth, private endpoint"
```

---

## Task 8: SignalR Module

**Files:**
- Create: `modules/signalr/main.tf`
- Create: `modules/signalr/variables.tf`
- Create: `modules/signalr/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/signalr/variables.tf
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "subnet_id" { type = string }
variable "dns_zone_id" { type = string }

# modules/signalr/main.tf
locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
}

resource "azurerm_signalr_service" "main" {
  name                = "sigr-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = "Free_F1"
    capacity = 1
  }

  service_mode              = "Serverless"
  public_network_access_enabled = false

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_private_endpoint" "signalr" {
  name                = "pe-sigr-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-sigr-${local.naming_suffix}"
    private_connection_resource_id = azurerm_signalr_service.main.id
    subresource_names              = ["signalr"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.dns_zone_id]
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# modules/signalr/outputs.tf
output "signalr_id" {
  value = azurerm_signalr_service.main.id
}

output "signalr_hostname" {
  value = azurerm_signalr_service.main.hostname
}
```

**Step 2: Commit**

```bash
git add modules/signalr/
git commit -m "feat: add SignalR module with serverless mode, private endpoint"
```

---

## Task 9: Container Apps Module

**Files:**
- Create: `modules/container-apps/main.tf`
- Create: `modules/container-apps/variables.tf`
- Create: `modules/container-apps/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/container-apps/variables.tf
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "subnet_id" {
  description = "Container Apps subnet ID (/21 minimum)"
  type        = string
}
variable "acr_id" { type = string }
variable "key_vault_id" { type = string }
variable "log_analytics_id" { type = string }

# modules/container-apps/main.tf
locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.naming_suffix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_id

  infrastructure_subnet_id       = var.subnet_id
  internal_load_balancer_enabled = true

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Managed identity for Container Apps to pull from ACR and read Key Vault
resource "azurerm_user_assigned_identity" "container_apps" {
  name                = "id-cae-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_apps.principal_id
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.container_apps.principal_id
}

# modules/container-apps/outputs.tf
output "environment_id" {
  value = azurerm_container_app_environment.main.id
}

output "default_domain" {
  value = azurerm_container_app_environment.main.default_domain
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.container_apps.id
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.container_apps.client_id
}
```

**Step 2: Commit**

```bash
git add modules/container-apps/
git commit -m "feat: add Container Apps module with internal-only environment, managed identity"
```

---

## Task 10: Function App Module

**Files:**
- Create: `modules/function-app/main.tf`
- Create: `modules/function-app/variables.tf`
- Create: `modules/function-app/outputs.tf`

**Step 1: Create the module**

This creates the Flex Consumption hosting plan and a dedicated storage account. Individual function apps are created per-application via templates.

```hcl
# modules/function-app/variables.tf
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "subnet_id" {
  description = "Function App delegation subnet ID"
  type        = string
}
variable "pe_subnet_id" {
  description = "Private endpoint subnet ID"
  type        = string
}
variable "key_vault_id" { type = string }
variable "dns_zone_id" {
  description = "Blob private DNS zone ID"
  type        = string
}

# modules/function-app/main.tf
locals {
  naming_suffix  = "${var.project}-${var.environment}-${var.location}-001"
  location_short = {
    centralus = "cus"
    eastus    = "eus"
  }
}

# Flex Consumption plan
resource "azurerm_service_plan" "functions" {
  name                = "asp-func-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "FC1"

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Shared identity for function apps
resource "azurerm_user_assigned_identity" "functions" {
  name                = "id-func-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_role_assignment" "func_kv_secrets" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.functions.principal_id
}

# modules/function-app/outputs.tf
output "service_plan_id" {
  value = azurerm_service_plan.functions.id
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.functions.id
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.functions.client_id
}
```

**Step 2: Commit**

```bash
git add modules/function-app/
git commit -m "feat: add Function App module with Flex Consumption plan, managed identity"
```

---

## Task 11: Monitoring Module

**Files:**
- Create: `modules/monitoring/main.tf`
- Create: `modules/monitoring/variables.tf`
- Create: `modules/monitoring/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/monitoring/variables.tf
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "retention_days" {
  type    = number
  default = 30
}

# modules/monitoring/main.tf
locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Budget alert
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "budget-${local.naming_suffix}"
  resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  amount     = 500
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    contact_emails = []
    threshold_type = "Actual"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = []
    threshold_type = "Actual"
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_emails = []
    threshold_type = "Actual"
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}

data "azurerm_client_config" "current" {}

# modules/monitoring/outputs.tf
output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "app_insights_id" {
  value = azurerm_application_insights.main.id
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}
```

**Step 2: Commit**

```bash
git add modules/monitoring/
git commit -m "feat: add monitoring module with Log Analytics, App Insights, budget alerts"
```

---

## Task 12: Cloudflare Module

**Files:**
- Create: `modules/cloudflare/main.tf`
- Create: `modules/cloudflare/variables.tf`
- Create: `modules/cloudflare/outputs.tf`

**Step 1: Create the module**

```hcl
# modules/cloudflare/variables.tf
variable "project" { type = string }
variable "environment" { type = string }
variable "cloudflare_account_id" { type = string }
variable "cloudflare_zone_id" { type = string }
variable "container_apps_env_id" { type = string }
variable "container_apps_env_fqdn" { type = string }
variable "tunnel_replicas" {
  type    = number
  default = 2
}

# modules/cloudflare/main.tf

# Create the tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "${var.project}-${var.environment}-tunnel"
  secret     = random_password.tunnel_secret.result
}

resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

# Zero Trust Access - Entra ID IdP config is manual in Cloudflare dashboard
# Access applications are created per-app via the template terraform

# modules/cloudflare/outputs.tf
output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

output "tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.main.tunnel_token
  sensitive = true
}

output "tunnel_cname" {
  value = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
}
```

**Step 2: Commit**

```bash
git add modules/cloudflare/
git commit -m "feat: add Cloudflare module with tunnel and Zero Trust foundation"
```

---

## Task 13: Staging and DR Environment Compositions

**Files:**
- Modify: `environments/staging/main.tf` (populate from template)
- Modify: `environments/staging/variables.tf`
- Modify: `environments/staging/providers.tf`
- Modify: `environments/staging/backend.tf`
- Modify: `environments/staging/outputs.tf`
- Modify: `environments/dr/main.tf`
- Modify: `environments/dr/variables.tf`
- Modify: `environments/dr/providers.tf`
- Modify: `environments/dr/backend.tf`
- Modify: `environments/dr/outputs.tf`

**Step 1: Create staging environment**

Same as prod but:
- VNet: `10.2.0.0/16`, subnets `10.2.x.x`
- Backend key: `staging.tfstate`
- `retention_days = 30`
- `tunnel_replicas = 1`
- SQL: `max_vcores = 1`
- No budget alerts

**Step 2: Create DR environment**

- VNet: `10.1.0.0/16`, subnets `10.1.x.x`, location `eastus`
- Backend key: `dr.tfstate`
- Includes: networking (with peering to prod), keyvault, container-apps, cloudflare (standby), monitoring (log analytics only)
- Does NOT include: sql-database (uses geo-replica from prod module), signalr, function-app, storage
- Container Apps environment exists but no apps deployed initially

**Step 3: Commit**

```bash
git add environments/staging/ environments/dr/
git commit -m "feat: add staging and DR environment compositions"
```

---

## Task 14: Terraform State Bootstrap Script

**Files:**
- Create: `scripts/bootstrap-tfstate.sh`

**Step 1: Create bootstrap script**

This script creates the storage account for Terraform remote state (must run before any `terraform init`).

```bash
#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Terraform remote state storage
# Run this ONCE before any terraform init

RESOURCE_GROUP="rg-arena-tfstate-centralus-001"
STORAGE_ACCOUNT="starenatfstate001"
CONTAINER="tfstate"
LOCATION="centralus"

echo "Creating resource group for Terraform state..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

echo "Creating storage account for Terraform state..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

echo "Creating blob container..."
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT"

echo "Terraform state backend ready."
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Container: $CONTAINER"
```

**Step 2: Commit**

```bash
chmod +x scripts/bootstrap-tfstate.sh
git add scripts/bootstrap-tfstate.sh
git commit -m "feat: add Terraform state bootstrap script"
```

---

## Task 15: .NET API Template

**Files:**
- Create: `templates/dotnet-api/Dockerfile`
- Create: `templates/dotnet-api/src/Program.cs`
- Create: `templates/dotnet-api/src/TemplateApi.csproj`
- Create: `templates/dotnet-api/.github/workflows/deploy.yml`
- Create: `templates/dotnet-api/terraform/main.tf`
- Create: `templates/dotnet-api/terraform/variables.tf`
- Create: `templates/dotnet-api/README.md`

**Step 1: Create Dockerfile**

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY src/ .
RUN dotnet restore
RUN dotnet publish -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "TemplateApi.dll"]
```

**Step 2: Create minimal .NET API with health endpoint**

```csharp
// src/Program.cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHealthChecks();

var app = builder.Build();
app.MapHealthChecks("/health");
app.MapGet("/", () => "OK");
app.Run();
```

```xml
<!-- src/TemplateApi.csproj -->
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Azure.Identity" Version="1.11.*" />
    <PackageReference Include="Azure.Extensions.AspNetCore.Configuration.Secrets" Version="1.3.*" />
  </ItemGroup>
</Project>
```

**Step 3: Create GitHub Actions workflow**

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write
  contents: read

env:
  ACR_NAME: crarenacentralus001
  APP_NAME: ${{ github.event.repository.name }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Build and push to ACR
        run: |
          az acr login --name $ACR_NAME
          docker build -t $ACR_NAME.azurecr.io/$APP_NAME:${{ github.sha }} .
          docker push $ACR_NAME.azurecr.io/$APP_NAME:${{ github.sha }}

  deploy-staging:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to staging
        run: |
          az containerapp update \
            --name $APP_NAME \
            --resource-group rg-arena-stg-centralus-001 \
            --image $ACR_NAME.azurecr.io/$APP_NAME:${{ github.sha }}

  deploy-production:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to production
        run: |
          az containerapp update \
            --name $APP_NAME \
            --resource-group rg-arena-prod-centralus-001 \
            --image $ACR_NAME.azurecr.io/$APP_NAME:${{ github.sha }}
```

**Step 4: Create app-level Terraform**

```hcl
# templates/dotnet-api/terraform/variables.tf
variable "app_name" { type = string }
variable "environment" { type = string }
variable "container_apps_environment_id" { type = string }
variable "managed_identity_id" { type = string }
variable "acr_login_server" { type = string }
variable "image_tag" {
  type    = string
  default = "latest"
}

# templates/dotnet-api/terraform/main.tf
resource "azurerm_container_app" "app" {
  name                         = var.app_name
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.managed_identity_id
  }

  template {
    min_replicas = 0
    max_replicas = 5

    container {
      name   = var.app_name
      image  = "${var.acr_login_server}/${var.app_name}:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = {
    app         = var.app_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

data "azurerm_resource_group" "main" {
  name = "rg-arena-${var.environment}-centralus-001"
}
```

**Step 5: Create README.md**

Brief setup instructions: how to configure OIDC, set GitHub secrets, first deploy.

**Step 6: Commit**

```bash
git add templates/dotnet-api/
git commit -m "feat: add .NET API template with Dockerfile, GH Actions, Terraform"
```

---

## Task 16: Node.js API Template

**Files:**
- Create: `templates/node-api/Dockerfile`
- Create: `templates/node-api/src/index.js`
- Create: `templates/node-api/src/package.json`
- Create: `templates/node-api/.github/workflows/deploy.yml`
- Create: `templates/node-api/terraform/main.tf`
- Create: `templates/node-api/terraform/variables.tf`
- Create: `templates/node-api/README.md`

**Step 1: Create Dockerfile**

```dockerfile
FROM node:20-slim AS build
WORKDIR /app
COPY src/package*.json ./
RUN npm ci --production
COPY src/ .

FROM node:20-slim
WORKDIR /app
COPY --from=build /app .
EXPOSE 8080
ENV PORT=8080
CMD ["node", "index.js"]
```

**Step 2: Create minimal Express app with health endpoint**

```javascript
// src/index.js
const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.get('/health', (req, res) => res.json({ status: 'healthy' }));
app.get('/', (req, res) => res.send('OK'));

app.listen(port, () => console.log(`Listening on port ${port}`));
```

```json
{
  "name": "template-node-api",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": { "express": "^4.18.0" }
}
```

**Step 3: GH Actions workflow** - Same structure as dotnet-api template

**Step 4: Terraform** - Same structure as dotnet-api template

**Step 5: Commit**

```bash
git add templates/node-api/
git commit -m "feat: add Node.js API template with Dockerfile, GH Actions, Terraform"
```

---

## Task 17: Rails App Template

**Files:**
- Create: `templates/rails-app/Dockerfile`
- Create: `templates/rails-app/.github/workflows/deploy.yml`
- Create: `templates/rails-app/terraform/main.tf`
- Create: `templates/rails-app/terraform/variables.tf`
- Create: `templates/rails-app/README.md`

**Step 1: Create Dockerfile**

```dockerfile
FROM ruby:3.3-slim AS build
RUN apt-get update && apt-get install -y build-essential libpq-dev nodejs npm
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && bundle install
COPY . .
RUN SECRET_KEY_BASE=placeholder bundle exec rails assets:precompile 2>/dev/null || true

FROM ruby:3.3-slim
RUN apt-get update && apt-get install -y libpq-dev nodejs && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app .
COPY --from=build /usr/local/bundle /usr/local/bundle
EXPOSE 8080
ENV RAILS_ENV=production PORT=8080
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "8080"]
```

**Step 2: Create GH Actions workflow and Terraform** - Same pattern as other templates

**Step 3: Create README** - Rails-specific setup (Gemfile, database config, asset pipeline)

**Step 4: Commit**

```bash
git add templates/rails-app/
git commit -m "feat: add Rails app template with Dockerfile, GH Actions, Terraform"
```

---

## Task 18: Function App Templates (dotnet + node)

**Files:**
- Create: `templates/function-dotnet/src/host.json`
- Create: `templates/function-dotnet/src/Program.cs`
- Create: `templates/function-dotnet/src/HealthCheck.cs`
- Create: `templates/function-dotnet/src/FunctionTemplate.csproj`
- Create: `templates/function-dotnet/.github/workflows/deploy.yml`
- Create: `templates/function-dotnet/terraform/main.tf`
- Create: `templates/function-dotnet/terraform/variables.tf`
- Create: `templates/function-dotnet/README.md`
- Create: `templates/function-node/src/host.json`
- Create: `templates/function-node/src/package.json`
- Create: `templates/function-node/src/functions/health.js`
- Create: `templates/function-node/.github/workflows/deploy.yml`
- Create: `templates/function-node/terraform/main.tf`
- Create: `templates/function-node/terraform/variables.tf`
- Create: `templates/function-node/README.md`

**Step 1: Create .NET Function template**

```csharp
// src/Program.cs
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services => {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
    })
    .Build();

host.Run();
```

```csharp
// src/HealthCheck.cs
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace FunctionTemplate;

public class HealthCheck
{
    [Function("Health")]
    public HttpResponseData Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequestData req)
    {
        var response = req.CreateResponse(System.Net.HttpStatusCode.OK);
        response.WriteString("healthy");
        return response;
    }
}
```

**Step 2: Create Node.js Function template**

```javascript
// src/functions/health.js
const { app } = require('@azure/functions');

app.http('health', {
    methods: ['GET'],
    route: 'health',
    handler: async (request, context) => {
        return { body: JSON.stringify({ status: 'healthy' }) };
    }
});
```

**Step 3: GH Actions workflows** - Use `az functionapp deployment` instead of container deploy

**Step 4: Terraform** - Creates the function app resource, storage account, connects to Flex Consumption plan

**Step 5: Commit**

```bash
git add templates/function-dotnet/ templates/function-node/
git commit -m "feat: add Function App templates for .NET and Node.js"
```

---

## Task 19: Scaffold Script (new-app.sh)

**Files:**
- Create: `scripts/new-app.sh`

**Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/new-app.sh --name myapp --template dotnet-api --org myorg
#
# Creates a new GitHub repo from a template, configures OIDC identity,
# and sets up CI/CD for the Arena platform.

usage() {
  echo "Usage: $0 --name <app-name> --template <template> --org <github-org>"
  echo ""
  echo "Templates: dotnet-api, node-api, rails-app, function-dotnet, function-node"
  echo ""
  echo "Options:"
  echo "  --name       Application name (used for repo, container app, DNS)"
  echo "  --template   Template to use from templates/"
  echo "  --org        GitHub organization"
  echo "  --domain     Custom domain (optional, for Cloudflare DNS)"
  exit 1
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --name) APP_NAME="$2"; shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    --org) GH_ORG="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    *) usage ;;
  esac
done

: "${APP_NAME:?--name is required}"
: "${TEMPLATE:?--template is required}"
: "${GH_ORG:?--org is required}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$REPO_ROOT/templates/$TEMPLATE"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Error: Template '$TEMPLATE' not found at $TEMPLATE_DIR"
  exit 1
fi

REPO_NAME="arena-${APP_NAME}"

echo "=== Creating new app: $APP_NAME ==="
echo "  Template: $TEMPLATE"
echo "  Repo: $GH_ORG/$REPO_NAME"
echo ""

# Step 1: Create GitHub repo
echo "1. Creating GitHub repository..."
gh repo create "$GH_ORG/$REPO_NAME" --private --clone
cd "$REPO_NAME"

# Step 2: Copy template
echo "2. Copying template files..."
cp -r "$TEMPLATE_DIR"/. .
find . -type f -exec sed -i '' "s/template-name/$APP_NAME/g" {} + 2>/dev/null || \
find . -type f -exec sed -i "s/template-name/$APP_NAME/g" {} +

# Step 3: Initial commit
echo "3. Creating initial commit..."
git add -A
git commit -m "feat: initialize $APP_NAME from $TEMPLATE template"
git push -u origin main

# Step 4: Configure GitHub environments
echo "4. Setting up GitHub environments..."
gh api repos/"$GH_ORG"/"$REPO_NAME"/environments/staging -X PUT
gh api repos/"$GH_ORG"/"$REPO_NAME"/environments/production -X PUT \
  --input - <<EOF
{
  "reviewers": [{"type": "User", "id": $(gh api user --jq '.id')}],
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}
EOF

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Configure OIDC federated credentials in Azure for repo: $GH_ORG/$REPO_NAME"
echo "  2. Set GitHub secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"
echo "  3. Run: cd $REPO_NAME/terraform && terraform apply"
echo "  4. Push code to trigger first deployment"
```

**Step 2: Commit**

```bash
chmod +x scripts/new-app.sh
git add scripts/new-app.sh
git commit -m "feat: add scaffold script for creating new apps from templates"
```

---

## Task 20: DR Failover Script

**Files:**
- Create: `scripts/failover.sh`

**Step 1: Create the failover script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/failover.sh --action activate|deactivate
#
# Activates or deactivates DR environment in East US

usage() {
  echo "Usage: $0 --action <activate|deactivate>"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --action) ACTION="$2"; shift 2 ;;
    *) usage ;;
  esac
done

: "${ACTION:?--action is required}"

DR_RG="rg-arena-prod-eastus-001"

case $ACTION in
  activate)
    echo "=== Activating DR environment ==="
    echo "1. Scaling up Container Apps..."
    for app in $(az containerapp list -g "$DR_RG" --query '[].name' -o tsv); do
      echo "   Scaling $app to min=1..."
      az containerapp update -n "$app" -g "$DR_RG" --min-replicas 1
    done

    echo "2. Promoting SQL geo-replica..."
    # SQL failover group handles this automatically if configured
    echo "   Check Azure Portal for SQL failover group status"

    echo ""
    echo "=== DR activated ==="
    echo "Remember to update Cloudflare tunnel routes to point to DR environment"
    ;;

  deactivate)
    echo "=== Deactivating DR environment ==="
    echo "1. Scaling down Container Apps..."
    for app in $(az containerapp list -g "$DR_RG" --query '[].name' -o tsv); do
      echo "   Scaling $app to min=0, max=0..."
      az containerapp update -n "$app" -g "$DR_RG" --min-replicas 0 --max-replicas 0
    done

    echo ""
    echo "=== DR deactivated ==="
    ;;

  *)
    usage
    ;;
esac
```

**Step 2: Commit**

```bash
chmod +x scripts/failover.sh
git add scripts/failover.sh
git commit -m "feat: add DR failover script for activate/deactivate"
```

---

## Task 21: Terraform Validation

**Step 1: Run `terraform fmt -check -recursive` on all modules and environments**

```bash
terraform fmt -recursive modules/ environments/
```

**Step 2: Run `terraform validate` on each environment (with `-backend=false`)**

```bash
for env in shared prod staging dr; do
  echo "Validating $env..."
  cd environments/$env
  terraform init -backend=false
  terraform validate
  cd ../..
done
```

Expected: All pass

**Step 3: Fix any issues found**

**Step 4: Commit if formatting changes were made**

```bash
git add -A
git commit -m "style: format Terraform files"
```

---

## Task 22: Final Commit and Summary

**Step 1: Verify full repo structure**

```bash
find . -type f | grep -v .git | sort
```

Verify all expected files exist per the design doc.

**Step 2: Create a tfvars.example for each environment**

```hcl
# environments/prod/terraform.tfvars.example
subscription_id        = ""
cloudflare_api_token   = ""
cloudflare_account_id  = ""
cloudflare_zone_id     = ""
acr_id                 = ""
sql_admin_object_id    = ""
sql_admin_login        = ""
dns_zone_ids = {
  sql     = ""
  acr     = ""
  keyvault = ""
  blob    = ""
  signalr = ""
}
```

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add tfvars examples for all environments"
```
