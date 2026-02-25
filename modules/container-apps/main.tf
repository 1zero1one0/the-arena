locals {
  naming_suffix = "${var.project}-${var.environment}-${var.location}-001"
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_container_app_environment" "main" {
  name                           = "cae-${local.naming_suffix}"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  infrastructure_subnet_id       = var.subnet_id
  internal_load_balancer_enabled = true

  tags = local.tags

  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }
}

# Managed identity for Container Apps to pull from ACR and read Key Vault
resource "azurerm_user_assigned_identity" "container_apps" {
  name                = "id-cae-${local.naming_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
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
