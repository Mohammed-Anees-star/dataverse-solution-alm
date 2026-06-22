#!/usr/bin/env pwsh
# =============================================================================
# PIPELINE: Export Solutions from DEV Environment
# =============================================================================
# Organization:  Halyse Technologies
# Author:        Mohammed Anees (Senior D365 Architect)
# Version:       1.0.0
#
# PURPOSE:
#   Exports all Halyse solutions from the DEV environment, unpacks them into
#   source-controllable XML files, and stages them for git commit.
#   Run this after making changes in DEV to capture the delta.
#
# USAGE:
#   ./export-solution.ps1 -DevUrl "https://yourorg-dev.crm.dynamics.com"
#   ./export-solution.ps1 -SolutionName "HalyseAccountGovernance"  # Single solution
#
# CI/CD USAGE (service principal):
#   ./export-solution.ps1 `
#     -DevUrl $env:PP_DEV_URL `
#     -TenantId $env:PP_TENANT_ID `
#     -AppId $env:PP_APP_ID `
#     -ClientSecret $env:PP_CLIENT_SECRET
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$DevUrl,

    [string]$SolutionName = "",            # Empty = export all Halyse solutions

    [string]$TenantId     = "",            # For service principal auth
    [string]$AppId        = "",            # For service principal auth
    [string]$ClientSecret = "",            # For service principal auth

    [string]$OutputDir    = "../../exported",
    [string]$SourceDir    = "../../solution-components",
    [switch]$CommitChanges = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Step { param($msg) Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

# ── Authentication ────────────────────────────────────────────────────────────

Write-Step "Authenticating to DEV environment"

if ($TenantId -and $AppId -and $ClientSecret) {
    Write-OK "Using service principal (CI/CD mode)"
    pac auth create `
        --name "export-sp" `
        --url $DevUrl `
        --tenant $TenantId `
        --applicationId $AppId `
        --clientSecret $ClientSecret 2>&1 | Out-Null
} else {
    Write-OK "Using interactive auth (developer mode)"
    pac auth create --name "export-dev" --url $DevUrl 2>&1 | Out-Null
}

# Verify connection
$orgInfo = pac org who 2>&1
Write-OK "Connected to: $orgInfo"

# ── Solution List ─────────────────────────────────────────────────────────────

# Define all Halyse solutions and their source folders
$solutions = @(
    @{ Name = "HalyseSharedConfig";         Folder = "shared-config"       },
    @{ Name = "HalyseAccountGovernance";    Folder = "account-governance"  },
    @{ Name = "HalyseOpportunityRevenue";   Folder = "opportunity-revenue" },
    @{ Name = "HalyseCaseEscalation";       Folder = "case-escalation"     },
    @{ Name = "HalysePCFControls";          Folder = "pcf-controls"        }
)

# If a specific solution was requested, filter to that one
if ($SolutionName) {
    $solutions = $solutions | Where-Object { $_.Name -eq $SolutionName }
    if (-not $solutions) {
        Write-Fail "Unknown solution: $SolutionName"
        exit 1
    }
}

# ── Export + Unpack Loop ─────────────────────────────────────────────────────

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$changed = @()

foreach ($sol in $solutions) {
    $name   = $sol.Name
    $folder = $sol.Folder
    $zipPath= "$OutputDir/$name.zip"
    $srcPath= "$SourceDir/$folder"

    Write-Step "Exporting $name"

    # Export unmanaged (for source control)
    try {
        pac solution export `
            --name $name `
            --path $zipPath `
            --managed false `
            --overwrite true 2>&1

        Write-OK "Exported → $zipPath"
    } catch {
        Write-Warn "Skipping $name — not found in environment (may not be installed yet)"
        continue
    }

    # Unpack to XML source files
    Write-Step "Unpacking $name → $srcPath"
    New-Item -ItemType Directory -Path $srcPath -Force | Out-Null

    pac solution unpack `
        --zipfile $zipPath `
        --folder $srcPath `
        --allowDelete true `
        --processCanvasApps false 2>&1

    Write-OK "Unpacked to: $srcPath"
    $changed += $srcPath
}

# ── Git Commit (optional) ────────────────────────────────────────────────────

if ($CommitChanges -and $changed.Count -gt 0) {
    Write-Step "Committing changes to git"

    Push-Location "../../"
    try {
        git add ($changed | ForEach-Object { $_ -replace "^../../", "./" })
        $status = git status --short
        if ($status) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
            git commit -m "chore: Export solutions from DEV [$timestamp] [skip ci]"
            Write-OK "Committed changes"
        } else {
            Write-OK "No changes to commit"
        }
    } finally {
        Pop-Location
    }
}

Write-Host "`n✅ Export complete!" -ForegroundColor Green
Write-Host "   Solutions exported: $($changed.Count)" -ForegroundColor White
Write-Host "   Review changes with: git diff $SourceDir" -ForegroundColor White
