# =====================================================
# SECURITY DEVICE MONITOR - ENTRY POINT
# =====================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------
# RESOLVE PROJECT ROOT
# ---------------------------

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------------------------
# MAIN SCRIPT PATH
# ---------------------------

$MainScriptPath = Join-Path $ScriptRoot "src\Main.ps1"

# ---------------------------
# VALIDATION
# ---------------------------

if (-not (Test-Path -Path $MainScriptPath)) {
    Write-Host ""
    Write-Host "ERROR: Main script not found at:" -ForegroundColor Red
    Write-Host $MainScriptPath -ForegroundColor Red
    Write-Host ""
    exit 1
}

# ---------------------------
# BANNER
# ---------------------------

Write-Host ""
Write-Host "==============================================="
Write-Host "   Security Device Monitor - Public Demo"
Write-Host "==============================================="
Write-Host ""

Write-Host "Launching pipeline..." -ForegroundColor Cyan
Write-Host ""

# ---------------------------
# EXECUTION
# ---------------------------

try {
    & $MainScriptPath

    Write-Host ""
    Write-Host "Execution completed successfully" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "Execution failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    exit 1
}