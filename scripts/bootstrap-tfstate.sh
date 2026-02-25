#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Terraform remote state storage
# Run this ONCE before any terraform init

RESOURCE_GROUP="rg-arena-tfstate-centralus-001"
STORAGE_ACCOUNT="starenatfstate001"
CONTAINER="tfstate"
LOCATION="centralus"

echo "=== Bootstrapping Terraform State ==="
echo ""

echo "1. Creating resource group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

echo "2. Creating storage account..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

echo "3. Creating blob container..."
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --output none

echo ""
echo "=== Terraform state backend ready ==="
echo "  Resource Group:  $RESOURCE_GROUP"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Container:       $CONTAINER"
