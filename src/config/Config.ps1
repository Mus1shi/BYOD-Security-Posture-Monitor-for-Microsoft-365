# =====================================================
# GLOBAL CONFIGURATION - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Central configuration file for the public demo edition
# of the Device Security Posture Monitor project.
#
# This version is designed to run with:
# - fake / sample data
# - local demo paths
# - no production credentials
# - mail disabled by default
#
# Important:
# Do not store any real secret, tenant ID, internal email,
# or infrastructure detail in this file.
# =====================================================

# =====================================================
# GENERAL EXECUTION MODE
# =====================================================

$DemoMode = $true
$EnableGraphCollection = $false
$EnableTrendApiCollection = $false
$EnableMail = $false
$EnableDefender = $false

# =====================================================
# OPTIONAL LOCAL SECRET LOADER
# =====================================================
# In the public version, secret loading is optional.
# The script can run in demo mode without any real secret.
# If you later want to test API collection locally,
# you can use environment variables or your own local setup.
# =====================================================

$LoadSecretsHelper = Join-Path $PSScriptRoot "Load-Secrets.ps1"

if (Test-Path $LoadSecretsHelper) {
    . $LoadSecretsHelper
}

# =====================================================
# PUBLIC PLACEHOLDER CREDENTIALS
# =====================================================
# Demo mode does not require real values.
# These placeholders are intentionally non-functional.
# =====================================================

$TenantId = $env:GRAPH_TENANT_ID
$ClientId = $env:GRAPH_CLIENT_ID
$ClientSecret = $env:GRAPH_CLIENT_SECRET

$TrendApiKey = $env:TREND_API_KEY

$DefenderTenantId = $env:DEFENDER_TENANT_ID
$DefenderClientId = $env:DEFENDER_CLIENT_ID
$DefenderClientSecret = $env:DEFENDER_CLIENT_SECRET

# =====================================================
# TREND CACHE SETTINGS
# =====================================================

$TrendCacheMaxAgeHours = 12

# =====================================================
# MAIL SETTINGS - PUBLIC DEMO
# =====================================================
# Mail is disabled by default in the public version.
# These values are placeholders only.
# =====================================================

$EmailRecipient = "demo-recipient@example.com"
$EmailSender    = "demo-monitor@example.com"
$SmtpServer     = "smtp.example.com"
$SmtpPort       = 25

# =====================================================
# PROJECT PATH INITIALIZATION
# =====================================================
# Build project-relative paths used by the demo version.
# =====================================================

$ScriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcRoot     = Split-Path -Parent $ScriptRoot
$ProjectRoot = Split-Path -Parent $SrcRoot

$DataPath          = Join-Path $ProjectRoot "data"
$RawDataPath       = Join-Path $DataPath "raw"
$ProcessedDataPath = Join-Path $DataPath "processed"
$ReportsPath       = Join-Path $DataPath "reports"
$SampleDataPath    = Join-Path $DataPath "sample"
$InfraFilesPath    = Join-Path $DataPath "infra_files"

foreach ($folder in @(
    $DataPath,
    $RawDataPath,
    $ProcessedDataPath,
    $ReportsPath,
    $SampleDataPath,
    $InfraFilesPath
)) {
    if (-not (Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }
}

# =====================================================
# DEMO INPUT FILES
# =====================================================
# These sample files are used by the public demo version.
# Adjust names if your sample dataset filenames differ.
# =====================================================

$SampleTrendFile  = Join-Path $SampleDataPath "sample_trend_workstations.json"
$SampleEntraFile  = Join-Path $SampleDataPath "sample_entra_devices.json"
$SampleIntuneFile = Join-Path $SampleDataPath "sample_intune_devices.json"

# =====================================================
# EXECUTION VALIDATION
# =====================================================
# In demo mode:
# - no secret is mandatory
# - no live API dependency should block execution
#
# In live mode:
# - required credentials must be provided explicitly
# =====================================================

if (-not $DemoMode) {
    if ($EnableGraphCollection -and (-not $TenantId -or -not $ClientId -or -not $ClientSecret)) {
        throw "Graph collection is enabled, but Graph credentials are missing."
    }

    if ($EnableTrendApiCollection -and -not $TrendApiKey) {
        throw "Trend API collection is enabled, but TREND_API_KEY is missing."
    }

    if ($EnableDefender -and (-not $DefenderTenantId -or -not $DefenderClientId -or -not $DefenderClientSecret)) {
        throw "Defender collection is enabled, but Defender credentials are missing."
    }

    if ($EnableMail) {
        if (-not $EmailRecipient -or -not $EmailSender -or -not $SmtpServer -or -not $SmtpPort) {
            throw "Mail is enabled, but one or more SMTP settings are missing."
        }
    }
}

# =====================================================
# GLOBAL POWERSHELL BEHAVIOR
# =====================================================

$ErrorActionPreference = "Stop"

# =====================================================
# EXECUTION BANNER
# =====================================================

Write-Host "[OK] Public demo configuration loaded" -ForegroundColor Green
Write-Host "[INFO] Demo mode: $DemoMode" -ForegroundColor White
Write-Host "[INFO] Graph collection enabled: $EnableGraphCollection" -ForegroundColor White
Write-Host "[INFO] Trend API collection enabled: $EnableTrendApiCollection" -ForegroundColor White
Write-Host "[INFO] Defender enabled: $EnableDefender" -ForegroundColor White
Write-Host "[INFO] Mail enabled: $EnableMail" -ForegroundColor White