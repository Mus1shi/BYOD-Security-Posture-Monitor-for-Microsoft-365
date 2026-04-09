# =====================================================
# REPORT EXPORTS - PUBLIC DEMO VERSION
# =====================================================
# Export:
# - Full consolidated JSON report
# - Helpdesk CSV / JSON report
# - Entra-only JSON report
# - Probable personal device JSON report
# - Enriched Intune CSV export
# =====================================================

function Export-ByodReports {
    param (
        [array]$ConsolidatedDevices,
        [array]$DevicesMatched,
        [array]$DevicesPartial,
        [array]$DevicesUnmatched,

        [int]$TagCountCritical,
        [int]$TagCountWarning,
        [int]$TagCountNormal,

        [int]$IssueNotRegisteredInEntra,
        [int]$IssueProbablePrivateByodNotRegistered,
        [int]$IssueNoncompliantDevice,
        [int]$IssueByodWorkplace,
        [int]$IssueNotManagedInIntune,

        [int]$RiskLevelCritical,
        [int]$RiskLevelHigh,
        [int]$RiskLevelMedium,
        [int]$RiskLevelLow,

        [int]$DuplicateHostnameCount,

        [array]$CleanExport,
        [string]$ReportsPath,
        [string]$ProcessedDataPath,
        [string]$ProjectRoot
    )

    Write-Host "[STEP] Exporting reports" -ForegroundColor Cyan

    $date = Get-Date -Format "yyyyMMdd-HHmm"

    # =====================================================
    # FULL CONSOLIDATED JSON REPORT
    # =====================================================
    $fullJsonDataset = [PSCustomObject]@{
        generated_at  = $date
        total_records = $ConsolidatedDevices.Count

        highlights    = [PSCustomObject]@{
            urgent_devices       = @($ConsolidatedDevices | Where-Object { $_.is_urgent -eq $true }).Count
            critical_devices     = $TagCountCritical
            warning_devices      = $TagCountWarning
            noncompliant_devices = @($ConsolidatedDevices | Where-Object { $_.is_noncompliant -eq $true }).Count

            probable_personal_devices = @($ConsolidatedDevices | Where-Object {
                $_.issues -contains "probable_private_byod_not_registered_in_entra"
            }).Count

            devices_not_managed_in_intune = @($ConsolidatedDevices | Where-Object {
                $_.issues -contains "not_managed_in_intune"
            }).Count

            unmatched_devices = $DevicesUnmatched.Count
        }

        summary = [PSCustomObject]@{
            total_devices       = $ConsolidatedDevices.Count

            risk_level_critical = $RiskLevelCritical
            risk_level_high     = $RiskLevelHigh
            risk_level_medium   = $RiskLevelMedium
            risk_level_low      = $RiskLevelLow

            critical_devices    = $TagCountCritical
            warning_devices     = $TagCountWarning
            normal_devices      = $TagCountNormal
            urgent_devices      = @($ConsolidatedDevices | Where-Object { $_.is_urgent -eq $true }).Count

            issue_not_registered_in_entra              = $IssueNotRegisteredInEntra
            issue_probable_personal_device_not_registered = $IssueProbablePrivateByodNotRegistered
            issue_noncompliant_device                  = $IssueNoncompliantDevice
            issue_workplace_registration               = $IssueByodWorkplace
            issue_not_managed_in_intune                = $IssueNotManagedInIntune

            matched_devices    = $DevicesMatched.Count
            partial_devices    = $DevicesPartial.Count
            unmatched_devices  = $DevicesUnmatched.Count
            entra_only_devices = @($ConsolidatedDevices | Where-Object { $_.match_status -eq "present_in_entra" }).Count

            duplicate_hostnames = $DuplicateHostnameCount

            trend_present  = @($ConsolidatedDevices | Where-Object { $_.has_trend -eq $true }).Count
            entra_present  = @($ConsolidatedDevices | Where-Object { $_.has_entra -eq $true }).Count
            intune_present = @($ConsolidatedDevices | Where-Object { $_.has_intune -eq $true }).Count

            registered_in_entra = @($ConsolidatedDevices | Where-Object { $_.is_registered_in_entra -eq $true }).Count
            managed_in_intune   = @($ConsolidatedDevices | Where-Object { $_.is_managed_in_intune -eq $true }).Count
            noncompliant_total  = @($ConsolidatedDevices | Where-Object { $_.is_noncompliant -eq $true }).Count

            fully_visible     = @($ConsolidatedDevices | Where-Object { $_.source_health_status -eq "fully_visible" }).Count
            partially_visible = @($ConsolidatedDevices | Where-Object { $_.source_health_status -eq "partially_visible" }).Count
            source_gap        = @($ConsolidatedDevices | Where-Object { $_.source_health_status -eq "source_gap" }).Count
            entra_visible_only = @($ConsolidatedDevices | Where-Object { $_.source_health_status -eq "entra_visible_only" }).Count

            inactive_devices_30d_plus = @($ConsolidatedDevices | Where-Object {
                $null -ne $_.days_since_last_connection -and $_.days_since_last_connection -gt 30
            }).Count
        }

        records = $ConsolidatedDevices
    }

    $fullJsonPath = Join-Path $ReportsPath "Full_device_security_report_$date.json"
    $fullJsonDataset | ConvertTo-Json -Depth 10 | Out-File -FilePath $fullJsonPath -Encoding UTF8

    $infraFilesPath = Join-Path $ProjectRoot "data\infra_files"

    if (-not (Test-Path $infraFilesPath)) {
        New-Item -Path $infraFilesPath -ItemType Directory -Force | Out-Null
    }

    $fullJsonStablePath = Join-Path $infraFilesPath "Full_device_security_report.json"
    $fullJsonDataset | ConvertTo-Json -Depth 10 | Out-File -FilePath $fullJsonStablePath -Encoding UTF8

    # =====================================================
    # HELPDESK REPORT VIEW
    # =====================================================
    $helpdeskCases = @()

    foreach ($device in $ConsolidatedDevices) {
        if ($device.visual_tag -eq "critical" -or $device.visual_tag -eq "warning") {

            $caseUser = "unknown"
            if ($device.intune -and $device.intune.USER) {
                $caseUser = $device.intune.USER
            }

            $helpdeskObject = [PSCustomObject]@{
                risk_level                 = $device.risk_level
                risk_score                 = $device.risk_score
                device_name                = $device.device_name
                user                       = $caseUser
                reason                     = $device.match_reason
                recommended_action         = $device.recommended_action
                is_urgent                  = $device.is_urgent
                priority                   = $device.priority
                status                     = $device.match_status
                visual_tag                 = $device.visual_tag
                issues                     = $device.issues

                entra_trust_type           = $device.entra_trust_type

                recent_activity            = $device.recent_activity
                days_since_last_connection = $device.days_since_last_connection

                source_health_status       = $device.source_health_status
                source_health_reason       = $device.source_health_reason
                trend_running              = $device.trend_running
                entra_running              = $device.entra_running
                intune_running             = $device.intune_running
            }

            $helpdeskCases += $helpdeskObject
        }
    }

    $helpdeskCases = $helpdeskCases | Sort-Object `
        @{ Expression = {
                switch ($_.priority) {
                    "urgent" { 0 }
                    "high"   { 1 }
                    "medium" { 2 }
                    "normal" { 3 }
                    default  { 4 }
                }
            }
        },
        @{ Expression = { $_.risk_score }; Descending = $true },
        @{ Expression = {
                switch ($_.visual_tag) {
                    "critical" { 0 }
                    "warning"  { 1 }
                    "normal"   { 2 }
                    default    { 3 }
                }
            }
        }

    $helpDeskReportPathCsv = Join-Path $ReportsPath "device_helpdesk_report_$date.csv"
    $helpDeskReportPathJson = Join-Path $ReportsPath "device_helpdesk_report_$date.json"

    $helpdeskCases | Export-Csv -Path $helpDeskReportPathCsv -NoTypeInformation -Delimiter ";"
    $helpdeskCases | ConvertTo-Json -Depth 10 | Out-File -FilePath $helpDeskReportPathJson -Encoding UTF8

    # =====================================================
    # ENTRA-ONLY DEVICES REPORT
    # =====================================================
    $onlyEntraDevices = $ConsolidatedDevices | Where-Object {
        $_.match_status -eq "present_in_entra"
    }

    $onlyEntraDevicesPath = Join-Path $ReportsPath "entra_only_devices_$date.json"

    $onlyEntraDevicesFile = [PSCustomObject]@{
        generated_at  = $date
        total_devices = $onlyEntraDevices.Count
        summary       = [PSCustomObject]@{
            total_devices             = $onlyEntraDevices.Count
            managed_in_intune         = @($onlyEntraDevices | Where-Object { $_.is_managed_in_intune -eq $true }).Count
            not_managed_in_intune     = @($onlyEntraDevices | Where-Object { $_.is_managed_in_intune -eq $false }).Count
            noncompliant_devices      = @($onlyEntraDevices | Where-Object { $_.is_noncompliant -eq $true }).Count
            workplace_devices         = @($onlyEntraDevices | Where-Object { $_.entra_trust_type -eq "Workplace" }).Count
            inactive_devices_30d_plus = @($onlyEntraDevices | Where-Object {
                $null -ne $_.days_since_last_connection -and $_.days_since_last_connection -gt 30
            }).Count
        }
        records       = $onlyEntraDevices
    }

    $onlyEntraDevicesFile | ConvertTo-Json -Depth 10 | Out-File -FilePath $onlyEntraDevicesPath -Encoding UTF8

    # =====================================================
    # PROBABLE PERSONAL DEVICE REPORT
    # =====================================================
    $probablePersonalDevices = $ConsolidatedDevices | Where-Object {
        $_.issues -contains "probable_private_byod_not_registered_in_entra"
    }

    $probablePersonalDevicesPath = Join-Path $ReportsPath "probable_personal_devices_$date.json"

    $probablePersonalDevicesFile = [PSCustomObject]@{
        generated_at  = $date
        total_devices = $probablePersonalDevices.Count
        summary       = [PSCustomObject]@{
            total_devices             = $probablePersonalDevices.Count
            recent_activity_devices   = @($probablePersonalDevices | Where-Object { $_.recent_activity -eq $true }).Count
            inactive_devices_30d_plus = @($probablePersonalDevices | Where-Object {
                $null -ne $_.days_since_last_connection -and $_.days_since_last_connection -gt 30
            }).Count
            duplicate_hostnames       = @($probablePersonalDevices | Where-Object { $_.duplicate_hostname -eq $true }).Count
        }
        records       = $probablePersonalDevices
    }

    $probablePersonalDevicesFile | ConvertTo-Json -Depth 10 | Out-File -FilePath $probablePersonalDevicesPath -Encoding UTF8

    # =====================================================
    # ENRICHED INTUNE EXPORT
    # =====================================================
    $sortedCleanExport = $CleanExport | Sort-Object @{
        Expression = {
            switch ($_.COMPLIANCE) {
                "noncompliant" { 0 }
                "inGracePeriod" { 1 }
                "configManager" { 2 }
                default { 3 }
            }
        }
    }

    $intuneExportPath = Join-Path $ProcessedDataPath "Intune_ManagedDevices_Enriched_$date.csv"
    $sortedCleanExport | Export-Csv -Path $intuneExportPath -NoTypeInformation -Delimiter ";"

    Write-Host "[OK] Reports exported" -ForegroundColor Green

    return [PSCustomObject]@{
        FullJsonDataset         = $fullJsonDataset
        FullJsonPath            = $fullJsonPath
        FullJsonStablePath      = $fullJsonStablePath
        HelpdeskCases           = $helpdeskCases
        HelpDeskReportPathCsv   = $helpDeskReportPathCsv
        HelpDeskReportPathJson  = $helpDeskReportPathJson
        IntuneExportPath        = $intuneExportPath
        EntraOnlyReportPath     = $onlyEntraDevicesPath
        ProbablePrivateByodPath = $probablePersonalDevicesPath
    }
}