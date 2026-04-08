# =====================================================
# DEVICE SECURITY POSTURE MONITOR - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Build a consolidated device view by correlating
# Trend Vision One, Entra ID, and Intune signals.
#
# Public version goals:
# - run safely with fake / sample data
# - avoid production dependencies by default
# - demonstrate architecture, correlation, scoring,
#   and reporting logic
# =====================================================

# =====================================================
# MODULE LOADING
# =====================================================

. "$PSScriptRoot\tools\Invoke-TrendCollectEndpoint.ps1"

. "$PSScriptRoot\config\Config.ps1"
. "$PSScriptRoot\core\GraphAuth.ps1"
. "$PSScriptRoot\core\EntraCollect.ps1"
. "$PSScriptRoot\core\IntuneCollect.ps1"
. "$PSScriptRoot\core\DefenderCollect.ps1"
. "$PSScriptRoot\core\TrendCollect.ps1"
. "$PSScriptRoot\processing\Correlation.ps1"
. "$PSScriptRoot\processing\RiskEngine.ps1"
. "$PSScriptRoot\output\Reports.ps1"
. "$PSScriptRoot\output\Mail.ps1"

# =====================================================
# MAIN EXECUTION
# =====================================================

try {
    Write-Host "[STEP] Starting Device Security Posture Monitor" -ForegroundColor Cyan

    $headers = $null

    # =====================================================
    # AUTHENTICATION (OPTIONAL IN PUBLIC DEMO)
    # =====================================================
    if (-not $DemoMode -and $EnableGraphCollection) {
        Write-Host "[STEP] Authenticating to Microsoft Graph" -ForegroundColor Cyan

        $accessToken = Get-GraphToken `
            -TenantId $TenantId `
            -ClientId $ClientId `
            -ClientSecret $ClientSecret

        $headers = @{
            Authorization = "Bearer $accessToken"
        }
    }
    else {
        Write-Host "[INFO] Demo mode active - Microsoft Graph authentication skipped" -ForegroundColor White
    }

    # =====================================================
    # ENTRA COLLECTION / DEMO LOAD
    # =====================================================
    if ($DemoMode) {
        $entraData = Get-EntraDevices `
            -DemoMode `
            -SampleEntraFile $SampleEntraFile `
            -RawDataPath $RawDataPath `
            -ProcessedDataPath $ProcessedDataPath
    }
    else {
        $entraData = Get-EntraDevices `
            -Headers $headers `
            -RawDataPath $RawDataPath `
            -ProcessedDataPath $ProcessedDataPath
    }

    $entraByDeviceId = $entraData.ByDeviceId
    $entraByDisplayName = $entraData.ByDisplayName

    # =====================================================
    # INTUNE COLLECTION / DEMO LOAD
    # =====================================================
    if ($DemoMode) {
        $intuneData = Get-IntuneDevices `
            -DemoMode `
            -SampleIntuneFile $SampleIntuneFile `
            -EntraByDeviceId $entraByDeviceId
    }
    else {
        $intuneData = Get-IntuneDevices `
            -Headers $headers `
            -EntraByDeviceId $entraByDeviceId
    }

    $cleanExport = $intuneData.CleanDevices
    $intuneByDeviceId = $intuneData.ByDeviceId

    # =====================================================
    # DEFENDER (DISABLED BY DEFAULT IN PUBLIC DEMO)
    # =====================================================
    if ($EnableDefender -and -not $DemoMode) {
        Write-Host "[INFO] Defender integration is enabled, but still optional in this public version" -ForegroundColor White

        # Example future flow:
        # $accessTokenDefender = Get-DefenderAccessToken `
        #     -TenantId $DefenderTenantId `
        #     -ClientId $DefenderClientId `
        #     -ClientSecret $DefenderClientSecret
        #
        # $defenderDevices = Get-DefenderDevices -AccessTokenDefender $accessTokenDefender
        # $defenderMap = New-DefenderDeviceMap -DefenderDevices $defenderDevices
    }
    else {
        Write-Host "[INFO] Defender integration skipped" -ForegroundColor White
    }

    # =====================================================
    # TREND COLLECTION / DEMO LOAD / CACHE
    # =====================================================
    if ($DemoMode) {
        Write-Host "[STEP] Loading Trend demo dataset" -ForegroundColor Cyan

        $trendData = Get-TrendDevices `
            -DemoMode `
            -SampleTrendFile $SampleTrendFile `
            -ProcessedDataPath $ProcessedDataPath
    }
    else {
        $latestTrendFile = Get-ChildItem -Path $ProcessedDataPath -Filter "trend_workstations_*.json" -ErrorAction SilentlyContinue |
            Sort-Object -Property LastWriteTime |
            Select-Object -Last 1

        $shouldCollectTrend = $true

        if ($latestTrendFile) {
            $trendFileAgeHours = ((Get-Date) - $latestTrendFile.LastWriteTime).TotalHours

            if ($trendFileAgeHours -lt $TrendCacheMaxAgeHours) {
                $shouldCollectTrend = $false
                Write-Host "[INFO] Reusing recent Trend workstation file: $($latestTrendFile.Name)" -ForegroundColor White
                Write-Host "[INFO] Trend file age: $([math]::Round($trendFileAgeHours, 2)) hours" -ForegroundColor White
            }
            else {
                Write-Host "[INFO] Existing Trend workstation file is too old: $([math]::Round($trendFileAgeHours, 2)) hours" -ForegroundColor Yellow
                Write-Host "[INFO] Starting fresh Trend collection" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "[INFO] No existing Trend workstation file found" -ForegroundColor Yellow
            Write-Host "[INFO] Starting fresh Trend collection" -ForegroundColor Yellow
        }

        if ($EnableTrendApiCollection) {
            if ($shouldCollectTrend) {
                Invoke-TrendCollectEndpoint `
                    -RawDataPath $RawDataPath `
                    -ProcessedDataPath $ProcessedDataPath `
                    -NoPreview
            }
        }
        else {
            Write-Host "[INFO] Trend API collection disabled - using latest local processed file if available" -ForegroundColor White
        }

        $trendData = Get-TrendDevices -ProcessedDataPath $ProcessedDataPath
    }

    $trendDevices = $trendData.Devices

    # =====================================================
    # CORRELATION
    # =====================================================
    $correlationData = New-ConsolidatedDevices `
        -TrendDevices $trendDevices `
        -EntraAll $entraData.AllDevices `
        -EntraByDisplayName $entraByDisplayName `
        -IntuneByDeviceId $intuneByDeviceId
        # -DefenderMap $defenderMap

    $ConsolidatedDevices = $correlationData.ConsolidatedDevices
    $DevicesMatched = $correlationData.DevicesMatched
    $DevicesPartial = $correlationData.DevicesPartial
    $DevicesUnmatched = $correlationData.DevicesUnmatched

    # =====================================================
    # RISK ENGINE
    # =====================================================
    $riskData = Invoke-RiskEngine -ConsolidatedDevices $ConsolidatedDevices

    $ConsolidatedDevices = $riskData.ConsolidatedDevices
    $duplicateHostnameCount = $riskData.DuplicateHostnameCount

    $tagCountCritical = $riskData.TagCountCritical
    $tagCountWarning = $riskData.TagCountWarning
    $tagCountNormal = $riskData.TagCountNormal

    $issueNotRegisteredInEntra = $riskData.IssueNotRegisteredInEntra
    $issueProbablePrivateByodNotRegistered = $riskData.IssueProbablePrivateByodNotRegistered
    $issueNoncompliantDevice = $riskData.IssueNoncompliantDevice
    $issueByodWorkplace = $riskData.IssueByodWorkplace
    $issueNotManagedInIntune = $riskData.IssueNotManagedInIntune

    $riskLevelCritical = $riskData.RiskLevelCritical
    $riskLevelHigh = $riskData.RiskLevelHigh
    $riskLevelMedium = $riskData.RiskLevelMedium
    $riskLevelLow = $riskData.RiskLevelLow

    # =====================================================
    # REPORTS
    # =====================================================
    $reportData = Export-ByodReports `
        -ConsolidatedDevices $ConsolidatedDevices `
        -DevicesMatched $DevicesMatched `
        -DevicesPartial $DevicesPartial `
        -DevicesUnmatched $DevicesUnmatched `
        -TagCountCritical $tagCountCritical `
        -TagCountWarning $tagCountWarning `
        -TagCountNormal $tagCountNormal `
        -IssueNotRegisteredInEntra $issueNotRegisteredInEntra `
        -IssueProbablePrivateByodNotRegistered $issueProbablePrivateByodNotRegistered `
        -IssueNoncompliantDevice $issueNoncompliantDevice `
        -IssueByodWorkplace $issueByodWorkplace `
        -IssueNotManagedInIntune $issueNotManagedInIntune `
        -RiskLevelCritical $riskLevelCritical `
        -RiskLevelHigh $riskLevelHigh `
        -RiskLevelMedium $riskLevelMedium `
        -RiskLevelLow $riskLevelLow `
        -DuplicateHostnameCount $duplicateHostnameCount `
        -CleanExport $cleanExport `
        -ReportsPath $ReportsPath `
        -ProcessedDataPath $ProcessedDataPath `
        -ProjectRoot $ProjectRoot

    $fullJsonPath = $reportData.FullJsonPath
    $fullJsonStablePath = $reportData.FullJsonStablePath
    $helpdeskCases = $reportData.HelpdeskCases
    $HelpDeskReportPathCsv = $reportData.HelpDeskReportPathCsv
    $HelpDeskReportPathJson = $reportData.HelpDeskReportPathJson
    $IntuneExportPath = $reportData.IntuneExportPath
    $OnlyEntraDevicesPath = $reportData.EntraOnlyReportPath
    $ProbablePrivateByodPath = $reportData.ProbablePrivateByodPath

    # =====================================================
    # MAIL (OPTIONAL / DISABLED BY DEFAULT)
    # =====================================================
    if ($EnableMail) {
        $mailResult = Send-ByodReportMail `
            -HelpdeskCases $helpdeskCases `
            -TagCountCritical $tagCountCritical `
            -TagCountWarning $tagCountWarning `
            -TagCountNormal $tagCountNormal `
            -ProbablePrivateByodCount $issueProbablePrivateByodNotRegistered `
            -ConsolidatedDevices $ConsolidatedDevices `
            -HelpDeskReportPathCsv $HelpDeskReportPathCsv `
            -EmailRecipient $EmailRecipient `
            -EmailSender $EmailSender `
            -SmtpServer $SmtpServer `
            -SmtpPort $SmtpPort `
            -ForceSend $false
    }
    else {
        Write-Host "[INFO] Mail sending disabled in public demo configuration" -ForegroundColor White

        $mailResult = [PSCustomObject]@{
            Sent   = $false
            Reason = "mail_disabled"
        }
    }

    # =====================================================
    # EXECUTION SUMMARY
    # =====================================================
    $helpdeskNoncompliant = ($helpdeskCases | Where-Object { $_.issues -contains "noncompliant_device" }).Count
    $helpdeskPartial = ($helpdeskCases | Where-Object { $_.status -eq "partial" }).Count
    $helpdeskUnmatched = ($helpdeskCases | Where-Object { $_.status -eq "unmatched" }).Count
    $helpdeskWorkplace = ($helpdeskCases | Where-Object { $_.entra_trust_type -eq "Workplace" }).Count
    $helpdeskProbablePrivateByod = ($helpdeskCases | Where-Object { $_.issues -contains "probable_private_byod_not_registered_in_entra" }).Count
    $entraOnlyCount = @($ConsolidatedDevices | Where-Object { $_.match_status -eq "present_in_entra" }).Count

    Write-Host ""
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host "DEVICE SECURITY POSTURE REPORT" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Execution mode       : $(if ($DemoMode) { 'Demo' } else { 'Live' })" -ForegroundColor White
    Write-Host "Total Trend devices  : $($trendDevices.Count)" -ForegroundColor White
    Write-Host "Total consolidated   : $($ConsolidatedDevices.Count)" -ForegroundColor White
    Write-Host ""

    Write-Host "Matched              : $($DevicesMatched.Count)" -ForegroundColor Green
    Write-Host "Partial              : $($DevicesPartial.Count)" -ForegroundColor Yellow
    Write-Host "Unmatched            : $($DevicesUnmatched.Count)" -ForegroundColor Red
    Write-Host "Entra-only           : $entraOnlyCount" -ForegroundColor White
    Write-Host ""

    Write-Host "Critical             : $tagCountCritical" -ForegroundColor Red
    Write-Host "Warning              : $tagCountWarning" -ForegroundColor Yellow
    Write-Host "Normal               : $tagCountNormal" -ForegroundColor Green
    Write-Host ""

    Write-Host "Helpdesk cases       : $($helpdeskCases.Count)" -ForegroundColor Magenta
    Write-Host "Noncompliant         : $helpdeskNoncompliant" -ForegroundColor Yellow
    Write-Host "Partial              : $helpdeskPartial" -ForegroundColor Yellow
    Write-Host "Unmatched            : $helpdeskUnmatched" -ForegroundColor Yellow
    Write-Host "Workplace            : $helpdeskWorkplace" -ForegroundColor Yellow
    Write-Host "Probable personal    : $helpdeskProbablePrivateByod" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Reports exported:" -ForegroundColor Cyan
    Write-Host $HelpDeskReportPathCsv -ForegroundColor Cyan
    Write-Host $HelpDeskReportPathJson -ForegroundColor Cyan
    Write-Host $fullJsonPath -ForegroundColor Cyan
    Write-Host $fullJsonStablePath -ForegroundColor Cyan
    Write-Host $IntuneExportPath -ForegroundColor Cyan
    Write-Host $OnlyEntraDevicesPath -ForegroundColor Cyan
    Write-Host $ProbablePrivateByodPath -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Mail status          : $($mailResult.Reason)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "============================" -ForegroundColor Cyan
}
catch {
    Write-Host "[ERROR] Script execution failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }

    throw
}