#!/usr/bin/env bash
#
# Creates the Azure resources for the static website and uploads site/.
# Safe to re-run: existing resources are reused, files are overwritten.
#
# Usage: ./scripts/deploy.sh <suffix> [location]
#   suffix    2-8 lowercase letters or digits, makes names unique (e.g. zs01)
#   location  Azure region, defaults to eastus

set -euo pipefail

SUFFIX="${1:-}"
LOCATION="${2:-eastus}"

if [[ ! "$SUFFIX" =~ ^[a-z0-9]{2,8}$ ]]; then
  echo "Usage: $0 <suffix> [location]" >&2
  echo "The suffix must be 2-8 lowercase letters or digits, for example: zs01" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_DIR="$SCRIPT_DIR/../site"

RESOURCE_GROUP="rg-staticweb-poc-$SUFFIX"
STORAGE_ACCOUNT="ststaticwebpoc$SUFFIX"
TAGS=(project=azure-static-website-poc environment=poc managed-by=azure-cli "owner=${OWNER:-$(whoami)}")

if ! az account show --output none 2>/dev/null; then
  echo "You are not signed in to Azure. Run 'az login' first." >&2
  exit 1
fi

echo "Subscription:    $(az account show --query name --output tsv)"
echo "Resource group:  $RESOURCE_GROUP"
echo "Storage account: $STORAGE_ACCOUNT"
echo "Region:          $LOCATION"
echo

echo "==> Creating resource group"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags "${TAGS[@]}" \
  --output none

echo "==> Creating storage account"
if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "    Already exists, reusing it."
else
  if [[ "$(az storage account check-name --name "$STORAGE_ACCOUNT" --query nameAvailable --output tsv)" != "true" ]]; then
    echo "The name $STORAGE_ACCOUNT is taken by another Azure customer. Pick a different suffix." >&2
    exit 1
  fi
  az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --kind StorageV2 \
    --sku Standard_LRS \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --tags "${TAGS[@]}" \
    --output none
fi

echo "==> Enabling static website hosting"
az storage blob service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --static-website \
  --index-document index.html \
  --404-document 404.html \
  --output none

echo "==> Granting you Storage Blob Data Contributor on this storage account"
STORAGE_ID="$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id --output tsv)"
MY_ID="$(az ad signed-in-user show --query id --output tsv)"
if [[ -n "$(az role assignment list --assignee "$MY_ID" --role "Storage Blob Data Contributor" --scope "$STORAGE_ID" --query "[].id" --output tsv)" ]]; then
  echo "    Already assigned."
else
  az role assignment create \
    --assignee-object-id "$MY_ID" \
    --assignee-principal-type User \
    --role "Storage Blob Data Contributor" \
    --scope "$STORAGE_ID" \
    --output none
fi

# New role assignments can take a few minutes to reach the storage service.
echo "==> Uploading site files"
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if az storage blob upload-batch \
      --account-name "$STORAGE_ACCOUNT" \
      --auth-mode login \
      --destination '$web' \
      --source "$SITE_DIR" \
      --overwrite \
      --only-show-errors \
      --output none; then
    break
  fi
  if [[ "$attempt" == 10 ]]; then
    echo "Upload still failing after 10 attempts. Wait a few minutes and re-run this script." >&2
    exit 1
  fi
  echo "    Role not active yet (attempt $attempt of 10). Retrying in 30 seconds..."
  sleep 30
done

WEB_URL="$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query primaryEndpoints.web --output tsv)"

echo
echo "Done. Your site is live at:"
echo "  $WEB_URL"
echo
echo "Storage account name (needed for setup-oidc.sh): $STORAGE_ACCOUNT"
