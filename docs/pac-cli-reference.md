# PAC CLI Complete Reference

## Installation

```bash
# Via npm (cross-platform)
npm install -g @microsoft/power-platform-cli

# Verify
pac --version
```

---

## Authentication

```bash
# Create a named auth profile (interactive browser login)
pac auth create --name dev --url https://yourorg-dev.crm.dynamics.com

# Create with service principal (for CI/CD — no human interaction)
pac auth create \
  --name cicd \
  --url https://yourorg.crm.dynamics.com \
  --tenant <tenant-id> \
  --applicationId <app-id> \
  --clientSecret <secret>

# List all auth profiles
pac auth list

# Switch active profile
pac auth select --name prod

# Delete a profile
pac auth delete --name dev

# Show current environment info
pac org who
```

---

## Solution Commands

### Export

```bash
# Export unmanaged (for source control)
pac solution export \
  --name HalyseAccountGovernance \
  --path ./exported/HalyseAccountGovernance_unmanaged.zip \
  --managed false

# Export managed (for deployment)
pac solution export \
  --name HalyseAccountGovernance \
  --path ./exported/HalyseAccountGovernance_managed.zip \
  --managed true

# Export with environment specified (without switching auth)
pac solution export \
  --name HalyseAccountGovernance \
  --path ./exported/solution.zip \
  --environment https://yourorg-dev.crm.dynamics.com
```

### Unpack (Export → Source Control)

```bash
# Unpack zip into folder of XML files (for git)
pac solution unpack \
  --zipfile ./exported/HalyseAccountGovernance_unmanaged.zip \
  --folder ./solution-components/account-governance \
  --processCanvasApps false \  # Set true if solution contains canvas apps
  --allowDelete true            # Allow removing files that were deleted from solution

# Unpack modes:
# --packagetype Unmanaged  (default)
# --packagetype Managed
# --packagetype Both       (extracts both layers)
```

### Pack (Source Control → Deployment Artifact)

```bash
# Pack source folder into zip (managed = ready for deployment)
pac solution pack \
  --zipfile ./artifacts/HalyseAccountGovernance_managed.zip \
  --folder ./solution-components/account-governance \
  --managed true

# Pack unmanaged (for re-import to dev)
pac solution pack \
  --zipfile ./artifacts/HalyseAccountGovernance_unmanaged.zip \
  --folder ./solution-components/account-governance \
  --managed false
```

### Import

```bash
# Basic import
pac solution import \
  --path ./artifacts/HalyseAccountGovernance_managed.zip

# Import with options
pac solution import \
  --path ./artifacts/HalyseAccountGovernance_managed.zip \
  --activate-plugins true \           # Enable plugins after import
  --force-overwrite true \            # Overwrite existing managed solution
  --skip-dependency-check false \     # Validate dependencies (keep true)
  --publish-changes true              # Publish immediately after import

# Import to specific environment (CI/CD)
pac solution import \
  --path ./artifacts/solution.zip \
  --environment https://yourorg-test.crm.dynamics.com \
  --activate-plugins true

# Import as holding (two-phase upgrade — staging)
pac solution import \
  --path ./artifacts/HalyseAccountGovernance_managed.zip \
  --import-as-holding true

# Apply the staged upgrade
pac solution upgrade \
  --solution-name HalyseAccountGovernance
```

### List & Inspect

```bash
# List all solutions in current environment
pac solution list

# Check solution dependencies
pac solution check \
  --path ./artifacts/solution.zip \
  --outputDirectory ./checker-results \
  --geo UnitedStates   # or Europe, Asia, etc.

# Show solution version info
pac solution show --path ./artifacts/solution.zip
```

### Clone (Alternative to Export + Unpack)

```bash
# Clone solution directly to source folder (export + unpack in one step)
pac solution clone \
  --name HalyseAccountGovernance \
  --outputDirectory ./solution-components/account-governance \
  --processCanvasApps false
```

---

## Plugin Commands

```bash
# Push plugin assembly to environment (dev only — bypasses solution)
pac plugin push --pluginFile ./bin/Release/Halyse.Dataverse.AccountGovernance.dll

# List plugin assemblies
pac plugin list
```

---

## PCF Commands

```bash
# Initialize a new PCF control
pac pcf init \
  --namespace Halyse \
  --name StarRatingControl \
  --template field   # or: dataset

# Push PCF control to environment (dev only — hot reload for testing)
pac pcf push --publisher-prefix halyse

# Refresh generated types after manifest changes
npm run refreshTypes
# (runs pcf-scripts refreshTypes internally)
```

---

## Environment & Org Commands

```bash
# List all environments in your tenant
pac env list

# Show current environment
pac org who

# Switch to a different environment
pac org select --environment https://yourorg-test.crm.dynamics.com

# Create a new developer environment
pac env create \
  --name "Halyse Dev" \
  --type Developer \
  --region unitedstates
```

---

## Connection Reference Commands

```bash
# List connection references in a solution
pac connection-reference list --solution-name HalyseAccountGovernance

# Set connection reference mapping (used in CI/CD)
# Passed during pac solution import:
pac solution import \
  --path ./solution.zip \
  --connection-references ./connection-references/test-mappings.json
```

---

## Environment Variable Commands

```bash
# List environment variables in a solution
pac env-var list --solution-name HalyseAccountGovernance

# Set an environment variable value (for target environment)
pac env-var set \
  --schema-name halyse_ApiEndpoint \
  --value "https://api.halyse.com/crm"
```

---

## Common CI/CD Pattern (Full Pipeline)

```bash
#!/bin/bash
# Full export-unpack-commit workflow (runs on schedule or manually)

# 1. Authenticate (service principal in CI)
pac auth create \
  --url "$DEV_URL" \
  --tenant "$TENANT_ID" \
  --applicationId "$APP_ID" \
  --clientSecret "$CLIENT_SECRET"

# 2. Export unmanaged solution from DEV
pac solution export \
  --name HalyseAccountGovernance \
  --path ./exported/HalyseAccountGovernance.zip \
  --managed false

# 3. Unpack to XML for source control
pac solution unpack \
  --zipfile ./exported/HalyseAccountGovernance.zip \
  --folder ./solution-components/account-governance \
  --allowDelete true

# 4. Commit changes
git config user.email "ci@halyse.com"
git config user.name "Halyse CI Bot"
git add ./solution-components/account-governance
git commit -m "chore: Export HalyseAccountGovernance from DEV [skip ci]" || echo "No changes"
git push

# ─────────────────────────────────────────────────
# Deploy to TEST (runs on PR merge to main)
# ─────────────────────────────────────────────────

# 5. Pack managed solution
pac solution pack \
  --zipfile ./artifacts/HalyseAccountGovernance_managed.zip \
  --folder ./solution-components/account-governance \
  --managed true

# 6. Import to TEST
pac auth create --url "$TEST_URL" --tenant "$TENANT_ID" \
  --applicationId "$APP_ID" --clientSecret "$CLIENT_SECRET"

pac solution import \
  --path ./artifacts/HalyseAccountGovernance_managed.zip \
  --activate-plugins true \
  --force-overwrite true
```
