# =====================================================
# CONFIGURATION - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

# ---------------------------
# PROJECT PATHS
# ---------------------------

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot

$DataRoot       = Join-Path $ProjectRoot "data"
$RawDataPath    = Join-Path $DataRoot "raw"
$ProcessedPath  = Join-Path $DataRoot "processed"
$ReportsPath    = Join-Path $DataRoot "reports"
$SampleDataPath = Join-Path $DataRoot "sample"

# Frontend export (React will consume this)
$FrontendDataPath = Join-Path $ReportsPath "frontend"

# ---------------------------
# EXECUTION MODES
# ---------------------------

# Public demo mode (SAFE)
$DemoMode = $true

# Live collection flags (disabled in public repo)
$EnableGraphCollection    = $false
$EnableTrendCollection    = $false
$EnableDefenderLive       = $false

# Demo data usage
$EnableDemoData           = $true
$EnableDefenderDemo       = $true

# Output options
$EnableMail               = $false
$EnableFrontendExport     = $true

# ---------------------------
# SAMPLE DATA FILES
# ---------------------------

# Entra / Intune / Trend
$SampleEntraDevicesFile  = Join-Path $SampleDataPath "entra_devices_demo.json"
$SampleIntuneDevicesFile = Join-Path $SampleDataPath "intune_devices_demo.json"
$SampleTrendDevicesFile  = Join-Path $SampleDataPath "trend_devices_demo.json"

# Defender demo files
$SampleDefenderAlertsFile     = Join-Path $SampleDataPath "defender_alerts_demo.json"
$SampleDefenderMachinesFile   = Join-Path $SampleDataPath "defender_machines_demo.json"
$SampleDefenderHuntingFile    = Join-Path $SampleDataPath "defender_hunting_demo.json"
$SampleDefenderMissingKbsFile = Join-Path $SampleDataPath "defender_missing_kbs_demo.json"

# ---------------------------
# OUTPUT FILES
# ---------------------------

$Timestamp = Get-Date -Format "yyyyMMdd-HHmm"

# Full report
$FullReportFile = Join-Path $ReportsPath "security_device_full_report_$Timestamp.json"
$FullReportStable = Join-Path $ReportsPath "security_device_full_report_demo.json"

# Summary report
$SummaryReportFile = Join-Path $ReportsPath "security_device_summary_$Timestamp.json"
$SummaryReportStable = Join-Path $ReportsPath "security_device_summary_demo.json"

# Frontend exports
$FrontendFullReport   = Join-Path $FrontendDataPath "security_device_full_report.json"
$FrontendSummary     = Join-Path $FrontendDataPath "security_device_summary.json"

# ---------------------------
# PROJECT NAME
# ---------------------------

$ReportName = "Security Device Monitor Report (Public Demo)"

# ---------------------------
# RISK LEVEL CONFIG
# ---------------------------

$RiskLevels = @{
    Critical = 90
    High     = 70
    Medium   = 40
    Low      = 10
}

# ---------------------------
# LOGGING
# ---------------------------

$EnableVerboseLogging = $true

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp][$Level] $Message"
}

# ---------------------------
# FOLDER INITIALIZATION
# ---------------------------

$Folders = @(
    $DataRoot,
    $RawDataPath,
    $ProcessedPath,
    $ReportsPath,
    $SampleDataPath,
    $FrontendDataPath
)

foreach ($folder in $Folders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Log "Created folder: $folder"
    }
}

# ---------------------------
# VALIDATION
# ---------------------------

if ($DemoMode -and -not $EnableDemoData) {
    throw "DemoMode is enabled but EnableDemoData is disabled."
}

if ($EnableDefenderDemo) {
    Write-Log "Defender demo mode enabled"
}

Write-Log "Configuration loaded successfully"