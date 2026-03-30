# =====================================================
# PROJECT CONFIGURATION
# =====================================================
# Purpose:
# Central configuration file for the BYOD Device Monitor.
#
# Public GitHub version:
# - Safe by default
# - Demo mode enabled by default
# - No real secrets stored here
# - Uses local fake sample datasets
#
# Available modes:
# - Demo : uses fake sample files stored in /data
# - Live : uses real Microsoft Graph / Trend / SMTP settings
#
# Important:
# This public file must never contain production secrets.
# Real internal values should stay in a private, ignored file.
# =====================================================

# =====================================================
# EXECUTION MODE
# =====================================================
# Demo:
#   Safe public mode for GitHub and portfolio usage.
#   No real API calls should be required.
#
# Live:
#   Internal/private mode using real services.
# =====================================================

$Mode = "Demo"

# =====================================================
# OPTIONAL FEATURES
# =====================================================
# Enable or disable optional project features.
#
# EnableMail:
# - false = safe default for GitHub demo
# - true  = allows SMTP email sending if properly configured
# =====================================================

$EnableMail = $false

# =====================================================
# PROJECT ROOT
# =====================================================
# $PSScriptRoot here points to:
#   <repo>\src\config
#
# We go up two levels to reach the repository root.
# =====================================================

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# =====================================================
# FOLDER STRUCTURE
# =====================================================
# Centralize all important project folders.
# This makes the project easier to move and clone.
# =====================================================

$DataPath = Join-Path $ProjectRoot "data"

$RawDataPath = Join-Path $DataPath "raw"
$ProcessedDataPath = Join-Path $DataPath "processed"
$ReportsPath = Join-Path $DataPath "reports"

# =====================================================
# SAMPLE DATASET PATHS (DEMO MODE)
# =====================================================
# These files are fake datasets used for the public demo.
# They should contain realistic but non-sensitive values.
# =====================================================

$SampleTrendPath = Join-Path $RawDataPath "sample_trend_endpoints.json"
$SampleIntunePath = Join-Path $ProcessedDataPath "sample_intune_devices.csv"
$SampleEntraPath = Join-Path $ReportsPath "sample_entra_devices.json"

# =====================================================
# TREND CACHE SETTINGS
# =====================================================
# In Live mode, if a recent Trend workstation file already
# exists, the script can reuse it instead of collecting again.
#
# In Demo mode, this setting has no real impact.
# =====================================================

$TrendCacheMaxAgeHours = 4

# =====================================================
# MICROSOFT GRAPH SETTINGS (LIVE MODE ONLY)
# =====================================================
# These values must remain empty in the public GitHub version.
#
# Private/internal usage:
# - Load them securely from environment variables
# - Or load them from a private local file excluded by .gitignore
#
# Never commit real tenant IDs, client IDs, or client secrets.
# =====================================================

$TenantId = ""
$ClientId = ""
$ClientSecret = ""

# =====================================================
# TREND API SETTINGS (LIVE MODE ONLY)
# =====================================================
# The Trend API key should never be stored here in the
# public repository.
#
# The collection script should read it from:
#   $env:TREND_API_KEY
# =====================================================

# No direct Trend API key is stored in this public config.

# =====================================================
# SMTP / EMAIL SETTINGS (LIVE MODE ONLY)
# =====================================================
# Safe public defaults:
# - empty sender
# - empty recipient
# - empty SMTP server
#
# This prevents accidental mail sending in the demo version.
# =====================================================

$EmailRecipient = ""
$EmailSender = ""
$SmtpServer = ""
$SmtpPort = 25

# =====================================================
# OPTIONAL DEMO LABELS / METADATA
# =====================================================
# These optional values help make logs and future README
# explanations clearer.
# =====================================================

$ProjectName = "BYOD Device Monitor"
$ProjectVersion = "1.0-demo-public"

# =====================================================
# DIRECTORY INITIALIZATION
# =====================================================
# Ensure project data folders exist before the main script
# starts working with files.
#
# This improves first-run experience after cloning the repo.
# =====================================================

foreach ($folder in @($DataPath, $RawDataPath, $ProcessedDataPath, $ReportsPath)) {
    if (-not (Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }
}

# =====================================================
# EXECUTION BANNER
# =====================================================
# Optional console feedback to make startup clearer.
# =====================================================

Write-Host "[CONFIG] Project loaded: $ProjectName" -ForegroundColor Cyan
Write-Host "[CONFIG] Version: $ProjectVersion" -ForegroundColor Cyan
Write-Host "[CONFIG] Mode: $Mode" -ForegroundColor Cyan
Write-Host "[CONFIG] Mail enabled: $EnableMail" -ForegroundColor Cyan
Write-Host "[CONFIG] Project root: $ProjectRoot" -ForegroundColor DarkGray