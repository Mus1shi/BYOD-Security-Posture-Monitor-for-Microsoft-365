# =====================================================
# MAIN - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------
# LOAD CONFIGURATION
# ---------------------------

. "$PSScriptRoot\config\Config.ps1"

# ---------------------------
# LOAD MODULES
# ---------------------------

. "$PSScriptRoot\core\DefenderCollect.ps1"
. "$PSScriptRoot\processing\Correlation.ps1"
. "$PSScriptRoot\processing\RiskEngine.ps1"
. "$PSScriptRoot\output\Reports.ps1"

if (Test-Path "$PSScriptRoot\output\Mail.ps1") {
    . "$PSScriptRoot\output\Mail.ps1"
}

# ---------------------------
# GENERIC HELPERS
# ---------------------------

function Read-DemoJsonFile {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Demo JSON file not found: $Path"
    }

    try {
        $content = Get-Content -Path $Path -Raw -Encoding UTF8

        if ([string]::IsNullOrWhiteSpace($content)) {
            return @()
        }

        $data = $content | ConvertFrom-Json

        if ($null -eq $data) {
            return @()
        }

        if ($data -is [System.Collections.IEnumerable] -and -not ($data -is [string])) {
            return @($data)
        }

        return @($data)
    }
    catch {
        throw "Failed to read demo JSON file '$Path': $($_.Exception.Message)"
    }
}

function Export-FrontendData {
    param (
        [Parameter(Mandatory)]
        $Reports
    )

    if (-not $EnableFrontendExport) {
        Write-Log "Frontend export disabled" "WARN"
        return
    }

    Ensure-Directory -Path $FrontendPath

    Write-Log "Exporting frontend full report..."
    $Reports.Full | ConvertTo-Json -Depth 12 | Out-File -FilePath $FrontendFullReportPath -Encoding UTF8

    Write-Log "Exporting frontend summary report..."
    $Reports.Summary | ConvertTo-Json -Depth 12 | Out-File -FilePath $FrontendSummaryReportPath -Encoding UTF8

    Write-Log "Frontend exports completed" "SUCCESS"
}

function Get-DemoSourceData {
    Write-Log "Loading public demo datasets..."

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

    Write-Log "Entra demo records loaded: $($entraDevices.Count)"
    Write-Log "Intune demo records loaded: $($intuneDevices.Count)"
    Write-Log "Trend demo records loaded: $($trendDevices.Count)"

    return [PSCustomObject]@{
        EntraDevices  = $entraDevices
        IntuneDevices = $intuneDevices
        TrendDevices  = $trendDevices
        DefenderData  = $defenderData
    }
}

function Start-SecurityDeviceMonitor {
    Write-Log "Starting $ProjectName..." "SUCCESS"

    if (-not $DemoMode) {
        throw "This public repository is configured for demo mode only."
    }

    if (-not $EnableDemoData) {
        throw "Demo mode is enabled but demo data loading is disabled."
    }

    $sourceData = Get-DemoSourceData

    Write-Log "Running correlation engine..."
    $correlatedDevices = Invoke-Correlation `
        -EntraDevices $sourceData.EntraDevices `
        -IntuneDevices $sourceData.IntuneDevices `
        -TrendDevices $sourceData.TrendDevices `
        -DefenderData $sourceData.DefenderData

    Write-Log "Running risk engine..."
    $scoredDevices = Invoke-RiskEngine -Devices $correlatedDevices

    Write-Log "Generating reports..."
    $reports = Export-Reports `
        -Devices $scoredDevices `
        -FullReportFile $FullReportTimestampedPath `
        -FullReportStable $FullReportStablePath `
        -SummaryReportFile $SummaryReportTimestampedPath `
        -SummaryReportStable $SummaryReportStablePath `
        -ReportName $ReportName

    Export-FrontendData -Reports $reports

    if ($EnableMail) {
        if (Get-Command -Name Send-ReportMail -ErrorAction SilentlyContinue) {
            Write-Log "Mail export enabled. Sending report..."
            Send-ReportMail `
                -Summary $reports.Summary `
                -FullReportPath $FullReportStablePath
        }
        else {
            Write-Log "Mail export requested but Send-ReportMail is not available." "WARN"
        }
    }

    Write-Log "Execution completed successfully" "SUCCESS"
    Write-Log "Stable full report: $FullReportStablePath"
    Write-Log "Stable summary report: $SummaryReportStablePath"

    if ($EnableFrontendExport) {
        Write-Log "Frontend full report: $FrontendFullReportPath"
        Write-Log "Frontend summary report: $FrontendSummaryReportPath"
    }

    return [PSCustomObject]@{
        CorrelatedDevices = $correlatedDevices
        ScoredDevices     = $scoredDevices
        Reports           = $reports
    }
}

Start-SecurityDeviceMonitor