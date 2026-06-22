#!/usr/bin/env pwsh
# =============================================================================
# PIPELINE: Solution Checker — Best Practice Analysis
# =============================================================================
# Organization:  Halyse Technologies
# Author:        Mohammed Anees (Senior D365 Architect)
# Version:       1.0.0
#
# PURPOSE:
#   Runs Microsoft's Solution Checker against all packed solution zips.
#   Fails the build (exit 1) if any Critical or High severity issues are found.
#   Used in PR validation pipeline — no Critical issues may reach main branch.
#
# WHAT SOLUTION CHECKER CATCHES:
#   - Deprecated API usage (Xrm.Page, etc.)
#   - Plugin performance anti-patterns
#   - Security role misconfigurations
#   - Unsupported customizations
#   - Missing async patterns
#
# USAGE:
#   ./validate-solution.ps1
#   ./validate-solution.ps1 -FailOn High   # Fail on High OR Critical
#   ./validate-solution.ps1 -FailOn Medium # Fail on Medium, High, or Critical
# =============================================================================

param(
    [ValidateSet("Critical","High","Medium","Low")]
    [string]$FailOn = "High",            # Fail build at this severity or above

    [string]$ArtifactsDir = "../../artifacts",
    [string]$ReportDir    = "../../checker-results",
    [string]$Geo          = "UnitedStates"   # UnitedStates, Europe, Asia, etc.
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

# Severity order (higher index = more severe)
$severityOrder = @("Low", "Medium", "High", "Critical")
$failIdx = $severityOrder.IndexOf($FailOn)

New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null

$zips = Get-ChildItem -Path $ArtifactsDir -Filter "*_managed.zip" -ErrorAction SilentlyContinue
if (-not $zips) {
    Write-Warn "No managed solution zips found in $ArtifactsDir"
    Write-Warn "Run import-solution.ps1 -DryRun first to build artifacts"
    exit 0
}

$totalIssues    = 0
$blockingIssues = 0

foreach ($zip in $zips) {
    $name       = $zip.BaseName -replace "_managed", ""
    $reportPath = "$ReportDir/$name"

    Write-Step "Checking: $($zip.Name)"

    pac solution check `
        --path $zip.FullName `
        --outputDirectory $reportPath `
        --geo $Geo 2>&1

    # Parse the JSON results
    $jsonFiles = Get-ChildItem -Path $reportPath -Filter "*.sarif" -Recurse -ErrorAction SilentlyContinue
    if (-not $jsonFiles) {
        Write-OK "No issues found (or no SARIF output generated)"
        continue
    }

    foreach ($jsonFile in $jsonFiles) {
        $sarif = Get-Content $jsonFile.FullName | ConvertFrom-Json
        $runs  = $sarif.runs

        foreach ($run in $runs) {
            $results = $run.results
            if (-not $results) { continue }

            # Group by severity
            $bySeverity = $results | Group-Object { $_.level }

            foreach ($group in $bySeverity) {
                $level    = switch ($group.Name) {
                    "error"   { "Critical" }
                    "warning" { "High" }
                    "note"    { "Medium" }
                    default   { "Low" }
                }
                $count    = $group.Count
                $totalIssues += $count

                $levelIdx = $severityOrder.IndexOf($level)
                if ($levelIdx -ge $failIdx) {
                    $blockingIssues += $count
                    Write-Fail "$level: $count issue(s)"
                    # Print each issue
                    foreach ($result in $group.Group) {
                        $msg = $result.message.text
                        $loc = if ($result.locations) {
                            $result.locations[0].physicalLocation.artifactLocation.uri
                        } else { "unknown" }
                        Write-Host "    → [$level] $msg" -ForegroundColor Red
                        Write-Host "      Location: $loc" -ForegroundColor DarkGray
                    }
                } else {
                    Write-Warn "$level: $count issue(s) (not blocking at FailOn=$FailOn)"
                }
            }
        }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host "`n── Validation Summary ──────────────────────────────────" -ForegroundColor White
Write-Host "   Total issues found:   $totalIssues" -ForegroundColor White
Write-Host "   Blocking issues:      $blockingIssues (FailOn=$FailOn or above)" -ForegroundColor White
Write-Host "   Reports saved to:     $ReportDir" -ForegroundColor White

if ($blockingIssues -gt 0) {
    Write-Host "`n✗ BUILD FAILED — $blockingIssues blocking issue(s) found" -ForegroundColor Red
    Write-Host "  Fix all $FailOn+ severity issues before merging" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ Validation passed — no blocking issues" -ForegroundColor Green
    exit 0
}
