# Solution ALM — Troubleshooting Guide

## Error: "Solution Import Failed — Missing Dependency"

**Symptom:** Import fails with `MissingComponentException` or "Required component not found".

**Cause:** Your solution references a component (table, field, option set) that doesn't exist in the target environment.

**Fix:**
```bash
# 1. Check what your solution depends on
pac solution check --path ./artifacts/solution.zip --geo UnitedStates

# 2. Import dependencies first (e.g., shared config solution)
pac solution import --path ./artifacts/HalyseSharedConfig_managed.zip
pac solution import --path ./artifacts/HalyseAccountGovernance_managed.zip

# 3. Import order matters — always import base solutions before dependent ones
```

**Prevention:** Maintain a `HalyseSharedConfig` solution that contains all shared tables/fields, and always import it first.

---

## Error: "Plugin Assembly Not Found After Import"

**Symptom:** Plugin step is registered but throws "Plugin type not found" at runtime.

**Cause:** The plugin assembly in the solution points to a specific strong name (version + public key token). If you recompiled without incrementing the version, Dataverse may not recognize it.

**Fix:**
```xml
<!-- In your .csproj, always increment AssemblyVersion on changes -->
<PropertyGroup>
  <AssemblyVersion>1.0.1.0</AssemblyVersion>  <!-- Increment patch -->
  <FileVersion>1.0.1.0</FileVersion>
</PropertyGroup>
```

```bash
# After updating version, re-export the solution from DEV (it will pick up the new assembly)
pac solution export --name HalyseAccountGovernance --path ./exported/solution.zip --managed false
pac solution unpack --zipfile ./exported/solution.zip --folder ./solution-components/account-governance
```

---

## Error: "Cannot Import Managed Solution — Unmanaged Customization Exists"

**Symptom:** "This solution is attempting to overwrite the component that was created by an unmanaged solution."

**Cause:** Someone manually customized a component in TEST/PROD that your managed solution is trying to own.

**Fix:**
```bash
# Force overwrite (removes the unmanaged layer)
pac solution import \
  --path ./solution.zip \
  --force-overwrite true

# If that still fails, manually remove the unmanaged customization in the target env:
# Maker Portal → Solutions → Default Solution → find the component → Delete
```

**Prevention:** Never customize in TEST or PROD. All changes go through DEV → export → PR → deploy pipeline.

---

## Error: "Environment Variable Has No Value"

**Symptom:** Plugin or flow reads empty string from env var; feature breaks in TEST/PROD.

**Cause:** Environment variable values are NOT included in the solution zip — they must be set manually per environment.

**Fix:**
```bash
pac auth select --name test
pac env-var set --schema-name halyse_ApiEndpoint --value "https://test-api.halyse.com/crm"
```

**Prevention:** Add env var setup to your deployment runbook/script. Every deploy checklist should include verifying env vars are set in the target environment.

---

## Error: "Flow is Turned Off After Import"

**Symptom:** Cloud flows are imported but are disabled/turned off in the target environment.

**Cause:** Flows import in a disabled state when connection references aren't mapped.

**Fix:**
```bash
# 1. Map connection references first
pac solution import \
  --path ./solution.zip \
  --connection-references ./connection-references/test-mappings.json

# 2. Then activate flows manually in Maker Portal, or via Power Automate Management connector

# 3. Or use the Power Platform Build Tools GitHub Action which handles this automatically
```

---

## Error: "pac solution unpack — File Already Exists"

**Symptom:** Unpack fails when re-running on an existing folder.

**Fix:**
```bash
# Use --allowDelete to let it clean up deleted components
pac solution unpack \
  --zipfile ./exported/solution.zip \
  --folder ./solution-components/account-governance \
  --allowDelete true   # ← This is key for re-runs

# If still failing, delete the folder and re-unpack fresh
rm -rf ./solution-components/account-governance
pac solution unpack --zipfile ./exported/solution.zip --folder ./solution-components/account-governance
```

---

## Error: "Authentication Failed in GitHub Actions"

**Symptom:** CI/CD fails with `401 Unauthorized` or `AADSTS` errors.

**Causes & Fixes:**

**A) Client secret expired:**
```bash
# Regenerate in Azure Portal → App Registrations → Certificates & Secrets
# Update PP_CLIENT_SECRET in GitHub Secrets
```

**B) Service principal not added as Application User:**
```
Power Platform Admin Center → Environments → [Your Env]
→ Settings → Users + Permissions → Application Users
→ New → Select your App ID → Assign System Administrator
```

**C) Wrong tenant ID:**
```bash
az account show --query tenantId  # Verify this matches PP_TENANT_ID secret
```

---

## Solution Checker: Critical Issues to Fix

| Issue | Severity | Fix |
|-------|----------|-----|
| Plugin using `IOrganizationServiceFactory` directly instead of via context | High | Use `context.OrganizationService` |
| Synchronous HTTP calls in plugins | Critical | Use async pattern or call from flow |
| `RetrieveMultiple` without column set | High | Always specify `new ColumnSet("field1", "field2")` |
| JavaScript using `Xrm.Page` (deprecated) | High | Replace with `executionContext.getFormContext()` |
| Plugin registered on `RetrieveMultiple` without filtering | Medium | Add query filter to avoid full-table scans |
| Hard-coded GUIDs in JavaScript | Medium | Use env vars or lookup by schema name |

---

## Quick Health Check After Deployment

```bash
# 1. Verify solution version
pac solution list | grep Halyse

# 2. Verify plugins are active
# (check in Maker Portal → Solutions → YourSolution → Plugin Assemblies)

# 3. Verify environment variables have values
pac env-var list --solution-name HalyseAccountGovernance

# 4. Run a quick smoke test — open a record and trigger the business rule
# Check Plugin Trace Logs: Settings → Customization → Plugin Trace Log
```
