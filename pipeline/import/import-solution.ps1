#!/usr/bin/env pwsh
# =============================================================================
# PIPELINE: Pack + Import Solutions to Target Environment
# =============================================================================
# Organization:  Halyse Technologies
# Author:        Mohammed Anees (Senior D365 Architect)
# Version:       1.0.0
#
# PURPOSE:
#   Packs source XML files into managed solution zips, then imports them
#   to the target environment (TEST or PROD) in the correct dependency order.
#   Supports both Update (fast) and Upgrade (safe, 2-phase) strategies.
#
# USAGE:
#   ./import-solution.ps1 -TargetUrl "https://yourorg-test.crm.dynamics.com"
#   ./import-solution.ps1 -TargetUrl "..." -Strategy Upgrade  # 2-phase safe upgrade
#
# CI/CD USAGE:
#   ./import-solution.ps1 `
#     -TargetUrl $env:PP_TEST_URL `
#     -TenantId $env:PP_TENANT_ID `
#     -AppId $env:PP_APP_ID `
#     -ClientSecret $env:PP_CLIENT_SECRET `
#     -ConnectionRefsFile "./connection-references/test-mappings.json"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetUrl,

    [ValidateSet("Update","Upgrade")]
    [string]$Strategy = "Update",            # Update=fast, Upgrade=safe 2-phase

    [string]$SolutionName = "",              # Empty = deploy all solutions

    [string]$TenantId     = "",
    [string]$AppId        = "",
    [string]$ClientSecret = "",

    [string]$SourceDir            = "../../solution-components",
    [string]$ArtifactsDir         = "../../artifacts",
    [string]$ConnectionRefsFile   = "",      # Optional connection ref mapping
    [switch]$ActivatePlugins      = $true,
    [switch]$PublishChanges       = $true,
    [switch]$DryRun               = $false   # Pack only, skip import
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

# ── Solution Import Order (dependencies matter!) ──────────────────────────────
# RULE: Always import base/shared solutions before dependent solutions.
# HalyseSharedConfig must come first — it defines the publisher and shared tables.

$solutions = @(
    @{ Name = "HalyseSharedConfig";         Folder = "shared-config"       },
    @{ Name = "HalyseAccountGovernance";    Folder = "account-governance"  },
    @{ Name = "HalyseOpportunityRevenue";   Folder = "opportunity-revenue" },
    @{ Name = "HalyseCaseEscalation";       Folder = "case-escalation"     },
    @{ Name = "HalysePCFControls";          Folder = "pcf-controls"        }
)

if ($SolutionName) {
    $solutions = $solutions | Where-Object { $_.Name -eq $SolutionName }
}

# ── Authentication ────────────────────────────────────────────────────────────

Write-Step "Authenticating to target environment: $TargetUrl"

if ($TenantId -and $AppId -and $ClientSecret) {
    pac auth create `
        --name "import-sp" `
        --url $TargetUrl `
        --tenant $TenantId `
        --applicationId $AppId `
        --clientSecret $ClientSecret 2>&1 | Out-Null
} else {
    pac auth create --name "import-interactive" --url $TargetUrl 2>&1 | Out-Null
}

$orgInfo = pac org who 2>&1
Write-OK "Connected: $orgInfo"

New-Item -ItemType Directory -Path $ArtifactsDir -Force | Out-Null

# ── Pack + Import Loop ────────────────────────────────────────────────────────

foreach ($sol in $solutions) {
    $name    = $sol.Name
    $folder  = $sol.Folder
    $srcPath = "$SourceDir/$folder"
    $zipPath = "$ArtifactsDir/${name}_managed.zip"

    # ── PACK ──────────────────────────────────────────────────────────────────

    Write-Step "Packing $name (managed)"

    if (-not (Test-Path $srcPath)) {
        Write-Warn "Source folder not found: $srcPath — skipping $name"
        continue
    }

    pac solution pack `
        --zipfile $zipPath `
        --folder $srcPath `
        --managed true 2>&1

    $sizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
    Write-OK "Packed: $zipPath ($sizeKB KB)"

    if ($DryRun) {
        Write-Warn "DryRun mode — skipping import of $name"
        continue
    }

    # ── IMPORT ────────────────────────────────────────────────────────────────

    Write-Step "Importing $name to target ($Strategy strategy)"

    $importArgs = @(
        "--path", $zipPath,
        "--activate-plugins", $ActivatePlugins.ToString().ToLower(),
        "--force-overwrite", "true"
    )

    if ($ConnectionRefsFile -and (Test-Path $ConnectionRefsFile)) {
        $importArgs += "--connection-references", $ConnectionRefsFile
        Write-OK "Using connection references: $ConnectionRefsFile"
    }

    if ($Strategy -eq "Upgrade") {
        # 2-phase: stage first, then apply
        Write-OK "Staging solution (holding import)..."
        pac solution import @importArgs --import-as-holding true 2>&1

        Write-OK "Applying upgrade (removing old layer)..."
        pac solution upgrade --solution-name $name 2>&1
    } else {
        # Direct update
        pac solution import @importArgs 2>&1
    }

    Write-OK "$name imported successfully"
}

# ── Publish ───────────────────────────────────────────────────────────────────

if ($PublishChanges -and -not $DryRun) {
    Write-Step "Publishing all customizations"
    pac org publish 2>&1
    Write-OK "Published"
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
Write-Host "   Target:   $TargetUrl" -ForegroundColor White
Write-Host "   Strategy: $Strategy" -ForegroundColor White
Write-Host "   Solutions: $($solutions.Count)" -ForegroundColor White

if ($DryRun) {
    Write-Host "`n⚠ DRY RUN — no solutions were actually imported" -ForegroundColor Yellow
    Write-Host "   Artifacts available in: $ArtifactsDir" -ForegroundColor White
}
