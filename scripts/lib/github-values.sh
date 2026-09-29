# Shared by setup-oidc.sh and teardown.sh: the secrets and
# variables setup-oidc.sh saves in GitHub for the deploy workflow.
# Sourced, not run directly.

GITHUB_SECRETS=(AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID)
GITHUB_VARIABLES=(STORAGE_ACCOUNT_NAME SITE_URL)

gh_ready() {
  command -v gh >/dev/null && gh auth status >/dev/null 2>&1
}

# The owner/repo of the clone in the current folder, or nothing.
current_repo() {
  gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true
}

# Prints the names of this project's values that exist in the repository, one per line.
existing_github_values() {
  local repo="$1" name secrets variables
  secrets="$(gh secret list --repo "$repo" --json name --jq '.[].name' 2>/dev/null || true)"
  variables="$(gh variable list --repo "$repo" --json name --jq '.[].name' 2>/dev/null || true)"
  for name in "${GITHUB_SECRETS[@]}"; do
    if grep -qx "$name" <<<"$secrets"; then echo "$name"; fi
  done
  for name in "${GITHUB_VARIABLES[@]}"; do
    if grep -qx "$name" <<<"$variables"; then echo "$name"; fi
  done
}

remove_github_values() {
  local repo="$1" name
  for name in "${GITHUB_SECRETS[@]}"; do
    gh secret delete "$name" --repo "$repo" >/dev/null 2>&1 || true
  done
  for name in "${GITHUB_VARIABLES[@]}"; do
    gh variable delete "$name" --repo "$repo" >/dev/null 2>&1 || true
  done
}

# Removes existing values before a fresh setup, so none are left stale if the setup stops partway.
clear_github_values_before_setup() {
  local repo="$1" found
  if ! gh_ready; then
    echo "    GitHub CLI (gh) is not installed or not signed in; skipping."
    return 0
  fi
  if [[ "$repo" != */* ]]; then
    echo "    Not run from inside a GitHub repository clone; skipping."
    return 0
  fi
  found="$(existing_github_values "$repo" | tr '\n' ' ')"
  if [[ -z "$found" ]]; then
    echo "    None found in $repo."
    return 0
  fi
  echo "    Removing from $repo: $found"
  remove_github_values "$repo"
}
