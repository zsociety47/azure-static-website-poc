#!/usr/bin/env bash
#
# Lets GitHub Actions deploy to the storage account using OpenID Connect,
# with no stored passwords or keys, then offers to save the values the
# workflow needs in the GitHub repository. Safe to re-run.
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

if ! az account show --output none 2>/dev/null; then
  echo "You are not signed in to Azure. Run 'az login' first." >&2
  exit 1
fi

# Newer repositories put owner and repository IDs in the subject
# (repo:owner@123/name@456), so ask GitHub instead of building it by hand.
# Azure matches the subject exactly, including letter case.
SUBJECT_PREFIX="$(gh api "repos/$REPO/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty' 2>/dev/null || true)"
if [[ -z "$SUBJECT_PREFIX" ]]; then
  SUBJECT_PREFIX="repo:$REPO"
fi
SUBJECT="${SUBJECT_PREFIX}:environment:${ENVIRONMENT}"

STORAGE_ID="$(az storage account list --query "[?name=='$STORAGE_ACCOUNT'].id | [0]" --output tsv)"
if [[ -z "$STORAGE_ID" ]]; then
  echo "Storage account $STORAGE_ACCOUNT was not found in the current subscription." >&2
  exit 1
fi

# shellcheck source=lib/github-values.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/github-values.sh"
echo "==> Removing existing GitHub secrets and variables from $REPO"
clear_github_values_before_setup "$REPO"

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
CREDENTIAL_JSON="{
  \"name\": \"$CREDENTIAL_NAME\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"$SUBJECT\",
  \"audiences\": [\"api://AzureADTokenExchange\"],
  \"description\": \"GitHub Actions deploys from $REPO to the $ENVIRONMENT environment\"
}"
EXISTING_SUBJECT="$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$CREDENTIAL_NAME'].subject | [0]" --output tsv)"
if [[ -z "$EXISTING_SUBJECT" ]]; then
  az ad app federated-credential create --id "$APP_ID" --parameters "$CREDENTIAL_JSON" --output none
elif [[ "$EXISTING_SUBJECT" != "$SUBJECT" ]]; then
  echo "    Exists with subject $EXISTING_SUBJECT, updating it."
  az ad app federated-credential update --id "$APP_ID" --federated-credential-id "$CREDENTIAL_NAME" --parameters "$CREDENTIAL_JSON" --output none
else
  echo "    Already exists, reusing it."
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

TENANT_ID="$(az account show --query tenantId --output tsv)"
SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
SITE_URL="$(az storage account show --ids "$STORAGE_ID" --query primaryEndpoints.web --output tsv)"

echo
echo "==> Saving values in GitHub repository $REPO"
SAVED_TO_GITHUB=false
if gh_ready; then
  read -r -p "    Save the secrets and variables in $REPO now? [Y/n] " ANSWER || ANSWER=n
  if [[ ! "$ANSWER" =~ ^[Nn] ]]; then
    printf '%s' "$APP_ID"          | gh secret set AZURE_CLIENT_ID --repo "$REPO"
    printf '%s' "$TENANT_ID"       | gh secret set AZURE_TENANT_ID --repo "$REPO"
    printf '%s' "$SUBSCRIPTION_ID" | gh secret set AZURE_SUBSCRIPTION_ID --repo "$REPO"
    gh variable set STORAGE_ACCOUNT_NAME --repo "$REPO" --body "$STORAGE_ACCOUNT"
    gh variable set SITE_URL --repo "$REPO" --body "$SITE_URL"
    SAVED_TO_GITHUB=true
  fi
else
  echo "    GitHub CLI (gh) is not installed or not signed in; skipping."
fi

echo
if [[ "$SAVED_TO_GITHUB" == true ]]; then
  echo "Done. Saved in GitHub (values are not shown):"
  echo "  Secrets:   AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"
  echo "  Variables: STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT, SITE_URL=$SITE_URL"
else
  echo "Done. Add these at https://github.com/$REPO/settings/secrets/actions"
  echo
  echo "  Secrets tab:"
  echo "    AZURE_CLIENT_ID        $APP_ID"
  echo "    AZURE_TENANT_ID        $TENANT_ID"
  echo "    AZURE_SUBSCRIPTION_ID  $SUBSCRIPTION_ID"
  echo "  Variables tab:"
  echo "    STORAGE_ACCOUNT_NAME   $STORAGE_ACCOUNT"
  echo "    SITE_URL               $SITE_URL"
fi
echo
echo "See the app registration in the Azure portal:"
echo "  https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$APP_ID"
echo
echo "New role assignments can take a few minutes to take effect."
