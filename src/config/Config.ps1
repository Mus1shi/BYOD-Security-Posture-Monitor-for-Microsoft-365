# =====================================================
# CONFIGURATION - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

# ---------------------------
# PATHS
# ---------------------------

$ConfigRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcRoot     = Split-Path -Parent $ConfigRoot
$ProjectRoot = Split-Path -Parent $SrcRoot

$DataRoot       = Join-Path $ProjectRoot "data"
$SampleDataPath = Join-Path $DataRoot "sample"
$RawDataPath    = Join-Path $DataRoot "raw"
$ProcessedPath  = Join-Path $DataRoot "processed"
$ReportsPath    = Join-Path $DataRoot "reports"
$FrontendPath   = Join-Path $ReportsPath "frontend"

# ---------------------------
# PROJECT IDENTITY
# ---------------------------

$ProjectName = "Security Device Monitor"
$ReportName  = "Security Device Monitor Report (Public Demo)"

# ---------------------------
# EXECUTION MODES
# ---------------------------

$DemoMode             = $true
$EnableDemoData       = $true
$EnableFrontendExport = $true
$EnableMail           = $false

# Live collection is intentionally disabled in the public repository
$EnableGraphCollection = $false
$EnableTrendCollection = $false
$EnableDefenderLive    = $false

# Public Defender demo visibility
$EnableDefenderDemo = $true

# ---------------------------
# SAMPLE INPUT FILES
# ---------------------------

$SampleEntraDevicesFile  = Join-Path $SampleDataPath "entra_devices_demo.json"
$SampleIntuneDevicesFile = Join-Path $SampleDataPath "intune_devices_demo.json"
$SampleTrendDevicesFile  = Join-Path $SampleDataPath "trend_devices_demo.json"

$SampleDefenderAlertsFile     = Join-Path $SampleDataPath "defender_alerts_demo.json"
$SampleDefenderMachinesFile   = Join-Path $SampleDataPath "defender_machines_demo.json"
$SampleDefenderHuntingFile    = Join-Path $SampleDataPath "defender_hunting_demo.json"
$SampleDefenderMissingKbsFile = Join-Path $SampleDataPath "defender_missing_kbs_demo.json"

# ---------------------------
# REPORT OUTPUT FILES
# ---------------------------

$RunTimestamp = Get-Date -Format "yyyyMMdd-HHmm"

$FullReportTimestampedPath = Join-Path $ReportsPath "security_device_full_report_$RunTimestamp.json"
$FullReportStablePath      = Join-Path $ReportsPath "security_device_full_report_demo.json"

$SummaryReportTimestampedPath = Join-Path $ReportsPath "security_device_summary_$RunTimestamp.json"
$SummaryReportStablePath      = Join-Path $ReportsPath "security_device_summary_demo.json"

$FrontendFullReportPath    = Join-Path $FrontendPath "security_device_full_report.json"
$FrontendSummaryReportPath = Join-Path $FrontendPath "security_device_summary.json"

# ---------------------------
# RISK SCORING THRESHOLDS
# ---------------------------

$RiskThresholds = @{
    Critical = 90
    High     = 70
    Warning  = 40
    Normal   = 0
}

# ---------------------------
# LOGGING
# ---------------------------

$EnableVerboseLogging = $true

function Write-Log {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# ---------------------------
# FILESYSTEM HELPERS
# ---------------------------

function Ensure-Directory {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Write-Log "Created directory: $Path"
    }
}

function Test-RequiredFile {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Required file not found: $Path"
    }
}

# ---------------------------
# INITIALIZE DIRECTORIES
# ---------------------------

@(
    $DataRoot,
    $SampleDataPath,
    $RawDataPath,
    $ProcessedPath,
    $ReportsPath,
    $FrontendPath
) | ForEach-Object {
    Ensure-Directory -Path $_
}

# ---------------------------
# VALIDATION
# ---------------------------

if ($DemoMode -and -not $EnableDemoData) {
    throw "Invalid configuration: DemoMode is enabled but EnableDemoData is disabled."
}

if ($EnableDefenderLive -and $EnableDefenderDemo) {
    throw "Invalid configuration: public configuration must not enable Defender live mode and Defender demo mode at the same time."
}

if ($EnableDemoData) {
    @(
        $SampleEntraDevicesFile,
        $SampleIntuneDevicesFile,
        $SampleTrendDevicesFile
    ) | ForEach-Object {
        Test-RequiredFile -Path $_
    }

    if ($EnableDefenderDemo) {
        @(
            $SampleDefenderAlertsFile,
            $SampleDefenderMachinesFile,
            $SampleDefenderHuntingFile,
            $SampleDefenderMissingKbsFile
        ) | ForEach-Object {
            Test-RequiredFile -Path $_
        }
    }
}

Write-Log "Configuration loaded successfully" "SUCCESS"
Write-Log "Project root: $ProjectRoot"
Write-Log "Demo mode: $DemoMode"
Write-Log "Defender demo enabled: $EnableDefenderDemo"
Write-Log "Frontend export enabled: $EnableFrontendExport"