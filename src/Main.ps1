# =====================================================
# MAIN - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------
# LOAD CONFIG
# ---------------------------

. "$PSScriptRoot\config\Config.ps1"

# ---------------------------
# LOAD MODULES
# ---------------------------

. "$PSScriptRoot\core\DefenderCollect.ps1"
. "$PSScriptRoot\processing\Correlation.ps1"
. "$PSScriptRoot\processing\RiskEngine.ps1"
. "$PSScriptRoot\output\Reports.ps1"

# Optional mail module
if (Test-Path "$PSScriptRoot\output\Mail.ps1") {
    . "$PSScriptRoot\output\Mail.ps1"
}

# ---------------------------
# HELPERS
# ---------------------------

function Read-DemoJsonFile {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Required file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($content)) {
        return @()
    }

    $data = $content | ConvertFrom-Json

    if ($data -is [System.Collections.IEnumerable] -and -not ($data -is [string])) {
        return @($data)
    }

    return @($data)
}

function Export-FrontendData {
    param (
        [Parameter(Mandatory)]
        $Reports
    )

    if (-not $EnableFrontendExport) {
        return
    }

    if (-not (Test-Path $FrontendPath)) {
        New-Item -ItemType Directory -Path $FrontendPath -Force | Out-Null
    }

    $Reports.Full | ConvertTo-Json -Depth 12 | Out-File -FilePath $FrontendFullReportPath -Encoding UTF8
    $Reports.Summary | ConvertTo-Json -Depth 12 | Out-File -FilePath $FrontendSummaryReportPath -Encoding UTF8
}

function Get-DemoData {

    Write-Log "Loading demo datasets..."

    $entraDevices  = Read-DemoJsonFile -Path $SampleEntraDevicesFile
    $intuneDevices = Read-DemoJsonFile -Path $SampleIntuneDevicesFile
    $trendDevices  = Read-DemoJsonFile -Path $SampleTrendDevicesFile

    $defenderData = $null

    if ($EnableDefenderDemo) {
        $defenderData = Get-DefenderDemoData `
            -AlertsFile $SampleDefenderAlertsFile `
            -MachinesFile $SampleDefenderMachinesFile `
            -HuntingFile $SampleDefenderHuntingFile `
            -MissingKbsFile $SampleDefenderMissingKbsFile
    }

    return [PSCustomObject]@{
        EntraDevices  = $entraDevices
        IntuneDevices = $intuneDevices
        TrendDevices  = $trendDevices
        DefenderData  = $defenderData
    }
}

# ---------------------------
# MAIN PIPELINE
# ---------------------------

function Start-SecurityDeviceMonitor {

    Write-Log "Starting Security Device Monitor..." "SUCCESS"

    if (-not $DemoMode) {
        throw "Public repo is demo mode only"
    }

    $data = Get-DemoData

    Write-Log "Running correlation..."
    $correlated = Invoke-Correlation `
        -EntraDevices $data.EntraDevices `
        -IntuneDevices $data.IntuneDevices `
        -TrendDevices $data.TrendDevices `
        -DefenderData $data.DefenderData

    Write-Log "Running risk engine..."
    $scored = Invoke-RiskEngine -Devices $correlated

    Write-Log "Generating reports..."
    $reports = Export-Reports `
        -Devices $scored `
        -FullReportFile $FullReportTimestampedPath `
        -FullReportStable $FullReportStablePath `
        -SummaryReportFile $SummaryReportTimestampedPath `
        -SummaryReportStable $SummaryReportStablePath `
        -ReportName $ReportName

    Export-FrontendData -Reports $reports

    Write-Log "Execution completed successfully" "SUCCESS"

    return $reports
}

# ---------------------------
# RUN
# ---------------------------

Start-SecurityDeviceMonitor