# Azure Platform Design - The Arena

**Date:** 2026-02-24
**Status:** Approved

## Overview

Best-practice Azure platform for "The Arena" with all resources internal, public access via Cloudflare Tunnel, Zero Trust employee access via Entra ID, and DR in a secondary region scaled to zero.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary region | Central US | User requirement |
| DR region | East US | Geographic separation |
| Naming | CAF convention (`type-arena-env-region-001`) | Azure best practice |
| VNet CIDR | Primary `10.0.0.0/16`, DR `10.1.0.0/16`, Staging `10.2.0.0/16` | Non-overlapping, room to grow |
| Environment separation | Separate resource groups per env | Isolation, RBAC, billing clarity |
| VMs | Removed | Arelle containerized, scale-to-zero |
| App Service | Removed | Rails admin app runs on Container Apps |
| All compute | Container Apps | Consistent deployment model |
| SQL tier | Serverless General Purpose, auto-pause | Cost efficient for variable load |
| MongoDB Atlas | Private endpoint (M10+) | Secure, no public internet |
| ACR tier | Standard | Sufficient, no geo-replication needed |
| SignalR | Serverless mode | Scale-to-zero pattern |
| Function Apps | Flex Consumption | VNet integration required |
| CI/CD auth | GitHub OIDC federated credentials | No stored secrets |
| Deploy flow | PR → main → staging → manual approve → prod | Review gates |
| Cloudflare Zero Trust | Free tier, <50 users, Entra ID | Fits requirements |
| IaC | Terraform modules, flat structure | Simple, maintainable |

## 1. Network Architecture

### Primary VNet (`vnet-arena-prod-centralus-001` - `10.0.0.0/16`)

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-container-apps` | `10.0.0.0/21` | Container Apps Environment (requires /21 minimum) |
| `snet-function` | `10.0.9.0/24` | Function App Flex Consumption |
| `snet-private-endpoints` | `10.0.10.0/24` | Private endpoints for SQL, ACR, KV, SignalR, Storage |
| `snet-cloudflare` | `10.0.11.0/24` | Cloudflare Tunnel connector (Container App) |

### Staging VNet (`vnet-arena-stg-centralus-001` - `10.2.0.0/16`)

Same subnet layout, `10.2.x.x` address space. No peering to prod.

### DR VNet (`vnet-arena-prod-eastus-001` - `10.1.0.0/16`)

Same layout as prod. Peered to primary VNet for failover scenarios.

### Private DNS Zones (in shared resource group)

- `privatelink.database.windows.net` (SQL)
- `privatelink.azurecr.io` (ACR)
- `privatelink.vaultcore.azure.net` (Key Vault)
- `privatelink.blob.core.windows.net` (Storage)
- `privatelink.signalr.net` (SignalR)

### NSGs

- Default deny inbound on all subnets
- Allow outbound to Azure services via service tags
- Allow Container Apps subnet <-> private endpoints subnet
- Allow Cloudflare subnet -> Container Apps subnets
- No public IPs anywhere

## 2. Cloudflare & Zero Trust

### Tunnel

- `cloudflared` runs as a Container App in `snet-cloudflare`
- 2 replicas in prod, 1 in staging
- Outbound-only connection, no inbound ports or public IPs
- Routes Cloudflare domains to internal service addresses

### DNS Routing

- Per-app CNAME records in Cloudflare, managed via Terraform Cloudflare provider
- e.g., `app.yourdomain.com` -> Tunnel -> internal Container App

### Zero Trust Access

- IdP: Entra ID (Azure AD)
- Access Application per internal service
- Employee group: production app access via Entra ID group
- Developer group: staging + production access, plus `cloudflared access` for VNet resources
- Service tokens for CI/CD health checks

### Developer VNet Access

- `cloudflared access` for ad-hoc tunneling (SQL, Key Vault, etc.)
- No VPN needed

## 3. Compute & Application Services

### Container Apps Environment

- One environment per resource group (prod, staging, DR)
- Internal-only mode (no public endpoint)
- Deployed into `snet-container-apps` (/21)
- Workload profiles: Consumption (serverless, scale-to-zero)
- DR: all apps scaled to `maxReplicas: 0`

### Container Apps (workloads)

- Arelle (containerized, scale-to-zero)
- Rails admin app
- Any new containerized services
- `cloudflared` tunnel connector
- Pull from ACR via private endpoint
- Managed identity for ACR pull + Key Vault access
- Revision-based deployments

### Function Apps

- Flex Consumption plan (VNet integrated via `snet-function`)
- .NET and Node.js runtimes
- Private endpoint for inbound
- Managed identity for Key Vault + Storage + SQL access
- Dedicated storage account per function app (Azure requirement), private endpoints

### SignalR Service

- Serverless mode
- Private endpoint in `snet-private-endpoints`
- No public access

## 4. Data & Storage

### Azure SQL Database

- Server: `sql-arena-prod-centralus-001`
- Serverless General Purpose, auto-pause after 1 hour
- Min 0.5 vCores, max 2 vCores
- Private endpoint, no public access
- Entra ID admin + managed identity auth (no SQL passwords)
- DR: geo-replicated read replica in East US (auto-failover group)

### MongoDB Atlas

- M10+ tier for private endpoint support
- Private endpoint peered to prod VNet
- Connection string in Key Vault

### Storage Accounts

- `starenaproducentralus001` (prod general purpose)
- `starenastgcentralus001` (staging)
- Private endpoints for blob/table/queue
- No public access
- Separate storage accounts per Function App

### Key Vault

- `kv-arena-prod-centralus-001` (per environment)
- RBAC authorization model
- Private endpoint
- Stores: MongoDB connection strings, external API keys, SQL connection strings
- Managed identities get `Key Vault Secrets User` role
- GitHub Actions identity gets `Key Vault Secrets Officer`
- Soft delete + purge protection enabled

### Container Registry

- `crarenacentralus001` (shared across environments)
- Standard tier
- Private endpoint
- Admin user disabled, managed identity pull
- Repos per app: `crarenacentralus001.azurecr.io/{app-name}`

## 5. CI/CD & Templates

### Flow

```
Developer pushes PR -> GitHub Actions builds + tests
  -> PR merged to main -> Deploy to staging (new revision)
  -> Manual approval (GitHub Environment protection rule)
  -> Promote to production (new revision, traffic shift)
```

### GitHub <-> Azure Auth

- OIDC federated credentials (no stored secrets)
- Managed identity per environment
- Roles: `AcrPush` on ACR, `Key Vault Secrets User`, `Contributor` on Container Apps

### Template Applications (`/templates/`)

| Template | Stack | Includes |
|----------|-------|----------|
| `dotnet-api` | .NET 8 Web API | Dockerfile, GH Actions, health endpoint, KV integration |
| `node-api` | Node.js/Express | Dockerfile, GH Actions, health endpoint, KV integration |
| `rails-app` | Ruby on Rails | Dockerfile, GH Actions, health endpoint, KV integration |
| `function-dotnet` | .NET 8 Isolated Function | GH Actions, KV binding, Flex Consumption config |
| `function-node` | Node.js Function | GH Actions, KV binding, Flex Consumption config |

Each template contains:
- `Dockerfile` (except raw Functions)
- `.github/workflows/deploy.yml`
- `terraform/` - app-specific resources (Container App definition, KV secrets, Cloudflare route)
- `README.md`

### Scaffold Script

```bash
./scripts/new-app.sh --name arelle --template dotnet-api --env prod
```

- Creates new GitHub repo from template
- Configures OIDC federated identity
- Creates Container App shell in Terraform
- Adds Cloudflare DNS route
- Sets up GitHub Environment protection rules

### DR Failover

- Same images from shared ACR
- DR Container Apps exist at `maxReplicas: 0`
- Failover script: sets `minReplicas: 1`, updates Cloudflare tunnel routes

## 6. Monitoring & Observability

### Log Analytics

- `log-arena-prod-centralus-001` (prod, 90-day retention)
- `log-arena-stg-centralus-001` (staging, 30-day retention)
- All resources send diagnostics here

### Application Insights

- One instance per environment, backed by Log Analytics
- Auto-instrumented for .NET and Node.js
- Connection string in Key Vault

### Alerts

- Container App replica failures / restarts
- SQL Database DTU > 80%
- Function App execution failures
- Key Vault access denied events
- Cloudflare tunnel health check
- Budget alerts at 50%, 80%, 100%

## 7. Resource Groups & Deployment Order

### Resource Groups

| Resource Group | Region | Purpose |
|---|---|---|
| `rg-arena-prod-centralus-001` | Central US | Production |
| `rg-arena-stg-centralus-001` | Central US | Staging |
| `rg-arena-prod-eastus-001` | East US | DR (scaled to 0) |
| `rg-arena-shared-centralus-001` | Central US | ACR, Private DNS Zones |

### Terraform Modules

| Module | Prod | Staging | DR | Shared |
|---|---|---|---|---|
| `networking` | VNet + subnets + NSGs | VNet + subnets + NSGs | VNet + subnets + NSGs | Private DNS Zones |
| `container-apps` | Environment + cloudflared | Environment + cloudflared | Environment (apps at 0) | - |
| `sql-database` | Serverless + PE | Serverless + PE | Geo-replica (paused) | - |
| `signalr` | Serverless + PE | Serverless + PE | - | - |
| `function-app` | Flex Consumption + storage | Flex Consumption + storage | - | - |
| `keyvault` | KV + RBAC | KV + RBAC | KV + RBAC | - |
| `storage` | General purpose + PE | General purpose + PE | - | - |
| `acr` | - | - | - | Standard + PE |
| `cloudflare` | Tunnel + DNS + ZT | Tunnel + DNS | Tunnel (standby) | - |
| `monitoring` | Log Analytics + AI + Alerts | Log Analytics + AI | Log Analytics | - |

### Deployment Order

1. Shared (ACR, DNS Zones)
2. Networking (VNets, subnets, NSGs, DNS links)
3. Key Vault
4. Data (SQL, Storage)
5. Compute (Container Apps Environment, SignalR, Function Apps)
6. Cloudflare (Tunnel, DNS, Zero Trust)
7. Monitoring (Log Analytics, App Insights, Alerts)

## Repo Structure

```
the-arena/
├── modules/
│   ├── networking/
│   ├── container-apps/
│   ├── sql-database/
│   ├── signalr/
│   ├── function-app/
│   ├── acr/
│   ├── keyvault/
│   ├── storage/
│   ├── cloudflare/
│   └── monitoring/
├── environments/
│   ├── shared/
│   ├── prod/
│   ├── staging/
│   └── dr/
├── templates/
│   ├── dotnet-api/
│   ├── node-api/
│   ├── rails-app/
│   ├── function-dotnet/
│   └── function-node/
├── scripts/
│   ├── new-app.sh
│   └── failover.sh
└── docs/
    └── plans/
```
