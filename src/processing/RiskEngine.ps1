# =====================================================
# RISK ENGINE - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

function Add-RiskIssue {
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

    switch ($RiskLevel.ToLower()) {
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

    if ($RiskLevel -eq "critical") {
        if ($issues -contains "defender_alert_present") {
            return "Investigate this device immediately, review the Defender alert, confirm ownership, and validate containment or remediation actions."
        }

        if ($issues -contains "active_unpatched_device") {
            return "Prioritize patch remediation immediately and validate exposure, management status, and device ownership."
        }

        return "Investigate this device as a priority and validate security visibility, management state, and remediation ownership."
    }

    if ($RiskLevel -eq "high") {
        if ($issues -contains "missing_security_updates") {
            return "Review missing KBs, confirm patch scope, and schedule remediation as soon as possible."
        }

        if ($issues -contains "registered_not_managed") {
            return "Confirm whether this device should be managed and decide whether to enroll, restrict, or monitor it more closely."
        }

        return "Review the identified security and management gaps and assign remediation actions."
    }

    if ($RiskLevel -eq "warning") {
        if ($issues -contains "defender_visibility_gap") {
            return "Check why the device is visible in one security source but not consistently in Defender."
        }

        if ($issues -contains "probable_private_byod") {
            return "Validate whether this device is an expected BYOD case and whether policy coverage is sufficient."
        }

        return "Review the device during normal operational follow-up and validate whether the identified gaps are expected."
    }

    return "No urgent action required. Keep this device under standard monitoring."
}

function Invoke-RiskEngine {
    param (
        [Parameter(Mandatory)]
        [array]$Devices
    )

    $scoredDevices = @()

    foreach ($device in $Devices) {
        $score = 0
        $riskTags = New-Object System.Collections.Generic.List[string]

        $issues = @($device.issues)

        if ($device.has_defender_alert) {
            $score += 45
            Add-RiskIssue -Tags $riskTags -Tag "defender_alert_present"
        }

        if ($device.has_missing_kbs) {
            $score += 20
            Add-RiskIssue -Tags $riskTags -Tag "missing_security_updates"
        }

        if ($device.has_missing_kbs -and $device.defender_machine_active) {
            $score += 15
            Add-RiskIssue -Tags $riskTags -Tag "active_unpatched_device"
        }

        if ($issues -contains "device_noncompliant") {
            $score += 25
            Add-RiskIssue -Tags $riskTags -Tag "device_noncompliant"
        }

        if (($issues -contains "device_noncompliant") -and $device.has_defender_alert) {
            $score += 20
            Add-RiskIssue -Tags $riskTags -Tag "noncompliant_with_security_alert"
        }

        if ($issues -contains "registered_not_managed") {
            $score += 15
            Add-RiskIssue -Tags $riskTags -Tag "registered_not_managed"
        }

        if ($issues -contains "probable_private_byod") {
            $score += 12
            Add-RiskIssue -Tags $riskTags -Tag "probable_private_byod"
        }

        if ($issues -contains "defender_visibility_gap") {
            $score += 10
            Add-RiskIssue -Tags $riskTags -Tag "defender_visibility_gap"
        }

        if ($issues -contains "missing_in_defender") {
            $score += 8
            Add-RiskIssue -Tags $riskTags -Tag "missing_in_defender"
        }

        if ($issues -contains "missing_in_intune") {
            $score += 12
            Add-RiskIssue -Tags $riskTags -Tag "missing_in_intune"
        }

        if ($issues -contains "missing_in_entra") {
            $score += 10
            Add-RiskIssue -Tags $riskTags -Tag "missing_in_entra"
        }

        if ($issues -contains "missing_in_trend") {
            $score += 8
            Add-RiskIssue -Tags $riskTags -Tag "missing_in_trend"
        }

        if ($issues -contains "inactive_defender_device") {
            $score += 10
            Add-RiskIssue -Tags $riskTags -Tag "inactive_defender_device"
        }

        if ($issues -contains "duplicate_hostname") {
            $score += 10
            Add-RiskIssue -Tags $riskTags -Tag "duplicate_hostname"
        }

        if ($device.missing_kb_count -ge 5) {
            $score += 10
            Add-RiskIssue -Tags $riskTags -Tag "multiple_missing_kbs"
        }

        if ($device.match_status -eq "single_source_only") {
            $score += 10
            Add-RiskIssue -Tags $riskTags -Tag "single_source_visibility"
        }

        if ($device.match_status -eq "partial_match_two_sources") {
            $score += 5
            Add-RiskIssue -Tags $riskTags -Tag "partial_visibility"
        }

        if ($device.source_presence.defender -and -not $device.source_presence.intune) {
            $score += 8
            Add-RiskIssue -Tags $riskTags -Tag "security_visibility_without_management"
        }

        if ($device.source_presence.trend -and -not $device.source_presence.defender) {
            $score += 6
            Add-RiskIssue -Tags $riskTags -Tag "trend_without_defender_visibility"
        }

        if ($score -gt 100) {
            $score = 100
        }

        $riskLevel = Get-RiskLevelFromScore -Score $score
        $visualTag = Get-VisualTagFromRiskLevel -RiskLevel $riskLevel
        $recommendedAction = Get-RecommendedAction -Device $device -RiskLevel $riskLevel

        $scoredDevices += [PSCustomObject]@{
            device_name                = $device.device_name
            primary_user               = $device.primary_user
            aad_device_id              = $device.aad_device_id
            device_os                  = $device.device_os
            device_os_version          = $device.device_os_version

            has_trend                  = $device.has_trend
            has_entra                  = $device.has_entra
            has_intune                 = $device.has_intune
            has_defender_alert         = $device.has_defender_alert
            has_defender_machine       = $device.has_defender_machine
            has_defender_hunting       = $device.has_defender_hunting
            has_missing_kbs            = $device.has_missing_kbs

            source_presence            = $device.source_presence
            match_status               = $device.match_status
            defender_visibility_status = $device.defender_visibility_status

            intune_compliance_state    = $device.intune_compliance_state
            entra_trust_type           = $device.entra_trust_type
            defender_onboarding_status = $device.defender_onboarding_status
            defender_machine_active    = $device.defender_machine_active

            missing_kb_count           = $device.missing_kb_count
            missing_kb_ids             = $device.missing_kb_ids
            missing_kb_names           = $device.missing_kb_names

            duplicate_hostname         = $device.duplicate_hostname
            duplicate_hostname_count   = $device.duplicate_hostname_count

            issues                     = $device.issues
            risk_tags                  = @($riskTags)
            risk_score                 = $score
            risk_level                 = $riskLevel
            visual_tag                 = $visualTag
            recommended_action         = $recommendedAction

            trend_data                 = $device.trend_data
            entra_data                 = $device.entra_data
            intune_data                = $device.intune_data
            defender_alerts            = $device.defender_alerts
            defender_machines          = $device.defender_machines
            defender_hunting           = $device.defender_hunting
            defender_missing_kbs       = $device.defender_missing_kbs
        }
    }

    Write-Log "Risk engine completed: $($scoredDevices.Count) devices scored"
    return @($scoredDevices | Sort-Object risk_score -Descending, device_name)
}