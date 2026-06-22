# Dataverse Solution ALM — Enterprise Deployment Pipelines

> **Part 4 of the D365 Full-Stack Mastery Series** by [Halyse Technologies](https://halyse.com)
> Mohammed Anees | Senior D365 Architect

---

## What is Solution ALM?

**ALM = Application Lifecycle Management.**

In the Power Platform world, ALM means having a disciplined, automated process to:
- Package your customizations (plugins, PCF controls, flows, forms) into a **Solution**
- Move that solution reliably from **Dev → Test → Production**
- Never manually click "Export" or "Import" in the UI on production systems
- Ensure every deployment is **repeatable, auditable, and reversible**

Without ALM, you get:
- "Works on dev, broken on prod" incidents
- Nobody knows what changed or when
- Rollbacks are manual nightmares
- New environments take days to set up

With ALM, you get:
- One `git push` triggers a full validated deployment
- Every release has a Git commit hash and a build artifact
- New environments are set up in minutes from code

---

## The Three-Environment Model

```
┌─────────────────────────────────────────────────────────────┐
│                    ENVIRONMENT FLOW                          │
│                                                             │
│  DEV (Unmanaged)  →  TEST (Managed)  →  PROD (Managed)     │
│                                                             │
│  Customizers work     QA validates        Users work        │
│  Unmanaged solution   Managed solution    Managed solution  │
│  Can edit freely      Cannot edit         Cannot edit       │
│                                                             │
│  Export ────────────────────────────────────────────────→  │
│         pac solution export                                 │
│                    pac solution import ──────────────────→  │
└─────────────────────────────────────────────────────────────┘
```

### Why Managed vs Unmanaged?

| | Unmanaged | Managed |
|---|-----------|---------|
| **Used in** | Dev environment | Test & Production |
| **Can edit components?** | Yes | No (locked) |
| **Can delete the solution?** | Yes, leaves components behind | Yes, removes all components cleanly |
| **Contains source?** | Yes | No (compiled) |
| **Best for** | Development | Deployment |

**Rule:** Never import an unmanaged solution into production.

---

## What a Solution Contains

A Power Platform Solution is a container for:

| Component Type | Examples |
|----------------|----------|
| **Tables (Entities)** | Custom tables, field additions |
| **Forms & Views** | Form layouts, grid views |
| **Plugins** | Your C# assemblies + step registrations |
| **PCF Controls** | Your TypeScript controls |
| **Web Resources** | JavaScript files, images |
| **Flows** | Power Automate cloud flows |
| **Connection References** | Pointers to connectors (not credentials) |
| **Environment Variables** | Config values that differ per environment |
| **Canvas Apps** | Power Apps canvas applications |
| **Security Roles** | Role definitions |

---

## Repository Structure

```
dataverse-solution-alm/
│
├── .github/
│   └── workflows/
│       ├── export-solution.yml      # Triggered manually — export from DEV
│       ├── deploy-test.yml          # PR merge to main → deploy to TEST
│       └── deploy-prod.yml          # Release tag → deploy to PROD
│
├── pipeline/
│   ├── export/
│   │   └── export-solution.ps1      # PAC CLI export script
│   ├── import/
│   │   └── import-solution.ps1      # PAC CLI import + upgrade script
│   └── validate/
│       └── validate-solution.ps1    # Solution checker (Microsoft Best Practices)
│
├── environments/
│   ├── dev/
│   │   └── env.json                 # Dev environment config
│   ├── test/
│   │   └── env.json                 # Test environment config
│   └── prod/
│       └── env.json                 # Prod environment config
│
├── solution-components/             # Unpacked solution source files
│   ├── account-governance/          # JS + plugin for account rules
│   ├── opportunity-revenue/         # JS + plugin for opportunity
│   ├── case-escalation/             # JS + plugin for case SLA
│   ├── pcf-controls/               # PCF control web resources
│   └── shared-config/              # Publisher, shared tables
│
├── connection-references/
│   └── connection-references.json   # All connection reference mappings
│
├── environment-variables/
│   └── environment-variables.json   # All env var values per environment
│
└── docs/
    ├── alm-concepts-explained.md    # Theory: what/why/how
    ├── pac-cli-reference.md         # PAC CLI command reference
    ├── setup-guide.md               # First-time environment setup
    └── troubleshooting.md           # Common ALM failures and fixes
```

---

## Solutions Index

| Solution | Publisher Prefix | Components | Purpose |
|----------|-----------------|------------|---------|
| `HalyseAccountGovernance` | `halyse` | Plugin + JS + Form | Account business rules |
| `HalyseOpportunityRevenue` | `halyse` | Plugin + JS | Revenue intelligence |
| `HalyseCaseEscalation` | `halyse` | Plugin + JS + SLA | Case management |
| `HalysePCFControls` | `halyse` | 5 PCF controls | UI component library |
| `HalyseSharedConfig` | `halyse` | Publisher + shared tables | Foundation layer |

---

## Quick Start

```bash
# 1. Install PAC CLI
npm install -g @microsoft/power-platform-cli

# 2. Authenticate to an environment
pac auth create --name dev --url https://yourorg-dev.crm.dynamics.com

# 3. Export a solution (unmanaged, for source control)
pac solution export \
  --name HalyseAccountGovernance \
  --path ./exported/HalyseAccountGovernance.zip \
  --managed false

# 4. Unpack for source control (human-readable XML)
pac solution unpack \
  --zipfile ./exported/HalyseAccountGovernance.zip \
  --folder ./solution-components/account-governance \
  --processCanvasApps false

# 5. Pack for deployment
pac solution pack \
  --zipfile ./artifacts/HalyseAccountGovernance_managed.zip \
  --folder ./solution-components/account-governance \
  --managed true

# 6. Import to target environment
pac solution import \
  --path ./artifacts/HalyseAccountGovernance_managed.zip \
  --environment https://yourorg-test.crm.dynamics.com \
  --activate-plugins true
```

---

## The Full CI/CD Flow

```
Developer pushes code
        │
        ▼
GitHub Actions: export-solution.yml
  - pac solution export (from DEV)
  - pac solution unpack (to XML source)
  - git commit & push
        │
        ▼
PR opened → CI validates
  - pac solution pack (rebuild)
  - pac solution check (best-practice analysis)
        │
        ▼
PR merged to main
  - pac solution pack --managed
  - pac solution import → TEST environment
  - Run automated tests
        │
        ▼
Release tag created (v1.2.0)
  - pac solution import → PROD environment
  - Notify team via Teams/email
```
