<div align="center">
<h1>Enterprise Dataverse Solution ALM Pipelines</h1>
<strong>Automated Application Lifecycle Management for Microsoft Dataverse using PAC CLI, GitHub Actions, and environment-governed configurations.</strong>
<p>
<a href="https://github.com/Mohammed-Anees-star/dataverse-solution-alm"><img src="https://img.shields.io/github/license/Mohammed-Anees-star/dataverse-solution-alm?color=blue" alt="License"></a>
<a href="https://github.com/Mohammed-Anees-star/dataverse-solution-alm"><img src="https://img.shields.io/github/last-commit/Mohammed-Anees-star/dataverse-solution-alm?logo=github" alt="Last Commit"></a>
<a href="https://github.com/Mohammed-Anees-star/dataverse-solution-alm"><img src="https://img.shields.io/github/repo-size/Mohammed-Anees-star/dataverse-solution-alm?color=informational" alt="Repo Size"></a>
<a href="https://github.com/Mohammed-Anees-star/dataverse-solution-alm"><img src="https://img.shields.io/github/languages/top/Mohammed-Anees-star/dataverse-solution-alm?color=yellow" alt="Primary Language"></a>
<a href="https://github.com/Mohammed-Anees-star/dataverse-solution-alm"><img src="https://img.shields.io/github/stars/Mohammed-Anees-star/dataverse-solution-alm?style=social" alt="Stars"></a>
</p>
</div>

## 🎯 Overview
Halyse Technologies operates a fully automated ALM pipeline for Microsoft Dataverse solutions encompassing plugins, PCF controls, flows, and configuration assets. This repository captures the source-controlled solution artifacts, PAC CLI automation scripts, environment variable governance, and GitHub Actions pipelines that move managed solutions from DEV to TEST to PROD with audit-grade traceability. Designed for CIOs, CTOs, and platform engineering leads, it demonstrates best-in-class Power Platform ALM practices aligned to publisher prefix `halyse` and namespace `Halyse.Dataverse.*`.

## 📦 Solutions Table
| # | Solution | Description | Key Tech | Path |
|---|----------|-------------|----------|------|
| 1 | HalyseSharedConfig | Base publisher, shared tables, environment scaffolding | PAC CLI pack/unpack, managed layering | `solution-components/shared-config` |
| 2 | HalyseAccountGovernance | Account governance plugins, scripts, forms | PluginBase architecture, Managed pipeline deployment | `solution-components/account-governance` |
| 3 | HalyseOpportunityRevenue | Opportunity revenue intelligence assets | Plugin + JS bundling, solution checker compliance | `solution-components/opportunity-revenue` |
| 4 | HalyseCaseEscalation | SLA and escalation assets | Multi-solution dependencies, upgrade strategy | `solution-components/case-escalation` |
| 5 | HalysePCFControls | PCF control bundle | PCF packaging, resource dependency mapping | `solution-components/pcf-controls` |

## 🏗️ Architecture
```mermaid
flowchart TB
    subgraph DevOps[GitHub Actions]
        ExportWorkflow[export-solution.yml]
        DeployTestWorkflow[deploy-test.yml]
        DeployProdWorkflow[deploy-prod.yml]
    end

    subgraph Scripts[PAC CLI Scripts]
        ExportPS1[export-solution.ps1]
        ValidatePS1[validate-solution.ps1]
        ImportPS1[import-solution.ps1]
    end

    subgraph Environments[Power Platform Environments]
        Dev[DEV (Unmanaged)]
        Test[TEST (Managed)]
        Prod[PROD (Managed)]
    end

    ExportWorkflow --> ExportPS1 --> Dev
    DeployTestWorkflow --> ValidatePS1 --> ImportPS1 --> Test
    DeployProdWorkflow --> ImportPS1 --> Prod

    Scripts --> EnvironmentVariables[Environment Variables]
    Scripts --> ConnectionRefs[Connection References]
    Dev -->|Solution Export| SolutionArtifacts[(Managed Artifacts)]
    SolutionArtifacts -->|Import| Test
    SolutionArtifacts -->|Import| Prod
```

## 🚀 Tech Stack
![Power Platform CLI](https://img.shields.io/badge/PAC%20CLI-742774?logo=powerapps&logoColor=white) ![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=github-actions&logoColor=white) ![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white) ![Azure Key Vault](https://img.shields.io/badge/Azure%20Key%20Vault-326CE5?logo=microsoft-azure&logoColor=white) ![Dataverse](https://img.shields.io/badge/Microsoft%20Dataverse-0078D4?logo=microsoft&logoColor=white) ![Application Insights](https://img.shields.io/badge/Application%20Insights-7200CA?logo=azuredevops&logoColor=white) ![YAML](https://img.shields.io/badge/YAML-000000?logo=yaml&logoColor=white)

## 🗂️ Project Structure
```text
.
├── README.md
├── solution-components/
│   ├── shared-config/
│   ├── account-governance/
│   ├── opportunity-revenue/
│   ├── case-escalation/
│   └── pcf-controls/
├── pipeline/
│   ├── export/export-solution.ps1
│   ├── validate/validate-solution.ps1
│   └── import/import-solution.ps1
├── environments/
│   ├── dev/env.json
│   ├── test/env.json
│   └── prod/env.json
├── connection-references/
│   ├── test-mappings.json
│   └── prod-mappings.json
├── environment-variables/environment-variables.json
└── docs/
    ├── alm-concepts-explained.md
    ├── pac-cli-reference.md
    ├── setup-guide.md
    └── troubleshooting.md
```

## 🛠️ Getting Started
### Prerequisites
- Power Platform CLI (`@microsoft/power-platform-cli`) installed and authenticated via service principal or interactive login.
- GitHub Actions runners with secure access to Azure Key Vault / GitHub secrets storing service principal credentials.
- DEV, TEST, PROD Dataverse environments aligned to the three-stage ALM model and seeded with `halyse` publisher.
- Connection references and environment variables defined in target environments to bind solution connectors post-import.

### Deployment Steps
1. Export unmanaged solutions from DEV for source control.
   ```bash
   cd pipeline/export
   ./export-solution.ps1 -DevUrl https://yourorg-dev.crm.dynamics.com -CommitChanges
   ```
2. Validate solution quality and best practices using the Solution Checker script.
   ```bash
   cd pipeline/validate
   ./validate-solution.ps1 -SolutionName HalyseAccountGovernance -Output "../../reports"
   ```
3. Pack managed artifacts and import to TEST using the upgrade or update strategy.
   ```bash
   cd pipeline/import
   ./import-solution.ps1 \
     -TargetUrl https://yourorg-test.crm.dynamics.com \
     -Strategy Upgrade \
     -ConnectionRefsFile ../../connection-references/test-mappings.json
   ```
4. After validation, publish to PROD by tagging a release or invoking the production workflow.
   ```bash
   gh workflow run deploy-prod.yml -f version=v1.2.0
   ```
5. Monitor deployment outcomes via GitHub Actions logs and Application Insights telemetry emitted by plugin instrumentation.

## ⚡ Key Patterns Demonstrated
- **Three-Stage Environment Model:** DEV unmanaged, TEST managed, PROD managed with solution layering, enabling clean rollback and consistent ALM.
- **PAC CLI Automation:** PowerShell scripts drive pack/export/import operations with dependency-aware ordering and optional upgrade strategy for major releases.
- **Connection Reference Governance:** JSON mapping files ensure flows bind to the correct connections in TEST/PROD without manual edits.
- **Environment Variable Configuration:** `environment-variables/environment-variables.json` centralizes configuration values across environments for repeatable deployments.
- **GitHub Actions Integration:** Workflows automate exports, quality checks, and deployments triggered by PR merges and release tags.
- **Solution Checker Enforcement:** `validate-solution.ps1` integrates the Microsoft Solution Checker for compliance before promotion.
- **Upgrade vs Update Strategies:** Supports both fast updates and safe staged upgrades with holding imports and `pac solution upgrade` calls.
- **Telemetry Hooks:** Plugins and flows incorporate Application Insights instrumentation, surfacing deployment impact across environments.
- **Rollback-Friendly Artifacts:** Managed solution ZIPs stored under `artifacts/` allow re-importing previous versions for rapid remediation.
- **Documentation-Driven ALM:** Detailed docs provide onboarding, troubleshooting, and conceptual guidance for platform engineers.

## 🔍 Solution Portfolio Deep Dive
### HalyseSharedConfig
- **Contents:** Publisher definition, shared tables, environment variable definitions, solution settings baseline.
- **Why it matters:** Establishes foundational components every downstream solution depends on; imported first in all pipelines.
- **Script reference:** Included as the first entry in `$solutions` arrays within `export-solution.ps1` and `import-solution.ps1`.

### HalyseAccountGovernance
- **Contents:** Plugins, JavaScript web resources, forms aligning account governance features.
- **ALM notes:** Packaged as managed, imported after SharedConfig to satisfy dependency on shared tables.
- **Telemetry:** Plugin instrumentation logs to Application Insights, traceable across environments.

### HalyseOpportunityRevenue
- **Contents:** Revenue intelligence plugin, supporting JS, option sets.
- **ALM notes:** Validated via solution checker for performance and security prior to deployment.

### HalyseCaseEscalation
- **Contents:** SLA configurations, plugins, flows for escalation triggers.
- **ALM notes:** Utilizes upgrade strategy for schema changes touching SLA KPIs to ensure clean transitions.

### HalysePCFControls
- **Contents:** PCF control manifests, resources, dataset bindings.
- **ALM notes:** Deployed after core solutions; scripts support `--processCanvasApps false` to keep packing lean.

## 🤝 About Halyse Technologies
Halyse Technologies specializes in enterprise Dataverse engineering, delivering end-to-end ALM pipelines, telemetry-driven operations, and regulatory-compliant deployments. Led by Mohammed Anees (friendanees3@gmail.com), we empower CIO offices with automated guardrails and auditable release practices.

## 🛡️ License
This repository is licensed under the MIT License. See the `LICENSE` file for full usage rights and attribution requirements.
