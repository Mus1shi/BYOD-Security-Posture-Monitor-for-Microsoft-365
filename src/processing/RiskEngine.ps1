# =====================================================
# REPORT EXPORTS
# =====================================================
# Purpose:
# Export:
# - Full consolidated JSON report
# - Helpdesk CSV / JSON report
# - Entra-only JSON report
# - Probable private BYOD JSON report
# - Enriched Intune CSV export
#
# Public GitHub version:
# - Keeps the same reporting logic as the internal project
# - Works with both Demo and Live mode
# - Adds defensive handling for incomplete sample data
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
        [string]$ProcessedDataPath
    )

    Write-Host "[STEP] Exporting reports" -ForegroundColor Cyan

    # -------------------------------------------------
    # Ensure output folders exist
    # -------------------------------------------------
    foreach ($folder in @($ReportsPath, $ProcessedDataPath)) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }

    $date = Get-Date -Format "yyyyMMdd-HHmm"

    # -------------------------------------------------
    # Defensive normalization
    # -------------------------------------------------
    # Make sure later report exports do not fail if a
    # demo dataset is incomplete.
    # -------------------------------------------------
    foreach ($device in $ConsolidatedDevices) {

        $requiredProperties = @(
            "match_status",
            "visual_tag",
            "risk_level",
            "risk_score",
            "device_name",
            "match_reason",
            "recommended_action",
            "issues",
            "entra_trust_type",
            "recent_activity",
            "days_since_last_connection",
            "has_trend",
            "has_entra",
            "has_intune",
            "is_registered_in_entra",
            "is_managed_in_intune",
            "is_noncompliant",
            "duplicate_hostname"
        )

        foreach ($property in $requiredProperties) {
            if (-not ($device.PSObject.Properties.Name -contains $property)) {
                $defaultValue = $null

                switch ($property) {
                    "issues" { $defaultValue = @() }
                    "recent_activity" { $defaultValue = $false }
                    "has_trend" { $defaultValue = $false }
                    "has_entra" { $defaultValue = $false }
                    "has_intune" { $defaultValue = $false }
                    "is_registered_in_entra" { $defaultValue = $false }
                    "is_managed_in_intune" { $defaultValue = $false }
                    "is_noncompliant" { $defaultValue = $false }
                    "duplicate_hostname" { $defaultValue = $false }
                }

                $device | Add-Member -NotePropertyName $property -NotePropertyValue $defaultValue -Force
            }
        }

        # Ensure nested Intune object exists when missing
        if (-not ($device.PSObject.Properties.Name -contains "intune")) {
            $device | Add-Member -NotePropertyName intune -NotePropertyValue $null -Force
        }
    }

    # =================================================
    # FULL CONSOLIDATED JSON REPORT
    # =================================================
    $fullJsonDataset = [PSCustomObject]@{
        generated_at  = $date
        total_records = $ConsolidatedDevices.Count
        summary       = [PSCustomObject]@{
            total_devices                              = $ConsolidatedDevices.Count

            risk_level_critical                        = $RiskLevelCritical
            risk_level_high                            = $RiskLevelHigh
            risk_level_medium                          = $RiskLevelMedium
            risk_level_low                             = $RiskLevelLow

            critical_devices                           = $TagCountCritical
            warning_devices                            = $TagCountWarning
            normal_devices                             = $TagCountNormal

            issue_not_registered_in_entra              = $IssueNotRegisteredInEntra
            issue_probable_private_byod_not_registered = $IssueProbablePrivateByodNotRegistered
            issue_noncompliant_device                  = $IssueNoncompliantDevice
            issue_byod_workplace                       = $IssueByodWorkplace
            issue_not_managed_in_intune                = $IssueNotManagedInIntune

            matched_devices                            = $DevicesMatched.Count
            partial_devices                            = $DevicesPartial.Count
            unmatched_devices                          = $DevicesUnmatched.Count
            entra_only_devices                         = @($ConsolidatedDevices | Where-Object { $_.match_status -eq "present_in_entra" }).Count

            duplicate_hostnames                        = $DuplicateHostnameCount

            trend_present                              = @($ConsolidatedDevices | Where-Object { $_.has_trend -eq $true }).Count
            entra_present                              = @($ConsolidatedDevices | Where-Object { $_.has_entra -eq $true }).Count
            intune_present                             = @($ConsolidatedDevices | Where-Object { $_.has_intune -eq $true }).Count

            registered_in_entra                        = @($ConsolidatedDevices | Where-Object { $_.is_registered_in_entra -eq $true }).Count
            managed_in_intune                          = @($ConsolidatedDevices | Where-Object { $_.is_managed_in_intune -eq $true }).Count
            noncompliant_devices                       = @($ConsolidatedDevices | Where-Object { $_.is_noncompliant -eq $true }).Count

            inactive_devices_30d_plus                  = @($ConsolidatedDevices | Where-Object {
                $null -ne $_.days_since_last_connection -and $_.days_since_last_connection -gt 30
            }).Count
        }
        records       = $ConsolidatedDevices
    }

    $fullJsonPath = Join-Path $ReportsPath "Full_devices_report_$date.json"
    $fullJsonDataset | ConvertTo-Json -Depth 10 | Out-File -FilePath $fullJsonPath -Encoding UTF8

    # =================================================
    # HELPDESK REPORT VIEW
    # =================================================
    $helpdeskCases = @()

    foreach ($device in $ConsolidatedDevices) {
        if ($device.visual_tag -eq "critical" -or $device.visual_tag -eq "warning") {

            $caseUser = "unknown"

            if ($device.intune -and $device.intune.PSObject.Properties.Name -contains "USER" -and $device.intune.USER) {
                $caseUser = $device.intune.USER
            }

            $helpdeskObject = [PSCustomObject]@{
                risk_level                 = $device.risk_level
                risk_score                 = $device.risk_score
                device_name                = $device.device_name
                user                       = $caseUser
                reason                     = $device.match_reason
                recommended_action         = $device.recommended_action
                status                     = $device.match_status
                visual_tag                 = $device.visual_tag
                issues                     = $device.issues
                entra_trust_type           = $device.entra_trust_type
                recent_activity            = $device.recent_activity
                days_since_last_connection = $device.days_since_last_connection
            }

            $helpdeskCases += $helpdeskObject
        }
    }

    $helpdeskCases = $helpdeskCases | Sort-Object `
        @{ Expression = { $_.risk_score }; Descending = $true },
        @{ Expression = {
            switch ($_.visual_tag) {
                "critical" { 0 }
                "warning"  { 1 }
                "normal"   { 2 }
                default    { 3 }
            }
        }}

    $helpDeskReportPathCsv = Join-Path $ReportsPath "helpdesk_report_$date.csv"
    $helpDeskReportPathJson = Join-Path $ReportsPath "helpdesk_report_$date.json"

    $helpdeskCases | Export-Csv -Path $helpDeskReportPathCsv -NoTypeInformation -Delimiter ";"
    $helpdeskCases | ConvertTo-Json -Depth 10 | Out-File -FilePath $helpDeskReportPathJson -Encoding UTF8

    # =================================================
    # ENTRA-ONLY DEVICES REPORT
    # =================================================
    $onlyEntraDevices = $ConsolidatedDevices | Where-Object {
        $_.match_status -eq "present_in_entra"
    }

    $onlyEntraDevicesPath = Join-Path $ReportsPath "entra_only_devices_$date.json"

    $onlyEntraDevicesFile = [PSCustomObject]@{
        generated_at = $date
        total_devices = $onlyEntraDevices.Count
        summary = [PSCustomObject]@{
            total_devices             = $onlyEntraDevices.Count
            managed_in_intune         = @($onlyEntraDevices | Where-Object { $_.is_managed_in_intune -eq $true }).Count
            not_managed_in_intune     = @($onlyEntraDevices | Where-Object { $_.is_managed_in_intune -eq $false }).Count
            noncompliant_devices      = @($onlyEntraDevices | Where-Object { $_.is_noncompliant -eq $true }).Count
            workplace_devices         = @($onlyEntraDevices | Where-Object { $_.entra_trust_type -eq "Workplace" }).Count
            inactive_devices_30d_plus = @($onlyEntraDevices | Where-Object {
                $null -ne $_.days_since_last_connection -and $_.days_since_last_connection -gt 30
            }).Count
        }
        records = $onlyEntraDevices
    }

    $onlyEntraDevicesFile | ConvertTo-Json -Depth 10 | Out-File -FilePath $onlyEntraDevicesPath -Encoding UTF8

    # =================================================
    # PROBABLE PRIVATE BYOD NOT REGISTERED IN ENTRA
    # =================================================
    $probablePrivateByodDevices = $ConsolidatedDevices | Where-Object {
        $_.issues -contains "probable_private_byod_not_registered_in_entra"
    }

    $probablePrivateByodPath = Join-Path $ReportsPath "probable_private_byod_not_registered_in_entra_$date.json"

    $probablePrivateByodFile = [PSCustomObject]@{
        generated_at = $date
        total_devices = $probablePrivateByodDevices.Count
        summary = [PSCustomObject]@{
            total_devices             = $probablePrivateByodDevices.Count
            recent_activity_devices   = @($probablePrivateByodDevices | Where-Object { $_.recent_activity -eq $true }).Count
            inactive_devices_30d_plus = @($probablePrivateByodDevices | Where-Object {
                $null -ne $_.days_since_last_connection -and $_.days_since_last_connection -gt 30
            }).Count
            duplicate_hostnames       = @($probablePrivateByodDevices | Where-Object { $_.duplicate_hostname -eq $true }).Count
        }
        records = $probablePrivateByodDevices
    }

    $probablePrivateByodFile | ConvertTo-Json -Depth 10 | Out-File -FilePath $probablePrivateByodPath -Encoding UTF8

    # =================================================
    # ENRICHED INTUNE EXPORT
    # =================================================
    # Sort Intune devices to make compliance problems appear first.
    # -------------------------------------------------
    $sortedCleanExport = $CleanExport | Sort-Object @{
        Expression = {
            switch ($_.COMPLIANCE) {
                "noncompliant"  { 0 }
                "inGracePeriod" { 1 }
                "configManager" { 2 }
                default         { 3 }
            }
        }
    }

    $intuneExportPath = Join-Path $ProcessedDataPath "BYOD_Intune_ManagedDevices_$date.csv"
    $sortedCleanExport | Export-Csv -Path $intuneExportPath -NoTypeInformation -Delimiter ";"

    Write-Host "[OK] Reports exported" -ForegroundColor Green

    return [PSCustomObject]@{
        FullJsonDataset         = $fullJsonDataset
        FullJsonPath            = $fullJsonPath
        HelpdeskCases           = $helpdeskCases
        HelpDeskReportPathCsv   = $helpDeskReportPathCsv
        HelpDeskReportPathJson  = $helpDeskReportPathJson
        IntuneExportPath        = $intuneExportPath
        EntraOnlyReportPath     = $onlyEntraDevicesPath
        ProbablePrivateByodPath = $probablePrivateByodPath
    }
}