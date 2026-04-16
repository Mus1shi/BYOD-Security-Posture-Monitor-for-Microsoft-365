# =====================================================
# RISK ENGINE - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

function Add-RiskTag {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[string]]$Tags,

        [Parameter(Mandatory)]
        [string]$Tag
    )

    if (-not [string]::IsNullOrWhiteSpace($Tag) -and -not $Tags.Contains($Tag)) {
        [void]$Tags.Add($Tag)
    }
}

function Get-RiskLevelFromScore {
    param (
        [Parameter(Mandatory)]
        [int]$Score
    )

    if ($Score -ge 90) { return "critical" }
    if ($Score -ge 70) { return "high" }
    if ($Score -ge 40) { return "warning" }
    return "normal"
}

function Get-VisualTagFromRiskLevel {
    param (
        [Parameter(Mandatory)]
        [string]$RiskLevel
    )

    switch ($RiskLevel.ToLowerInvariant()) {
        "critical" { return "critical" }
        "high"     { return "danger" }
        "warning"  { return "warning" }
        default    { return "normal" }
    }
}

function Get-RecommendedAction {
    param (
        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        [string]$RiskLevel
    )

    $issues = @($Device.issues)

    switch ($RiskLevel) {
        "critical" {
            if ($issues -contains "defender_alert_present") {
                return "Investigate immediately. Review the Defender alert, validate device ownership, confirm current exposure, and trigger containment or remediation if required."
            }

            if ($issues -contains "active_unpatched_device") {
                return "Prioritize patch remediation immediately. Confirm the missing KB scope, validate management ownership, and reduce exposure without delay."
            }

            return "Investigate this device as a priority. Validate security visibility, management state, ownership, and remediation path."
        }

        "high" {
            if ($issues -contains "missing_security_updates") {
                return "Review missing security updates, confirm which KBs are missing, and schedule remediation as soon as possible."
            }

            if ($issues -contains "registered_not_managed") {
                return "Confirm whether this device should be managed. Enroll it, restrict it, or monitor it more closely depending on policy."
            }

            return "Review the identified security and management gaps and assign clear remediation ownership."
        }

        "warning" {
            if ($issues -contains "defender_visibility_gap") {
                return "Check why this device is visible in one security source but not consistently represented in Defender."
            }

            if ($issues -contains "probable_private_byod") {
                return "Validate whether this is an expected BYOD case and whether policy coverage is sufficient."
            }

            return "Review the device during normal operational follow-up and confirm whether the identified gaps are expected."
        }

        default {
            return "No urgent action required. Keep this device under standard monitoring."
        }
    }
}

function Get-RiskScoreResult {
    param (
        [Parameter(Mandatory)]
        $Device
    )

    $score = 0
    $riskTags = New-Object System.Collections.Generic.List[string]
    $issues = @($Device.issues)

    if ($Device.has_defender_alert) {
        $score += 45
        Add-RiskTag -Tags $riskTags -Tag "defender_alert_present"
    }

    if ($Device.has_missing_kbs) {
        $score += 20
        Add-RiskTag -Tags $riskTags -Tag "missing_security_updates"
    }

    if ($Device.has_missing_kbs -and $Device.defender_machine_active) {
        $score += 15
        Add-RiskTag -Tags $riskTags -Tag "active_unpatched_device"
    }

    if ($issues -contains "device_noncompliant") {
        $score += 25
        Add-RiskTag -Tags $riskTags -Tag "device_noncompliant"
    }

    if (($issues -contains "device_noncompliant") -and $Device.has_defender_alert) {
        $score += 20
        Add-RiskTag -Tags $riskTags -Tag "noncompliant_with_security_alert"
    }

    if ($issues -contains "registered_not_managed") {
        $score += 15
        Add-RiskTag -Tags $riskTags -Tag "registered_not_managed"
    }

    if ($issues -contains "probable_private_byod") {
        $score += 12
        Add-RiskTag -Tags $riskTags -Tag "probable_private_byod"
    }

    if ($issues -contains "defender_visibility_gap") {
        $score += 10
        Add-RiskTag -Tags $riskTags -Tag "defender_visibility_gap"
    }

    if ($issues -contains "missing_in_defender") {
        $score += 8
        Add-RiskTag -Tags $riskTags -Tag "missing_in_defender"
    }

    if ($issues -contains "missing_in_intune") {
        $score += 12
        Add-RiskTag -Tags $riskTags -Tag "missing_in_intune"
    }

    if ($issues -contains "missing_in_entra") {
        $score += 10
        Add-RiskTag -Tags $riskTags -Tag "missing_in_entra"
    }

    if ($issues -contains "missing_in_trend") {
        $score += 8
        Add-RiskTag -Tags $riskTags -Tag "missing_in_trend"
    }

    if ($issues -contains "inactive_defender_device") {
        $score += 10
        Add-RiskTag -Tags $riskTags -Tag "inactive_defender_device"
    }

    if ($issues -contains "duplicate_hostname") {
        $score += 10
        Add-RiskTag -Tags $riskTags -Tag "duplicate_hostname"
    }

    if ([int]$Device.missing_kb_count -ge 5) {
        $score += 10
        Add-RiskTag -Tags $riskTags -Tag "multiple_missing_kbs"
    }

    if ($Device.match_status -eq "single_source_only") {
        $score += 10
        Add-RiskTag -Tags $riskTags -Tag "single_source_visibility"
    }

    if ($Device.match_status -eq "partial_match_two_sources") {
        $score += 5
        Add-RiskTag -Tags $riskTags -Tag "partial_visibility"
    }

    if ($Device.source_presence.defender -and -not $Device.source_presence.intune) {
        $score += 8
        Add-RiskTag -Tags $riskTags -Tag "security_visibility_without_management"
    }

    if ($Device.source_presence.trend -and -not $Device.source_presence.defender) {
        $score += 6
        Add-RiskTag -Tags $riskTags -Tag "trend_without_defender_visibility"
    }

    if ($score -gt 100) {
        $score = 100
    }

    $riskLevel = Get-RiskLevelFromScore -Score $score
    $visualTag = Get-VisualTagFromRiskLevel -RiskLevel $riskLevel
    $recommendedAction = Get-RecommendedAction -Device $Device -RiskLevel $riskLevel

    return [PSCustomObject]@{
        risk_score         = $score
        risk_level         = $riskLevel
        visual_tag         = $visualTag
        risk_tags          = @($riskTags)
        recommended_action = $recommendedAction
    }
}

function Merge-RiskDataIntoDevice {
    param (
        [Parameter(Mandatory)]
        $Device,

        [Parameter(Mandatory)]
        $RiskData
    )

    return [PSCustomObject]@{
        device_name                = $Device.device_name
        primary_user               = $Device.primary_user
        aad_device_id              = $Device.aad_device_id
        device_os                  = $Device.device_os
        device_os_version          = $Device.device_os_version

        has_trend                  = $Device.has_trend
        has_entra                  = $Device.has_entra
        has_intune                 = $Device.has_intune
        has_defender_alert         = $Device.has_defender_alert
        has_defender_machine       = $Device.has_defender_machine
        has_defender_hunting       = $Device.has_defender_hunting
        has_missing_kbs            = $Device.has_missing_kbs

        source_presence            = $Device.source_presence
        match_status               = $Device.match_status
        defender_visibility_status = $Device.defender_visibility_status

        intune_compliance_state    = $Device.intune_compliance_state
        entra_trust_type           = $Device.entra_trust_type
        defender_onboarding_status = $Device.defender_onboarding_status
        defender_machine_active    = $Device.defender_machine_active

        missing_kb_count           = $Device.missing_kb_count
        missing_kb_ids             = $Device.missing_kb_ids
        missing_kb_names           = $Device.missing_kb_names

        duplicate_hostname         = $Device.duplicate_hostname
        duplicate_hostname_count   = $Device.duplicate_hostname_count

        issues                     = $Device.issues
        risk_tags                  = $RiskData.risk_tags
        risk_score                 = $RiskData.risk_score
        risk_level                 = $RiskData.risk_level
        visual_tag                 = $RiskData.visual_tag
        recommended_action         = $RiskData.recommended_action

        trend_data                 = $Device.trend_data
        entra_data                 = $Device.entra_data
        intune_data                = $Device.intune_data
        defender_alerts            = $Device.defender_alerts
        defender_machines          = $Device.defender_machines
        defender_hunting           = $Device.defender_hunting
        defender_missing_kbs       = $Device.defender_missing_kbs
    }
}

function Invoke-RiskEngine {
    param (
        [Parameter(Mandatory)]
        [array]$Devices
    )

    Write-Log "Running risk engine..."

    $scoredDevices = New-Object System.Collections.Generic.List[object]

    foreach ($device in $Devices) {
        $riskData = Get-RiskScoreResult -Device $device
        $scoredDevice = Merge-RiskDataIntoDevice -Device $device -RiskData $riskData
        [void]$scoredDevices.Add($scoredDevice)
    }

    $sortedDevices = @(
        $scoredDevices |
        Sort-Object -Property @{ Expression = "risk_score"; Descending = $true }, @{ Expression = "device_name"; Descending = $false }
    )

    Write-Log "Risk engine completed: $($sortedDevices.Count) devices scored" "SUCCESS"
    return $sortedDevices
}