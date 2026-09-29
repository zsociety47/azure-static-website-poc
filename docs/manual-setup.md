# Manual Setup in the Azure Portal

The same build as the scripts, done by clicking through the [Azure portal](https://portal.azure.com). Doing it by hand once shows what each script line actually creates; the [automated setup](../README.md#option-2-automated-setup-with-scripts) then does the same thing in a repeatable way.

Each step lists the script line that automates it. Pick a short suffix (2-8 lowercase letters or digits, e.g. `ab01`) and use it wherever you see `<suffix>`. If you also have a scripted build running, use a different suffix so the two don't collide.

Portal labels change from time to time. If a button has moved, search for the setting name in the portal's top search bar.

---

## Part A: Host the site

### 1. Create a resource group

*Automated by `az group create` in `scripts/deploy.sh`.*

1. Search for **Resource groups** and select **+ Create**.
2. **Subscription:** the subscription you want to use.
3. **Resource group:** `rg-staticweb-poc-<suffix>`
4. **Region:** East US (or the region closest to you).
5. **Tags** tab: add `project = azure-static-website-poc`, `environment = poc`, `managed-by = portal`, and `owner = <your name>`.
6. Select **Review + create**, then **Create**.

### 2. Create a storage account

*Automated by `az storage account create` in `scripts/deploy.sh`.*

1. Search for **Storage accounts** and select **+ Create**.
2. **Basics** tab:
   - **Resource group:** `rg-staticweb-poc-<suffix>`
   - **Storage account name:** `ststaticwebpoc<suffix>` (lowercase letters and digits only, unique across all of Azure)
   - **Region:** the same region as the resource group
   - **Primary service:** Azure Blob Storage or Azure Data Lake Storage Gen2
   - **Performance:** Standard
   - **Redundancy:** Locally-redundant storage (LRS)
3. **Advanced** tab:
   - **Require secure transfer for REST API operations:** on (`--https-only true`)
   - **Allow enabling anonymous access on individual containers:** off (`--allow-blob-public-access false`)
   - **Minimum TLS version:** Version 1.2 (`--min-tls-version TLS1_2`)
4. **Tags** tab: the same four tags as the resource group.
5. Select **Review + create**, then **Create**. Wait for "Your deployment is complete" and select **Go to resource**.

### 3. Enable static website hosting

*Automated by `az storage blob service-properties update --static-website` in `scripts/deploy.sh`.*

1. In the storage account menu, open **Data management > Static website**.
2. Set **Static website** to **Enabled**.
3. **Index document name:** `index.html`
4. **Error document path:** `404.html`
5. Select **Save**. Copy the **Primary endpoint**; this is the site address. Azure also creates a container named `$web`.

### 4. Give yourself permission to upload with your identity

*Automated by `az role assignment create` in `scripts/deploy.sh`.*

Being Owner of the subscription does not let you read or write files with your own identity; that needs a data role.

1. In the storage account menu, open **Access control (IAM)**.
2. Select **+ Add > Add role assignment**.
3. **Role** tab: search for and select **Storage Blob Data Contributor**, then **Next**.
4. **Members** tab: **Assign access to** User, group, or service principal. Select **+ Select members**, choose your own account, then **Select**.
5. Select **Review + assign** twice.

The role can take a few minutes to take effect. If the next step says you do not have permission, wait and try again.

### 5. Upload the site files

*Automated by `az storage blob upload-batch --auth-mode login` in `scripts/deploy.sh`.*

1. In the storage account menu, open **Data storage > Containers** and select **$web**.
2. Near the top, check **Authentication method**. If it says **Access key**, select **Switch to Microsoft Entra user account**. This is the portal's version of `--auth-mode login`: it uses your role from step 4 instead of the account's master key.
3. Select **Upload**, choose `site/index.html` and `site/404.html` from this repository, and select **Upload**.

### 6. Test it

1. Open the primary endpoint from step 3. The home page loads.
2. Add `/does-not-exist` to the end of the address. The custom 404 page loads.

---

## Part B: Let GitHub Actions sign in

These steps connect a GitHub repository to the storage account so pushes deploy automatically. `scripts/setup-oidc.sh` does all of Part B in one command.

If you already ran `setup-oidc.sh` for this repository, skip Part B: you would end up with two app registrations with the same name, and the repository can only point at one of them.

### 7. Register an app for GitHub Actions

*Automated by `az ad app create` and `az ad sp create` in `scripts/setup-oidc.sh`.*

1. Search for **Microsoft Entra ID**, open **App registrations**, and select **+ New registration**.
2. **Name:** `github-actions-<repo-name>`
3. **Supported account types:** Accounts in this organizational directory only.
4. Select **Register**. The portal also creates the service principal (listed under **Enterprise applications**).
5. From the **Overview** page, note the **Application (client) ID** and **Directory (tenant) ID**. Do not paste them anywhere public.

### 8. Add the federated credential

*Automated by `az ad app federated-credential create` in `scripts/setup-oidc.sh`.*

1. In the app registration, open **Certificates & secrets > Federated credentials** and select **+ Add credential**.
2. **Federated credential scenario:** Other issuer.
3. **Issuer:** `https://token.actions.githubusercontent.com`
4. **Value (subject identifier):** the exact subject GitHub sends. For newer repositories this includes owner and repository IDs, for example `repo:zsociety47@122703085/azure-static-website-poc@1396638213:environment:production`. Get yours with:
   ```bash
   gh api repos/<owner>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix
   ```
   then add `:environment:production` to the end.
5. **Name:** `github-production`. **Audience:** `api://AzureADTokenExchange` (the default).
6. Select **Add**.

> The **GitHub Actions deploying Azure resources** scenario in the same list builds the older name-only subject (`repo:owner/name:environment:production`). Newer repositories no longer send that format, so sign-in fails with `AADSTS700213: No matching federated identity record found`. Using **Other issuer** with the exact subject avoids this.

### 9. Grant the app access to the storage account only

*Automated by `az role assignment create --assignee-principal-type ServicePrincipal` in `scripts/setup-oidc.sh`.*

1. Open the storage account, then **Access control (IAM) > + Add > Add role assignment**.
2. **Role:** Storage Blob Data Contributor.
3. **Members:** select **+ Select members**, search for `github-actions-<repo-name>`, select it, then **Select**.
4. Select **Review + assign** twice.

### 10. Save the values in GitHub

*Automated with `gh secret set` and `gh variable set`.*

1. In the GitHub repository, open **Settings > Secrets and variables > Actions**.
2. **Secrets** tab, **New repository secret** for each: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` (found on the subscription's **Overview** page in the portal).
3. **Variables** tab, **New repository variable** for each: `STORAGE_ACCOUNT_NAME` (`ststaticwebpoc<suffix>`) and `SITE_URL` (the primary endpoint from step 3).

Push any change to `main` and the workflow deploys it.

---

## Clean up when you're done

A storage account this size costs cents per month, but delete it when you no longer need it.

1. **Resource group:** open **Resource groups > rg-staticweb-poc-`<suffix>` > Delete resource group**, type the name to confirm, and select **Delete**. This removes the storage account and the site.
2. **App registration (only if you did Part B by hand):** open **Microsoft Entra ID > App registrations > github-actions-`<repo-name>` > Delete**. This also removes its service principal and federated credential.

If you built everything with the scripts instead, `./scripts/teardown.sh <suffix>` does both steps.
