# =====================================================
# MAIN - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

# ---------------------------
# LOAD CONFIG
# ---------------------------

. "$PSScriptRoot\config\Config.ps1"

Write-Log "Starting Security Device Monitor..."

# ---------------------------
# LOAD MODULES
# ---------------------------

. "$PSScriptRoot\core\EntraCollect.ps1"
. "$PSScriptRoot\core\IntuneCollect.ps1"
. "$PSScriptRoot\core\TrendCollect.ps1"
. "$PSScriptRoot\core\DefenderCollect.ps1"

. "$PSScriptRoot\processing\Correlation.ps1"
. "$PSScriptRoot\processing\RiskEngine.ps1"

. "$PSScriptRoot\output\Reports.ps1"
. "$PSScriptRoot\output\Mail.ps1"

# ---------------------------
# STEP 1 - LOAD DATA
# ---------------------------

Write-Log "Loading data sources..."

if ($DemoMode -and $EnableDemoData) {

    Write-Log "Using DEMO data"

    $EntraDevices  = Get-Content $SampleEntraDevicesFile  | ConvertFrom-Json
    $IntuneDevices = Get-Content $SampleIntuneDevicesFile | ConvertFrom-Json
    $TrendDevices  = Get-Content $SampleTrendDevicesFile  | ConvertFrom-Json

} else {

    Write-Log "Live collection not enabled in public version" "WARN"
    $EntraDevices  = @()
    $IntuneDevices = @()
    $TrendDevices  = @()
}

# ---------------------------
# STEP 2 - LOAD DEFENDER
# ---------------------------

Write-Log "Loading Defender data..."

if ($EnableDefenderDemo) {

    $DefenderData = Get-DefenderDemoData `
        -AlertsFile     $SampleDefenderAlertsFile `
        -MachinesFile   $SampleDefenderMachinesFile `
        -HuntingFile    $SampleDefenderHuntingFile `
        -MissingKbsFile $SampleDefenderMissingKbsFile

} else {

    Write-Log "Defender disabled" "WARN"
    $DefenderData = $null
}

# ---------------------------
# STEP 3 - CORRELATION
# ---------------------------

Write-Log "Running correlation engine..."

$CorrelatedDevices = Invoke-Correlation `
    -EntraDevices  $EntraDevices `
    -IntuneDevices $IntuneDevices `
    -TrendDevices  $TrendDevices `
    -DefenderData  $DefenderData

# ---------------------------
# STEP 4 - RISK ENGINE
# ---------------------------

Write-Log "Running risk engine..."

$RiskDevices = Invoke-RiskEngine -Devices $CorrelatedDevices

# ---------------------------
# STEP 5 - REPORTS
# ---------------------------

Write-Log "Generating reports..."

$Reports = Export-Reports `
    -Devices $RiskDevices `
    -FullReportFile $FullReportFile `
    -FullReportStable $FullReportStable `
    -SummaryReportFile $SummaryReportFile `
    -SummaryReportStable $SummaryReportStable `
    -ReportName $ReportName

# ---------------------------
# STEP 6 - FRONTEND EXPORT
# ---------------------------

if ($EnableFrontendExport) {

    Write-Log "Exporting frontend data..."

    if (-not (Test-Path $FrontendDataPath)) {
        New-Item -ItemType Directory -Path $FrontendDataPath | Out-Null
    }

    $Reports.Full | ConvertTo-Json -Depth 10 | Out-File $FrontendFullReport -Encoding UTF8
    $Reports.Summary | ConvertTo-Json -Depth 10 | Out-File $FrontendSummary -Encoding UTF8

    Write-Log "Frontend data exported"
}

# ---------------------------
# STEP 7 - MAIL (DISABLED BY DEFAULT)
# ---------------------------

if ($EnableMail) {

    Write-Log "Sending report by mail..."

    Send-ReportMail `
        -Summary $Reports.Summary `
        -FullReportPath $FullReportStable
}

# ---------------------------
# FINAL LOG
# ---------------------------

Write-Log "Execution completed successfully"
Write-Log "Full report: $FullReportStable"
Write-Log "Summary report: $SummaryReportStable"