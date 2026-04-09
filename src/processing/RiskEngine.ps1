# =====================================================
# RISK ENGINE - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Build device match counters, detect duplicate hostnames,
# assign issues / visual tags / actions, and calculate the
# final risk score and risk level.
# =====================================================

function Invoke-RiskEngine {
    param (
        [array]$ConsolidatedDevices
    )

    Write-Host "[STEP] Running risk engine" -ForegroundColor Cyan

    # =====================================================
    # DUPLICATE HOSTNAME DETECTION
    # =====================================================
    $duplicateHostnames = $ConsolidatedDevices | Group-Object device_name | Where-Object { $_.Count -gt 1 }
    $duplicateHostnamesByName = @{}

    foreach ($group in $duplicateHostnames) {
        $duplicateHostnamesByName[$group.Name] = $group.Count
    }

    foreach ($device in $ConsolidatedDevices) {
        if ($duplicateHostnamesByName.ContainsKey($device.device_name)) {
            $device.duplicate_hostname = $true
            $device.duplicate_hostname_count = $duplicateHostnamesByName[$device.device_name]
        }
        else {
            $device.duplicate_hostname = $false
            $device.duplicate_hostname_count = 1
        }
    }

    # =====================================================
    # SOURCE PRESENCE COUNTERS
    # =====================================================
    $deviceNameStats = @{}

    foreach ($device in $ConsolidatedDevices) {
        $name = $device.device_name

        if (-not $deviceNameStats.ContainsKey($name)) {
            $deviceNameStats[$name] = [PSCustomObject]@{
                trend_count  = 0
                entra_count  = 0
                intune_count = 0
            }
        }

        if ($device.has_trend)  { $deviceNameStats[$name].trend_count++ }
        if ($device.has_entra)  { $deviceNameStats[$name].entra_count++ }
        if ($device.has_intune) { $deviceNameStats[$name].intune_count++ }
    }

    foreach ($device in $ConsolidatedDevices) {
        $currentDeviceName = $device.device_name

        if ($deviceNameStats.ContainsKey($currentDeviceName)) {
            $device.trend_count  = $deviceNameStats[$currentDeviceName].trend_count
            $device.entra_count  = $deviceNameStats[$currentDeviceName].entra_count
            $device.intune_count = $deviceNameStats[$currentDeviceName].intune_count
        }
        else {
            $device.trend_count  = 0
            $device.entra_count  = 0
            $device.intune_count = 0
        }
    }

    # =====================================================
    # RISK CLASSIFICATION RULES
    # =====================================================
    foreach ($device in $ConsolidatedDevices) {

        # =====================================================
        # GLOBAL LAST ACTIVITY (MULTI-SOURCE)
        # =====================================================
        $lastDates = @()

        if ($device.trend_last_connected -and $device.trend_last_connected -ne "unknown") {
            try { $lastDates += [datetime]$device.trend_last_connected } catch {}
        }

        if ($device.entra_last_signin -and $device.entra_last_signin -ne "unknown") {
            try { $lastDates += [datetime]$device.entra_last_signin } catch {}
        }

        if ($device.intune_last_sync -and $device.intune_last_sync -ne "unknown") {
            try { $lastDates += [datetime]$device.intune_last_sync } catch {}
        }

        $latestActivity = $null

        if ($lastDates.Count -gt 0) {
            $latestActivity = ($lastDates | Sort-Object -Descending)[0]
        }

        $isRecentActivity = $false
        $daysSinceLastConnection = $null
        $isInactiveDevice = $false
        $isVeryInactiveDevice = $false

        if ($latestActivity) {
            $daysSinceLastConnection = ((Get-Date) - $latestActivity).Days

            if ($daysSinceLastConnection -le 30) { $isRecentActivity = $true }
            if ($daysSinceLastConnection -gt 30) { $isInactiveDevice = $true }
            if ($daysSinceLastConnection -gt 90) { $isVeryInactiveDevice = $true }
        }

        $device.recent_activity = $isRecentActivity
        $device.days_since_last_connection = $daysSinceLastConnection
        $device.is_inactive_device = $isInactiveDevice
        $device.is_very_inactive_device = $isVeryInactiveDevice

        $device.issues = @()
        $device.visual_tag = $null
        $device.recommended_action = $null
        $device.is_urgent = $false
        $device.priority = "normal"

        if ($device.match_status -eq "unmatched") {

            $byodLikelihoodScore = 0

            if (
                $device.trend_last_logged_on_user -and
                $device.trend_last_logged_on_user -ne "unknown" -and
                -not [string]::IsNullOrWhiteSpace($device.trend_last_logged_on_user)
            ) {
                $byodLikelihoodScore++
            }

            if ($device.trend_type -match "endpoint|desktop|laptop|notebook|workstation") {
                $byodLikelihoodScore++
            }

            if (
                $device.device_os -match "Windows|macOS|iOS|Android" -and
                $device.device_os -notmatch "Server"
            ) {
                $byodLikelihoodScore++
            }

            if ($device.recent_activity -eq $true) {
                $byodLikelihoodScore++
            }

            if (
                $device.device_name -and
                $device.device_name -ne "unknown" -and
                $device.device_name -notmatch "^(PC-|LAP-|SRV-|ADM-|CORP-|VDI-|DESK-|WIN-)"
            ) {
                $byodLikelihoodScore++
            }

            if ($byodLikelihoodScore -ge 3) {
                $device.issues += "probable_private_byod_not_registered_in_entra"
                $device.visual_tag = "critical"
                $device.recommended_action = "Investigate probable personal device not registered in Entra"
            }
            else {
                $device.issues += "not_registered_in_entra"
                $device.visual_tag = "critical"
                $device.recommended_action = "Investigate device origin and tenant registration"
            }
        }
        elseif ($device.intune_compliance_state -eq "noncompliant") {
            $device.issues += "noncompliant_device"
            $device.visual_tag = "critical"
            $device.recommended_action = "Investigate device compliance policy immediately"
            $device.is_urgent = $true
            $device.priority = "urgent"
        }
        elseif (
            $device.entra_trust_type -eq "Workplace" -and
            $device.match_status -ne "present_in_entra" -and
            $device.is_managed_in_intune -eq $false
        ) {
            $device.issues += "byod_workplace"
            $device.visual_tag = "warning"
            $device.recommended_action = "Verify if BYOD usage is expected"
        }
        elseif ($device.match_status -eq "partial") {
            $device.issues += "not_managed_in_intune"
            $device.visual_tag = "warning"
            $device.recommended_action = "Investigate device management status in Intune"
        }

        if ($device.source_health_status -eq "source_gap") {
            if ($device.issues -notcontains "source_gap_visibility") {
                $device.issues += "source_gap_visibility"
            }

            if ($null -eq $device.visual_tag -or $device.visual_tag -eq "normal") {
                $device.visual_tag = "warning"
            }

            if (-not $device.recommended_action) {
                $device.recommended_action = "Review source visibility gap across Trend, Entra, and Intune"
            }
        }

        if ($device.source_health_status -eq "partially_visible") {
            if ($device.issues -notcontains "partial_source_visibility") {
                $device.issues += "partial_source_visibility"
            }

            if ($null -eq $device.visual_tag -or $device.visual_tag -eq "normal") {
                $device.visual_tag = "warning"
            }

            if (-not $device.recommended_action) {
                $device.recommended_action = "Review partial device visibility across security sources"
            }
        }

        if ($device.is_inactive_device -eq $true) {
            if ($device.issues -notcontains "inactive_device") {
                $device.issues += "inactive_device"
            }

            if ($null -eq $device.visual_tag) {
                $device.visual_tag = "warning"
                $device.recommended_action = "Review inactive device and confirm whether it should remain active in the environment"
            }
        }

        if ($device.is_very_inactive_device -eq $true) {
            if ($device.issues -notcontains "very_inactive_device") {
                $device.issues += "very_inactive_device"
            }

            if ($null -eq $device.visual_tag) {
                $device.visual_tag = "warning"
                $device.recommended_action = "Review long-inactive device and consider cleanup or retirement"
            }
        }

        if ($device.is_urgent -ne $true) {
            if ($device.visual_tag -eq "critical") {
                $device.priority = "high"
            }
            elseif ($device.visual_tag -eq "warning") {
                $device.priority = "medium"
            }
            else {
                $device.priority = "normal"
            }
        }

        if ($null -eq $device.visual_tag) {
            $device.visual_tag = "normal"
        }

        if (-not $device.recommended_action -and $device.visual_tag -eq "normal") {
            $device.recommended_action = "no_action"
        }
    }

    # =====================================================
    # RISK SCORING
    # =====================================================
    foreach ($device in $ConsolidatedDevices) {

        $deviceScoreCount = 0
        $riskLevel = $null

        if ($device.match_status -eq "unmatched") { $deviceScoreCount += 50 }
        if ($device.is_noncompliant -eq $true) { $deviceScoreCount += 40 }
        if ($device.match_status -eq "partial") { $deviceScoreCount += 25 }
        if ($device.entra_trust_type -eq "Workplace" -and $device.match_status -ne "present_in_entra") { $deviceScoreCount += 15 }
        if ($device.duplicate_hostname -eq $true) { $deviceScoreCount += 15 }
        if ($device.issues -contains "probable_private_byod_not_registered_in_entra") { $deviceScoreCount += 10 }
        if ($device.issues -contains "inactive_device") { $deviceScoreCount += 10 }
        if ($device.issues -contains "very_inactive_device") { $deviceScoreCount += 15 }
        if ($device.issues -contains "source_gap_visibility") { $deviceScoreCount += 15 }
        if ($device.issues -contains "partial_source_visibility") { $deviceScoreCount += 10 }

        if ($deviceScoreCount -gt 100) { $deviceScoreCount = 100 }

        if ($deviceScoreCount -ge 80) {
            $riskLevel = "critical"
        }
        elseif ($deviceScoreCount -ge 50) {
            $riskLevel = "high"
        }
        elseif ($deviceScoreCount -ge 20) {
            $riskLevel = "medium"
        }
        else {
            $riskLevel = "low"
        }

        $device.risk_score = $deviceScoreCount
        $device.risk_level = $riskLevel
    }

    # =====================================================
    # COUNTERS
    # =====================================================
    $tagCountCritical = @($ConsolidatedDevices | Where-Object { $_.visual_tag -eq "critical" }).Count
    $tagCountWarning = @($ConsolidatedDevices | Where-Object { $_.visual_tag -eq "warning" }).Count
    $tagCountNormal = @($ConsolidatedDevices | Where-Object { $_.visual_tag -eq "normal" }).Count

    $issueNotRegisteredInEntra = @($ConsolidatedDevices | Where-Object { $_.issues -contains "not_registered_in_entra" }).Count
    $issueProbablePrivateByodNotRegistered = @($ConsolidatedDevices | Where-Object { $_.issues -contains "probable_private_byod_not_registered_in_entra" }).Count
    $issueNoncompliantDevice = @($ConsolidatedDevices | Where-Object { $_.issues -contains "noncompliant_device" }).Count
    $issueByodWorkplace = @($ConsolidatedDevices | Where-Object { $_.issues -contains "byod_workplace" }).Count
    $issueNotManagedInIntune = @($ConsolidatedDevices | Where-Object { $_.issues -contains "not_managed_in_intune" }).Count
    $issueInactiveDevice = @($ConsolidatedDevices | Where-Object { $_.issues -contains "inactive_device" }).Count
    $issueVeryInactiveDevice = @($ConsolidatedDevices | Where-Object { $_.issues -contains "very_inactive_device" }).Count

    $riskLevelCritical = @($ConsolidatedDevices | Where-Object { $_.risk_level -eq "critical" }).Count
    $riskLevelHigh = @($ConsolidatedDevices | Where-Object { $_.risk_level -eq "high" }).Count
    $riskLevelMedium = @($ConsolidatedDevices | Where-Object { $_.risk_level -eq "medium" }).Count
    $riskLevelLow = @($ConsolidatedDevices | Where-Object { $_.risk_level -eq "low" }).Count

    Write-Host "[OK] Risk engine completed" -ForegroundColor Green

    return [PSCustomObject]@{
        ConsolidatedDevices                   = $ConsolidatedDevices
        DuplicateHostnameCount                = $duplicateHostnames.Count
        TagCountCritical                      = $tagCountCritical
        TagCountWarning                       = $tagCountWarning
        TagCountNormal                        = $tagCountNormal
        IssueNotRegisteredInEntra             = $issueNotRegisteredInEntra
        IssueProbablePrivateByodNotRegistered = $issueProbablePrivateByodNotRegistered
        IssueNoncompliantDevice               = $issueNoncompliantDevice
        IssueByodWorkplace                    = $issueByodWorkplace
        IssueNotManagedInIntune               = $issueNotManagedInIntune
        IssueInactiveDevice                   = $issueInactiveDevice
        IssueVeryInactiveDevice               = $issueVeryInactiveDevice
        RiskLevelCritical                     = $riskLevelCritical
        RiskLevelHigh                         = $riskLevelHigh
        RiskLevelMedium                       = $riskLevelMedium
        RiskLevelLow                          = $riskLevelLow
    }
}