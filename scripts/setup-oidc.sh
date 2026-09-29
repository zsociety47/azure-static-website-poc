#!/usr/bin/env bash
#
# Lets GitHub Actions deploy to the storage account using OpenID Connect,
# with no stored passwords or keys. Safe to re-run.
#
# Usage: ./scripts/setup-oidc.sh <github-owner>/<repo> <storage-account-name> [environment]
#   environment  GitHub environment the workflow deploys to, defaults to production

set -euo pipefail

REPO="${1:-}"
STORAGE_ACCOUNT="${2:-}"
ENVIRONMENT="${3:-production}"

if [[ ! "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ || -z "$STORAGE_ACCOUNT" ]]; then
  echo "Usage: $0 <github-owner>/<repo> <storage-account-name> [environment]" >&2
  echo "Example: $0 zsociety47/azure-static-website-poc ststaticwebpoczs01" >&2
  exit 1
fi

APP_NAME="github-actions-${REPO##*/}"
CREDENTIAL_NAME="github-${ENVIRONMENT}"
# GitHub builds this subject into every token; Azure matches it exactly, including letter case.
SUBJECT="repo:${REPO}:environment:${ENVIRONMENT}"

if ! az account show --output none 2>/dev/null; then
  echo "You are not signed in to Azure. Run 'az login' first." >&2
  exit 1
fi

STORAGE_ID="$(az storage account list --query "[?name=='$STORAGE_ACCOUNT'].id | [0]" --output tsv)"
if [[ -z "$STORAGE_ID" ]]; then
  echo "Storage account $STORAGE_ACCOUNT was not found in the current subscription." >&2
  exit 1
fi

echo "==> Creating app registration $APP_NAME"
APP_ID="$(az ad app list --display-name "$APP_NAME" --query "[0].appId" --output tsv)"
if [[ -n "$APP_ID" ]]; then
  echo "    Already exists, reusing it."
else
  APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId --output tsv)"
fi

echo "==> Creating service principal"
if az ad sp show --id "$APP_ID" --output none 2>/dev/null; then
  echo "    Already exists, reusing it."
else
  az ad sp create --id "$APP_ID" --output none
fi
SP_ID="$(az ad sp show --id "$APP_ID" --query id --output tsv)"

echo "==> Adding federated credential for $SUBJECT"
if [[ "$(az ad app federated-credential list --id "$APP_ID" --query "length([?name=='$CREDENTIAL_NAME'])" --output tsv)" != "0" ]]; then
  echo "    Already exists, reusing it."
else
  az ad app federated-credential create \
    --id "$APP_ID" \
    --parameters "{
      \"name\": \"$CREDENTIAL_NAME\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$SUBJECT\",
      \"audiences\": [\"api://AzureADTokenExchange\"],
      \"description\": \"GitHub Actions deploys from $REPO to the $ENVIRONMENT environment\"
    }" \
    --output none
fi

echo "==> Granting Storage Blob Data Contributor on $STORAGE_ACCOUNT"
if [[ -n "$(az role assignment list --assignee "$SP_ID" --role "Storage Blob Data Contributor" --scope "$STORAGE_ID" --query "[].id" --output tsv)" ]]; then
  echo "    Already assigned."
else
  az role assignment create \
    --assignee-object-id "$SP_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "$STORAGE_ID" \
    --output none
fi

echo
echo "Done. Save these in GitHub (Settings > Secrets and variables > Actions):"
echo
echo "  Secrets:"
echo "    AZURE_CLIENT_ID        $APP_ID"
echo "    AZURE_TENANT_ID        $(az account show --query tenantId --output tsv)"
echo "    AZURE_SUBSCRIPTION_ID  $(az account show --query id --output tsv)"
echo "  Variable:"
echo "    STORAGE_ACCOUNT_NAME   $STORAGE_ACCOUNT"
echo
echo "New role assignments can take a few minutes to take effect."
