#!/usr/bin/env bash
#
# Deletes everything deploy.sh and setup-oidc.sh created. The live site stops working.
#
# Usage: ./scripts/teardown.sh <suffix> [repo-name]
#   suffix     the same suffix you passed to deploy.sh (e.g. zs01)
#   repo-name  GitHub repository name, defaults to azure-static-website-poc

set -euo pipefail

SUFFIX="${1:-}"
REPO_NAME="${2:-azure-static-website-poc}"

if [[ ! "$SUFFIX" =~ ^[a-z0-9]{2,8}$ ]]; then
  echo "Usage: $0 <suffix> [repo-name]" >&2
  exit 1
fi

RESOURCE_GROUP="rg-staticweb-poc-$SUFFIX"
STORAGE_ACCOUNT="ststaticwebpoc$SUFFIX"
APP_NAME="github-actions-$REPO_NAME"

if ! az account show --output none 2>/dev/null; then
  echo "You are not signed in to Azure. Run 'az login' first." >&2
  exit 1
fi

HAS_GROUP="$(az group exists --name "$RESOURCE_GROUP")"
APP_ID="$(az ad app list --display-name "$APP_NAME" --query "[0].appId" --output tsv)"

if [[ "$HAS_GROUP" != "true" && -z "$APP_ID" ]]; then
  echo "Nothing to delete: $RESOURCE_GROUP and $APP_NAME do not exist."
  exit 0
fi

echo "Subscription: $(az account show --query name --output tsv)"
echo "This will permanently delete:"
if [[ "$HAS_GROUP" == "true" ]]; then
  echo "  - Resource group $RESOURCE_GROUP (storage account $STORAGE_ACCOUNT and the live site)"
fi
if [[ -n "$APP_ID" ]]; then
  echo "  - App registration $APP_NAME (its service principal and federated credential)"
fi
echo
read -r -p "Type the resource group name ($RESOURCE_GROUP) to confirm: " CONFIRM
if [[ "$CONFIRM" != "$RESOURCE_GROUP" ]]; then
  echo "Names did not match. Nothing was deleted."
  exit 1
fi

if [[ "$HAS_GROUP" == "true" ]]; then
  STORAGE_ID="$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[?name=='$STORAGE_ACCOUNT'].id | [0]" --output tsv)"
  if [[ -n "$STORAGE_ID" ]]; then
    echo "==> Removing role assignments on $STORAGE_ACCOUNT"
    az role assignment delete --scope "$STORAGE_ID" --output none
  fi

  echo "==> Deleting resource group $RESOURCE_GROUP (this can take a few minutes)"
  az group delete --name "$RESOURCE_GROUP" --yes --output none
fi

if [[ -n "$APP_ID" ]]; then
  echo "==> Deleting app registration $APP_NAME"
  az ad app delete --id "$APP_ID"
fi

echo
echo "Teardown complete. The GitHub repository is untouched; its deploy workflow will fail until you run deploy.sh and setup-oidc.sh again."
