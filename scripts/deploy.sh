#!/usr/bin/env bash
set -euo pipefail

# Deploy the Arena platform
# Usage: ./scripts/deploy.sh <environment>
# Example: ./scripts/deploy.sh shared
#          ./scripts/deploy.sh staging

ENVIRONMENT="${1:?Usage: $0 <shared|staging|prod|dr>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$REPO_ROOT/environments/$ENVIRONMENT"

if [[ ! -d "$ENV_DIR" ]]; then
  echo "Error: Environment '$ENVIRONMENT' not found at $ENV_DIR"
  exit 1
fi

echo "=== Deploying environment: $ENVIRONMENT ==="
echo ""

cd "$ENV_DIR"

echo "1. Initializing Terraform..."
terraform init

echo ""
echo "2. Planning..."
terraform plan -out=tfplan

echo ""
read -rp "Apply this plan? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  rm -f tfplan
  exit 0
fi

echo ""
echo "3. Applying..."
terraform apply tfplan
rm -f tfplan

echo ""
echo "=== Environment '$ENVIRONMENT' deployed ==="
