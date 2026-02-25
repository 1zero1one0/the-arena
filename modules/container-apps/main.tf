locals {
  location_short = {
    centralus = "cus"
    eastus    = "eus"
  }
  naming_suffix       = "${var.project}-${var.environment}-${var.location}-001"
  naming_suffix_short = "${var.project}-${var.environment}-${local.location_short[var.location]}-001"
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

# Storage account kept for future use; admin app uses EmptyDir (Azure Files/SMB incompatible with SQLite locking)
resource "azurerm_storage_account" "main" {
  name                     = "st${var.project}${var.environment}001"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

resource "azurerm_storage_share" "admin" {
  name               = "admin-storage"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 1
}

resource "azurerm_container_app_environment_storage" "admin" {
  name                         = "adminstorage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  share_name                   = azurerm_storage_share.admin.name
  access_mode                  = "ReadWrite"
}

# Admin Container App (the-hideout)
resource "azurerm_container_app" "admin" {
  name                         = "ca-admin-${local.naming_suffix_short}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.container_apps.id
  }

  secret {
    name  = "rails-master-key"
    value = var.rails_master_key
  }

  secret {
    name  = "entra-client-secret"
    value = var.entra_client_secret
  }

  secret {
    name  = "sendlayer-api-key"
    value = var.sendlayer_api_key
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "admin"
      image  = "${var.acr_login_server}/the-hideout:latest"
      cpu    = 0.5
      memory = "1Gi"

      volume_mounts {
        name = "admin-storage"
        path = "/rails/storage"
      }

      env {
        name        = "RAILS_MASTER_KEY"
        secret_name = "rails-master-key"
      }

      env {
        name  = "RAILS_ENV"
        value = "production"
      }

      env {
        name  = "HTTP_PORT"
        value = "8080"
      }

      env {
        name  = "SOLID_QUEUE_IN_PUMA"
        value = "true"
      }

      env {
        name  = "ENTRA_TENANT_ID"
        value = var.entra_tenant_id
      }

      env {
        name  = "ENTRA_TENANT_DOMAIN"
        value = var.entra_tenant_domain
      }

      env {
        name  = "ENTRA_CLIENT_ID"
        value = var.entra_client_id
      }

      env {
        name        = "ENTRA_CLIENT_SECRET"
        secret_name = "entra-client-secret"
      }

      env {
        name        = "SENDLAYER_API_KEY"
        secret_name = "sendlayer-api-key"
      }

      env {
        name  = "SENDLAYER_SENDER_EMAIL"
        value = var.sendlayer_sender_email
      }

      env {
        name  = "SENDLAYER_SENDER_NAME"
        value = var.sendlayer_sender_name
      }
    }

    volume {
      name         = "admin-storage"
      storage_type = "EmptyDir"
    }
  }

  tags = local.tags
}

# Cloudflare Tunnel connector
resource "azurerm_container_app" "cloudflared" {
  name                         = "ca-tunnel-${local.naming_suffix_short}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  secret {
    name  = "tunnel-token"
    value = var.tunnel_token
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "cloudflared"
      image  = "cloudflare/cloudflared:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      args = ["tunnel", "--no-autoupdate", "run"]

      env {
        name        = "TUNNEL_TOKEN"
        secret_name = "tunnel-token"
      }
    }
  }

  tags = local.tags
}
