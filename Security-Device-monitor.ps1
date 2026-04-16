# =====================================================
# SECURITY DEVICE MONITOR - ENTRY POINT
# =====================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve project root (this file location)
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Build path to Main.ps1
$MainScriptPath = Join-Path $ScriptRoot "src\Main.ps1"

# Validate Main.ps1 exists
if (-not (Test-Path -Path $MainScriptPath)) {
    Write-Error "Main script not found at: $MainScriptPath"
    exit 1
}

Write-Host ""
Write-Host "==============================================="
Write-Host "   Security Device Monitor - Public Demo"
Write-Host "==============================================="
Write-Host ""

Write-Host "Launching pipeline..." -ForegroundColor Cyan
Write-Host ""

try {
    & $MainScriptPath

    Write-Host ""
    Write-Host "Execution completed successfully" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "Execution failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}