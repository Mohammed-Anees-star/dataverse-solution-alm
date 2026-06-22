# Solution ALM — Environment Setup Guide

## Prerequisites

```bash
# 1. PAC CLI
npm install -g @microsoft/power-platform-cli
pac --version   # Should be 1.30+

# 2. Azure CLI (for service principal creation)
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

# 3. PowerShell 7+ (for pipeline scripts, cross-platform)
pwsh --version
```

---

## Step 1: Create a Service Principal for CI/CD

Human logins (interactive browser) can't run in GitHub Actions. You need a Service Principal (an "app identity") with permission to deploy solutions.

```powershell
# Login to Azure
az login

# Create the service principal
az ad sp create-for-rbac \
  --name "Halyse-PowerPlatform-CI" \
  --role Contributor \
  --scopes /subscriptions/<your-subscription-id>

# Output (save these — you'll need them in GitHub Secrets):
# {
#   "appId":       "<APPLICATION_ID>",   → PP_APP_ID
#   "password":    "<CLIENT_SECRET>",    → PP_CLIENT_SECRET
#   "tenant":      "<TENANT_ID>",        → PP_TENANT_ID
# }
```

### Grant the SP Power Platform permissions

1. Go to **Power Platform Admin Center** → Environments → Your ENV
2. Settings → Users + Permissions → Application Users
3. New App User → Select your SP → Assign **System Administrator** role

---

## Step 2: GitHub Repository Secrets

In your GitHub repo: Settings → Secrets and Variables → Actions → New repository secret

| Secret Name | Value | Used For |
|-------------|-------|----------|
| `PP_APP_ID` | Azure App Registration ID | Service principal auth |
| `PP_CLIENT_SECRET` | Azure App client secret | Service principal auth |
| `PP_TENANT_ID` | Your Azure AD tenant ID | Service principal auth |
| `PP_DEV_URL` | `https://yourorg-dev.crm.dynamics.com` | Export source |
| `PP_TEST_URL` | `https://yourorg-test.crm.dynamics.com` | Test deployment |
| `PP_PROD_URL` | `https://yourorg.crm.dynamics.com` | Production deployment |

---

## Step 3: Initial Solution Export (Bootstrap)

The first time you set up a repo, you need to export the existing solution from DEV and commit it:

```bash
# Authenticate to DEV
pac auth create --name dev --url https://yourorg-dev.crm.dynamics.com

# Export each solution
pac solution export \
  --name HalyseAccountGovernance \
  --path ./exported/HalyseAccountGovernance.zip \
  --managed false

# Unpack all solutions to their folders
pac solution unpack \
  --zipfile ./exported/HalyseAccountGovernance.zip \
  --folder ./solution-components/account-governance

pac solution unpack \
  --zipfile ./exported/HalyseOpportunityRevenue.zip \
  --folder ./solution-components/opportunity-revenue

# ... repeat for each solution

# Commit everything
git add .
git commit -m "feat: Initial solution export from DEV"
git push
```

---

## Step 4: Set Environment Variables Per Environment

After importing to TEST and PROD, set the environment variable values:

```bash
# Switch to TEST
pac auth select --name test

# Set each env var value
pac env-var set --schema-name halyse_ApiEndpoint \
  --value "https://test-api.halyse.com/crm"

pac env-var set --schema-name halyse_MaxRetries \
  --value "3"

# Switch to PROD
pac auth select --name prod

pac env-var set --schema-name halyse_ApiEndpoint \
  --value "https://api.halyse.com/crm"
```

---

## Step 5: Verify with a Test Deployment

```bash
# Pack managed version
pac solution pack \
  --zipfile ./artifacts/HalyseAccountGovernance_managed.zip \
  --folder ./solution-components/account-governance \
  --managed true

# Auth to TEST
pac auth select --name test

# Import
pac solution import \
  --path ./artifacts/HalyseAccountGovernance_managed.zip \
  --activate-plugins true \
  --force-overwrite true

# Verify
pac solution list | grep Halyse
```

You should see your solution listed with the correct version number.

---

## Daily Developer Workflow (After Setup)

```bash
# 1. Make changes in DEV environment (forms, plugins, etc.)

# 2. Export your changes
pac solution export \
  --name HalyseAccountGovernance \
  --path ./exported/HalyseAccountGovernance.zip \
  --managed false

pac solution unpack \
  --zipfile ./exported/HalyseAccountGovernance.zip \
  --folder ./solution-components/account-governance \
  --allowDelete true

# 3. Review what changed
git diff ./solution-components/account-governance

# 4. Commit and open a PR
git add ./solution-components/account-governance
git commit -m "feat: Add credit limit validation to Account form"
git push origin feature/credit-limit-validation

# 5. PR merge triggers automatic deployment to TEST
# 6. After QA approval, release tag triggers PROD deployment
```
