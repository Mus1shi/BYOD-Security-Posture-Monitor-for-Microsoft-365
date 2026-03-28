# =====================================================
# DEVICE MONITORING AND CORRELATION SCRIPT
# =====================================================
# Purpose:
# Build a consolidated device view by correlating Trend Micro,
# Entra ID, and Intune data.
#
# Public GitHub version:
# - Supports a safe Demo mode using fake sample datasets
# - Still keeps a Live mode structure for private/internal use
# - Prevents real API and mail dependencies when running in Demo
#
# Main outputs:
# - Full consolidated JSON report
# - Helpdesk-focused CSV / JSON report
# - Entra-only JSON report
# - Probable private BYOD JSON report
# - Optional email notification with attached report
#
# Main detection goals:
# - Devices seen in Trend but unknown in Entra ID
# - Devices known in Entra ID but not managed in Intune
# - Noncompliant managed devices
# - Workplace / BYOD-registered devices
# - Probable private BYOD not registered in Entra
# =====================================================

# =====================================================
# MAIN ORCHESTRATOR
# =====================================================
# This script:
# 1. Loads configuration
# 2. Loads all project modules
# 3. Chooses between Demo mode and Live mode
# 4. Collects or loads datasets
# 5. Correlates devices
# 6. Applies risk scoring
# 7. Exports reports
# 8. Optionally sends an email
# =====================================================

# -----------------------------------------------------
# Load project modules
# -----------------------------------------------------
# The order matters here because some functions depend
# on configuration values or other imported functions.
# -----------------------------------------------------

. "$PSScriptRoot\tools\Invoke-TrendCollectEndpoint.ps1"

. "$PSScriptRoot\config\Config.ps1"
. "$PSScriptRoot\core\GraphAuth.ps1"
. "$PSScriptRoot\core\EntraCollect.ps1"
. "$PSScriptRoot\core\IntuneCollect.ps1"
. "$PSScriptRoot\core\TrendCollect.ps1"
. "$PSScriptRoot\processing\Correlation.ps1"
. "$PSScriptRoot\processing\RiskEngine.ps1"
. "$PSScriptRoot\output\Reports.ps1"
. "$PSScriptRoot\output\Mail.ps1"

try {
    Write-Host "[STEP] Starting Devices Monitor" -ForegroundColor Cyan
    Write-Host "[INFO] Running mode: $Mode" -ForegroundColor White

    # =================================================
    # BASIC VALIDATION
    # =================================================
    # This block ensures the expected folders exist.
    # In a public GitHub demo, this avoids many path issues.
    # =================================================

    foreach ($folder in @($RawDataPath, $ProcessedDataPath, $ReportsPath)) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
            Write-Host "[INFO] Created missing folder: $folder" -ForegroundColor White
        }
    }

    # =================================================
    # DATA LOADING VARIABLES
    # =================================================
    # These variables are filled differently depending
    # on whether the script runs in Demo or Live mode.
    # =================================================

    $headers = @{}
    $entraData = $null
    $entraByDeviceId = @{}
    $entraByDisplayName = @{}

    $intuneData = $null
    $cleanExport = @()
    $intuneByDeviceId = @{}

    $trendData = $null
    $trendDevices = @()

    # =================================================
    # MODE SELECTION
    # =================================================
    # Demo mode:
    # - no real Graph authentication
    # - no real Trend API collection
    # - no required real SMTP
    #
    # Live mode:
    # - normal private/internal execution
    # =================================================

    switch ($Mode) {

        "Demo" {
            Write-Host "[INFO] Demo mode enabled - using sample datasets" -ForegroundColor Yellow

            # -----------------------------------------
            # Load fake Entra dataset
            # -----------------------------------------
            # Expected function:
            # Get-EntraDevicesFromSample -SamplePath <path>
            # -----------------------------------------
            $entraData = Get-EntraDevicesFromSample `
                -SamplePath $SampleEntraPath

            $entraByDeviceId = $entraData.ByDeviceId
            $entraByDisplayName = $entraData.ByDisplayName

            # -----------------------------------------
            # Load fake Intune dataset
            # -----------------------------------------
            # Expected function:
            # Get-IntuneDevicesFromSample -SamplePath <path> -EntraByDeviceId <hashtable>
            # -----------------------------------------
            $intuneData = Get-IntuneDevicesFromSample `
                -SamplePath $SampleIntunePath `
                -EntraByDeviceId $entraByDeviceId

            $cleanExport = $intuneData.CleanDevices
            $intuneByDeviceId = $intuneData.ByDeviceId

            # -----------------------------------------
            # Load fake Trend dataset
            # -----------------------------------------
            # Expected function:
            # Get-TrendDevicesFromSample -SamplePath <path>
            # -----------------------------------------
            $trendData = Get-TrendDevicesFromSample `
                -SamplePath $SampleTrendPath

            $trendDevices = $trendData.Devices
        }

        "Live" {
            Write-Host "[INFO] Live mode enabled - using real services" -ForegroundColor Yellow

            # =========================================
            # AUTH
            # =========================================
            # Real Microsoft Graph authentication.
            # This should only be used in the private/internal version.
            # =========================================
            $accessToken = Get-GraphToken `
                -TenantId $TenantId `
                -ClientId $ClientId `
                -ClientSecret $ClientSecret

            $headers = @{
                Authorization = "Bearer $accessToken"
            }

            # =========================================
            # ENTRA
            # =========================================
            $entraData = Get-EntraDevices `
                -Headers $headers `
                -RawDataPath $RawDataPath `
                -ProcessedDataPath $ProcessedDataPath

            $entraByDeviceId = $entraData.ByDeviceId
            $entraByDisplayName = $entraData.ByDisplayName

            # =========================================
            # INTUNE
            # =========================================
            $intuneData = Get-IntuneDevices `
                -Headers $headers `
                -EntraByDeviceId $entraByDeviceId

            $cleanExport = $intuneData.CleanDevices
            $intuneByDeviceId = $intuneData.ByDeviceId

            # =========================================
            # TREND COLLECTION / CACHE
            # =========================================
            # If a recent filtered Trend export exists,
            # reuse it instead of calling the API again.
            # =========================================
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

            if ($shouldCollectTrend) {
                Invoke-TrendCollectEndpoint `
                    -RawDataPath $RawDataPath `
                    -ProcessedDataPath $ProcessedDataPath `
                    -NoPreview
            }

            # =========================================
            # TREND LOAD
            # =========================================
            $trendData = Get-TrendDevices -ProcessedDataPath $ProcessedDataPath
            $trendDevices = $trendData.Devices
        }

        default {
            throw "Invalid Mode value in Config.ps1. Allowed values: Demo or Live."
        }
    }

    # =================================================
    # DATASET SANITY CHECK
    # =================================================
    # Fail early if a required dataset is empty or missing.
    # This is especially useful in a public demo repository.
    # =================================================

    if (-not $entraData -or -not $entraData.AllDevices -or $entraData.AllDevices.Count -eq 0) {
        throw "Entra dataset is empty or invalid."
    }

    if (-not $intuneData -or -not $intuneData.CleanDevices -or $intuneData.CleanDevices.Count -eq 0) {
        throw "Intune dataset is empty or invalid."
    }

    if (-not $trendDevices -or $trendDevices.Count -eq 0) {
        throw "Trend dataset is empty or invalid."
    }

    Write-Host "[OK] Entra devices available: $($entraData.AllDevices.Count)" -ForegroundColor Green
    Write-Host "[OK] Intune devices available: $($intuneData.CleanDevices.Count)" -ForegroundColor Green
    Write-Host "[OK] Trend devices available: $($trendDevices.Count)" -ForegroundColor Green

    # =================================================
    # CORRELATION
    # =================================================
    # Build a consolidated device view from:
    # - Trend devices
    # - Entra devices
    # - Intune devices
    # =================================================

    $correlationData = New-ConsolidatedDevices `
        -TrendDevices $trendDevices `
        -EntraAll $entraData.AllDevices `
        -EntraByDisplayName $entraByDisplayName `
        -IntuneByDeviceId $intuneByDeviceId

    $ConsolidatedDevices = $correlationData.ConsolidatedDevices
    $DevicesMatched = $correlationData.DevicesMatched
    $DevicesPartial = $correlationData.DevicesPartial
    $DevicesUnmatched = $correlationData.DevicesUnmatched

    # =================================================
    # RISK ENGINE
    # =================================================
    # Apply risk logic, issue tagging, and summary counts.
    # =================================================

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

    # =================================================
    # REPORTS
    # =================================================
    # Export JSON and CSV datasets for:
    # - full consolidated view
    # - helpdesk cases
    # - Entra-only devices
    # - probable private BYOD devices
    # - enriched Intune export
    # =================================================

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
        -ProcessedDataPath $ProcessedDataPath

    $fullJsonPath = $reportData.FullJsonPath
    $helpdeskCases = $reportData.HelpdeskCases
    $HelpDeskReportPathCsv = $reportData.HelpDeskReportPathCsv
    $HelpDeskReportPathJson = $reportData.HelpDeskReportPathJson
    $IntuneExportPath = $reportData.IntuneExportPath
    $OnlyEntraDevicesPath = $reportData.EntraOnlyReportPath
    $ProbablePrivateByodPath = $reportData.ProbablePrivateByodPath

    # =================================================
    # MAIL
    # =================================================
    # In Demo mode, or when mail is disabled, skip sending.
    # This prevents unwanted email usage in the public repo.
    # =================================================

    $mailResult = [PSCustomObject]@{
        Sent   = $false
        Reason = "mail_disabled"
    }

    if ($EnableMail -eq $true) {
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
            -ForceSend $true
    }
    else {
        Write-Host "[INFO] Mail sending disabled by configuration" -ForegroundColor White
    }

    # =================================================
    # EXECUTION SUMMARY
    # =================================================
    # Final console summary for quick operator review.
    # =================================================

    $helpdeskNoncompliant = ($helpdeskCases | Where-Object { $_.issues -contains "noncompliant_device" }).Count
    $helpdeskPartial = ($helpdeskCases | Where-Object { $_.status -eq "partial" }).Count
    $helpdeskUnmatched = ($helpdeskCases | Where-Object { $_.status -eq "unmatched" }).Count
    $helpdeskWorkplace = ($helpdeskCases | Where-Object { $_.entra_trust_type -eq "Workplace" }).Count
    $helpdeskProbablePrivateByod = ($helpdeskCases | Where-Object { $_.issues -contains "probable_private_byod_not_registered_in_entra" }).Count
    $entraOnlyCount = @($ConsolidatedDevices | Where-Object { $_.match_status -eq "present_in_entra" }).Count

    Write-Host ""
    Write-Host "[SUMMARY] BYOD Device Monitor Report" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host "BYOD DEVICE MONITOR REPORT" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Execution mode         : $Mode" -ForegroundColor White
    Write-Host "Total Trend devices    : $($trendDevices.Count)" -ForegroundColor White
    Write-Host ""

    Write-Host "Matched                : $($DevicesMatched.Count)" -ForegroundColor Green
    Write-Host "Partial                : $($DevicesPartial.Count)" -ForegroundColor Yellow
    Write-Host "Unmatched              : $($DevicesUnmatched.Count)" -ForegroundColor Red
    Write-Host "Entra-only             : $entraOnlyCount" -ForegroundColor White
    Write-Host ""

    Write-Host "Critical               : $tagCountCritical" -ForegroundColor Red
    Write-Host "Warning                : $tagCountWarning" -ForegroundColor Yellow
    Write-Host "Normal                 : $tagCountNormal" -ForegroundColor Green
    Write-Host ""

    Write-Host "Helpdesk cases         : $($helpdeskCases.Count)" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "Noncompliant           : $helpdeskNoncompliant" -ForegroundColor Yellow
    Write-Host "Partial                : $helpdeskPartial" -ForegroundColor Yellow
    Write-Host "Unmatched              : $helpdeskUnmatched" -ForegroundColor Yellow
    Write-Host "Workplace              : $helpdeskWorkplace" -ForegroundColor Yellow
    Write-Host "Probable private BYOD  : $helpdeskProbablePrivateByod" -ForegroundColor Yellow
    Write-Host "Duplicate hostnames    : $duplicateHostnameCount" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Reports exported:" -ForegroundColor Cyan
    Write-Host $HelpDeskReportPathCsv -ForegroundColor Cyan
    Write-Host $HelpDeskReportPathJson -ForegroundColor Cyan
    Write-Host $fullJsonPath -ForegroundColor Cyan
    Write-Host $IntuneExportPath -ForegroundColor Cyan
    Write-Host $OnlyEntraDevicesPath -ForegroundColor Cyan
    Write-Host $ProbablePrivateByodPath -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Mail status            : $($mailResult.Reason)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "============================" -ForegroundColor Cyan
}
catch {
    Write-Host "[ERROR] Script execution failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }
}