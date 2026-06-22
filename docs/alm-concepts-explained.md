# Solution ALM — Core Concepts Deep Dive

## 1. The Publisher

Before you create any solution, you create a **Publisher**. This is your namespace — it prefixes every component you create.

```
Publisher Name:   Halyse Technologies
Publisher Prefix: halyse

Result:
  - Custom tables:  halyse_projectmetrics
  - Custom fields:  halyse_creditrating
  - Web resources:  halyse_/js/AccountGovernance.js
  - PCF controls:   halyse_Halyse.StarRatingControl
```

**Why this matters:**
- Two solutions from different vendors can coexist safely — no naming collisions
- Microsoft uses the `cr<random>_` prefix for user-made customizations
- Enterprise: always use your company prefix, never the default `cr` prefix

---

## 2. Solution Layers

Power Platform uses a layering system. When you import a solution, it sits on top (or below) other solutions:

```
┌────────────────────────────────────┐
│  ACTIVE LAYER (your customization) │  ← What users see
├────────────────────────────────────┤
│  HalyseAccountGovernance (managed) │  ← Your solution
├────────────────────────────────────┤
│  Microsoft Dynamics 365 (base)     │  ← Microsoft's layer
└────────────────────────────────────┘
```

A managed solution creates a layer. When you delete the solution, its layer is removed and the layer below shows through. This is why managed solutions delete cleanly.

---

## 3. Solution Upgrade vs Update

This trips up every developer:

### Solution Update
```
Import v1.1.0 over v1.0.0 → immediate replacement
```
- Fast, no staging
- Risky: if import fails mid-way, you can end up with a broken partial state
- Good for: hotfixes, minor changes

### Solution Upgrade (Preferred for major releases)
```
Stage v1.1.0 alongside v1.0.0 → apply upgrade → old version removed
```
- Two-phase: Stage first, then Apply
- Safe: if staging fails, v1.0.0 is still running intact
- Removes old components automatically on apply
- Good for: removing fields/tables, major releases

```powershell
# Stage the new version (runs in background, doesn't affect live)
pac solution import --path ./v1.1.0.zip --import-as-holding

# Apply the upgrade (swaps live, removes old)
pac solution upgrade --solution-name HalyseAccountGovernance
```

---

## 4. Environment Variables

Environment Variables solve the "same solution, different config per environment" problem.

**Without env vars:**
```javascript
// ❌ Hardcoded — breaks when you move to prod
const apiEndpoint = "https://dev-api.halyse.com/crm";
```

**With env vars:**
```javascript
// ✅ Read from Dataverse at runtime — each env has its own value
const apiEndpoint = await Xrm.WebApi.retrieveRecord(
    "environmentvariablevalue", id, "?$select=value"
);
```

### How to define an Environment Variable

In your solution, create an **Environment Variable Definition**:
```
Schema Name:   halyse_ApiEndpoint
Display Name:  API Endpoint
Type:          String
Default Value: https://dev-api.halyse.com/crm (for dev)
```

Then create **Environment Variable Values** per environment (stored outside the solution):
```
DEV:  https://dev-api.halyse.com/crm
TEST: https://test-api.halyse.com/crm
PROD: https://api.halyse.com/crm
```

The definition travels with the solution. The values are set manually or via deployment pipeline per environment.

### In Plugins — reading Environment Variables

```csharp
// Reading an env var from a plugin (the correct enterprise pattern)
private string GetEnvironmentVariable(IOrganizationService service, string schemaName)
{
    var query = new QueryExpression("environmentvariablevalue")
    {
        ColumnSet = new ColumnSet("value"),
    };
    query.AddLink("environmentvariabledefinition", "environmentvariabledefinitionid",
        "environmentvariabledefinitionid")
        .LinkCriteria.AddCondition("schemaname", ConditionOperator.Equal, schemaName);

    var results = service.RetrieveMultiple(query);
    if (results.Entities.Count > 0)
        return results.Entities[0].GetAttributeValue<string>("value");

    // Fall back to definition default value
    var defQuery = new QueryExpression("environmentvariabledefinition")
    {
        ColumnSet = new ColumnSet("defaultvalue"),
        Criteria = { Conditions = {
            new ConditionExpression("schemaname", ConditionOperator.Equal, schemaName)
        }}
    };
    var defResult = service.RetrieveMultiple(defQuery);
    return defResult.Entities.FirstOrDefault()?.GetAttributeValue<string>("defaultvalue") ?? string.Empty;
}
```

---

## 5. Connection References

Connection References are the solution-aware way to use connectors (SharePoint, Outlook, Teams, SQL, etc.) in Flows.

**Without connection references:**
- Your Flow has a hardcoded connection owned by a user
- When that user leaves, all flows break
- You can't move the flow between environments cleanly

**With connection references:**
```
Solution contains:   ConnectionReference (pointer, no credentials)
Environment contains: Actual connection (credentials, per env)
```

When you import the solution to TEST, the connection reference is mapped to the TEST environment's connection. The flow itself doesn't need to change.

### Defining a connection reference (solution-components/):
```xml
<!-- In your unpacked solution XML -->
<connectionreference>
  <connectionreferencedisplayname>Halyse SharePoint</connectionreferencedisplayname>
  <connectorid>/providers/Microsoft.PowerApps/apis/shared_sharepointonline</connectorid>
  <iscustomizable>1</iscustomizable>
  <statecode>0</statecode>
  <connectionreferencelogicalname>halyse_HalyseSharePoint</connectionreferencelogicalname>
</connectionreference>
```

### Mapping during deployment (pipeline script):
```powershell
# Set the connection reference mapping before import
pac solution import `
  --path ./solution.zip `
  --connection-references ./connection-references/test-mappings.json
```

```json
// connection-references/test-mappings.json
[
  {
    "logicalName": "halyse_HalyseSharePoint",
    "connectionId": "/providers/Microsoft.PowerApps/apis/shared_sharepointonline/connections/abc123"
  }
]
```

---

## 6. pac solution unpack — Why It Matters

When you export a solution, you get a `.zip` file with XML inside. You can't meaningfully diff or review a `.zip` in a PR.

`pac solution unpack` extracts the zip into a folder structure of **human-readable XML files** — one file per component. Now:
- You can see exactly what changed in a Git diff
- PRs show "AccountGovernancePlugin.cs was modified"
- Code review on solution components is possible

```
Before unpack (opaque):
  HalyseAccountGovernance.zip (binary)

After unpack (reviewable):
  solution-components/account-governance/
    Other/Solution.xml               ← solution metadata
    PluginAssemblies/
      Halyse.Dataverse.AccountGovernance.xml   ← plugin step registrations
    WebResources/
      halyse_AccountGovernance.js.data.xml     ← JS file (base64)
    Entities/
      account/
        FormXml/
          main.xml                   ← form layout
        Views/
          Active Accounts.xml        ← view FETCHXML
```

---

## 7. Solution Checker (Best Practice Analysis)

Before deploying to production, always run the solution checker:

```powershell
pac solution check \
  --path ./artifacts/HalyseAccountGovernance.zip \
  --outputDirectory ./checker-results \
  --geo UnitedStates
```

It catches:
- Plugins using deprecated APIs
- Missing async patterns in JavaScript
- Security role issues
- Performance anti-patterns
- Unsupported customizations

The results come back as a JSON report with severity: Critical, High, Medium, Low.

In CI/CD, fail the build on any Critical findings.
