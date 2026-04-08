# =====================================================
# DEVICE CORRELATION - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Correlate Trend, Entra ID, and Intune records into a
# single consolidated device view used for:
# - risk analysis
# - operational reporting
# - helpdesk-oriented outputs
#
# Current matching strategy:
# 1. Trend endpointName -> Entra displayName
# 2. Entra deviceId -> Intune AZURE_AD_DEVICE_ID
#
# Defender enrichment is intentionally excluded for now
# in the public demo version.
# =====================================================

function New-ConsolidatedDevices {
    param (
        [array]$TrendDevices,
        [array]$EntraAll,
        [hashtable]$EntraByDisplayName,
        [hashtable]$IntuneByDeviceId
    )

    Write-Host "[STEP] Starting device correlation (Trend ↔ Entra ↔ Intune)" -ForegroundColor Cyan

    $consolidatedDevices = @()
    $processedEntraIds = @{}

    # =====================================================
    # FIRST PASS - TREND-BASED CORRELATION
    # =====================================================
    foreach ($device in $TrendDevices) {

        $entraMatch = $null
        $intuneMatch = $null
        $matchReason = $null
        $matchStatus = $null
        $aadDeviceId = $null

        if (
            $device.endpointName -and
            $EntraByDisplayName -and
            $EntraByDisplayName.ContainsKey($device.endpointName)
        ) {
            $entraMatch = $EntraByDisplayName[$device.endpointName]
        }

        if ($entraMatch) {
            if (
                $entraMatch.deviceId -and
                $IntuneByDeviceId -and
                $IntuneByDeviceId.ContainsKey($entraMatch.deviceId)
            ) {
                $intuneMatch = $IntuneByDeviceId[$entraMatch.deviceId]
            }

            if ($intuneMatch) {
                $matchStatus = "matched"
                $matchReason = "full_match_name_then_deviceid"
            }
            else {
                $matchStatus = "partial"
                $matchReason = "entra_match_only_on_name"
            }
        }
        else {
            $matchStatus = "unmatched"
            $matchReason = "trend_only_no_entra_match"
        }

        if ($entraMatch -and $entraMatch.deviceId) {
            $aadDeviceId = $entraMatch.deviceId
            $processedEntraIds[$entraMatch.deviceId] = $true
        }

        $consolidatedObject = [PSCustomObject]@{
            primary_user               = if ($intuneMatch -and $intuneMatch.USER) { $intuneMatch.USER } elseif ($device.lastLoggedOnUser) { $device.lastLoggedOnUser } else { "unknown" }
            device_name                = if ($device.endpointName) { $device.endpointName } elseif ($entraMatch -and $entraMatch.displayName) { $entraMatch.displayName } elseif ($intuneMatch -and $intuneMatch.DEVICE) { $intuneMatch.DEVICE } else { "unknown" }
            device_os                  = if ($device.osName) { $device.osName } elseif ($intuneMatch -and $intuneMatch.OS) { $intuneMatch.OS } elseif ($entraMatch -and $entraMatch.operatingSystem) { $entraMatch.operatingSystem } else { "unknown" }
            device_os_version          = if ($device.osVersion) { $device.osVersion } elseif ($intuneMatch -and $intuneMatch.OS_VERSION) { $intuneMatch.OS_VERSION } elseif ($entraMatch -and $entraMatch.operatingSystemVersion) { $entraMatch.operatingSystemVersion } else { "unknown" }

            match_status               = $matchStatus
            match_reason               = $matchReason

            issues                     = @()
            visual_tag                 = $null
            risk_score                 = 0
            risk_level                 = $null
            recommended_action         = $null
            is_urgent                  = $false
            priority                   = "normal"

            source_health_status       = "unknown"
            source_health_reason       = "not_evaluated_yet"

            trend_running              = $true
            entra_running              = if ($entraMatch) { $true } else { $false }
            intune_running             = if ($intuneMatch) { $true } else { $false }

            recent_activity            = $false
            days_since_last_connection = $null

            duplicate_hostname         = $false
            duplicate_hostname_count   = 1

            trend_count                = 1
            entra_count                = 0
            intune_count               = 0

            has_trend                  = $true
            has_entra                  = if ($entraMatch) { $true } else { $false }
            has_intune                 = if ($intuneMatch) { $true } else { $false }

            is_registered_in_entra     = if ($entraMatch) { $true } else { $false }
            is_managed_in_intune       = if ($intuneMatch) { $true } else { $false }
            is_noncompliant            = if ($intuneMatch -and $intuneMatch.COMPLIANCE -eq "noncompliant") { $true } else { $false }

            is_inactive_device         = $false
            is_very_inactive_device    = $false

            trend                      = $device
            entra                      = $entraMatch
            intune                     = $intuneMatch

            trend_agent_guid           = if ($device.agentGuid) { $device.agentGuid } else { "unknown" }
            trend_type                 = if ($device.type) { $device.type } else { "unknown" }
            trend_display_name         = if ($device.displayName) { $device.displayName } else { "unknown" }
            trend_endpoint_name        = if ($device.endpointName) { $device.endpointName } else { "unknown" }
            trend_last_connected       = if ($device.lastSeen) { $device.lastSeen } else { "unknown" }
            trend_last_used_ip         = if ($device.lastUsedIp) { $device.lastUsedIp } else { "unknown" }
            trend_ip_addresses         = if ($device.ipAddresses) { $device.ipAddresses } else { @() }
            trend_serial_number        = if ($device.serialNumber) { $device.serialNumber } else { "unknown" }
            trend_os_name              = if ($device.osName) { $device.osName } else { "unknown" }
            trend_os_version           = if ($device.osVersion) { $device.osVersion } else { "unknown" }
            trend_os_architecture      = if ($device.osArchitecture) { $device.osArchitecture } else { "unknown" }
            trend_os_platform          = if ($device.osPlatform) { $device.osPlatform } else { "unknown" }
            trend_cpu_architecture     = if ($device.cpuArchitecture) { $device.cpuArchitecture } else { "unknown" }
            trend_isolation_status     = if ($device.isolationStatus) { $device.isolationStatus } else { "unknown" }
            trend_service_gateway      = if ($device.serviceGatewayOrProxy) { $device.serviceGatewayOrProxy } else { "unknown" }
            trend_version_policy       = if ($device.versionControlPolicy) { $device.versionControlPolicy } else { "unknown" }
            trend_agent_update_status  = if ($device.agentUpdateStatus) { $device.agentUpdateStatus } else { "unknown" }
            trend_agent_update_policy  = if ($device.agentUpdatePolicy) { $device.agentUpdatePolicy } else { "unknown" }
            trend_security_policy      = if ($device.securityPolicy) { $device.securityPolicy } else { "unknown" }
            trend_security_override    = if ($device.securityPolicyOverriddenStatus) { $device.securityPolicyOverriddenStatus } else { "unknown" }
            trend_last_logged_on_user  = if ($device.lastLoggedOnUser) { $device.lastLoggedOnUser } else { "unknown" }

            entra_device_id                = if ($entraMatch -and $entraMatch.deviceId) { $entraMatch.deviceId } else { "unknown" }
            entra_display_name             = if ($entraMatch -and $entraMatch.displayName) { $entraMatch.displayName } else { "unknown" }
            entra_trust_type               = if ($entraMatch -and $entraMatch.trustType) { $entraMatch.trustType } else { "unknown" }
            entra_operating_system         = if ($entraMatch -and $entraMatch.operatingSystem) { $entraMatch.operatingSystem } else { "unknown" }
            entra_operating_system_version = if ($entraMatch -and $entraMatch.operatingSystemVersion) { $entraMatch.operatingSystemVersion } else { "unknown" }
            entra_last_signin              = if ($entraMatch -and $entraMatch.approximateLastSignInDateTime) { $entraMatch.approximateLastSignInDateTime } else { "unknown" }
            entra_account_enabled          = if ($entraMatch -and $null -ne $entraMatch.accountEnabled) { $entraMatch.accountEnabled } else { $false }

            intune_device_id               = if ($intuneMatch -and $intuneMatch.INTUNE_DEVICE_ID) { $intuneMatch.INTUNE_DEVICE_ID } else { "unknown" }
            intune_azure_ad_device_id      = if ($intuneMatch -and $intuneMatch.AZURE_AD_DEVICE_ID) { $intuneMatch.AZURE_AD_DEVICE_ID } else { "unknown" }
            intune_device_name             = if ($intuneMatch -and $intuneMatch.DEVICE) { $intuneMatch.DEVICE } else { "unknown" }
            intune_user                    = if ($intuneMatch -and $intuneMatch.USER) { $intuneMatch.USER } else { "unknown" }
            intune_compliance_state        = if ($intuneMatch -and $intuneMatch.COMPLIANCE) { $intuneMatch.COMPLIANCE } else { "unknown" }
            intune_serial_number           = if ($intuneMatch -and $intuneMatch.SERIAL_NUMBER) { $intuneMatch.SERIAL_NUMBER } else { "unknown" }
            intune_os                      = if ($intuneMatch -and $intuneMatch.OS) { $intuneMatch.OS } else { "unknown" }
            intune_os_version              = if ($intuneMatch -and $intuneMatch.OS_VERSION) { $intuneMatch.OS_VERSION } else { "unknown" }
            intune_last_sync               = if ($intuneMatch -and $intuneMatch.LAST_SYNC) { $intuneMatch.LAST_SYNC } else { "unknown" }
            intune_enrolled_date           = if ($intuneMatch -and $intuneMatch.ENROLLED_DATE) { $intuneMatch.ENROLLED_DATE } else { "unknown" }
            intune_ownership               = if ($intuneMatch -and $intuneMatch.OWNERSHIP_INTUNE) { $intuneMatch.OWNERSHIP_INTUNE } else { "unknown" }
            intune_entra_trust_type        = if ($intuneMatch -and $intuneMatch.ENTRA_TRUST_TYPE) { $intuneMatch.ENTRA_TRUST_TYPE } else { "unknown" }
        }

        if ($consolidatedObject.trend_running -and $consolidatedObject.entra_running -and $consolidatedObject.intune_running) {
            $consolidatedObject.source_health_status = "fully_visible"
            $consolidatedObject.source_health_reason = "present_in_trend_entra_intune"
        }
        elseif ($consolidatedObject.trend_running -and $consolidatedObject.entra_running -and -not $consolidatedObject.intune_running) {
            $consolidatedObject.source_health_status = "partially_visible"
            $consolidatedObject.source_health_reason = "present_in_trend_and_entra_but_missing_in_intune"
        }
        elseif ($consolidatedObject.trend_running -and -not $consolidatedObject.entra_running) {
            $consolidatedObject.source_health_status = "source_gap"
            $consolidatedObject.source_health_reason = "present_in_trend_only"
        }
        else {
            $consolidatedObject.source_health_status = "unknown"
            $consolidatedObject.source_health_reason = "unable_to_classify_source_visibility"
        }

        $consolidatedDevices += $consolidatedObject
    }

    # =====================================================
    # SECOND PASS - ENTRA-ONLY DEVICES
    # =====================================================
    foreach ($entraDevice in $EntraAll) {

        if (-not $entraDevice.deviceId) {
            continue
        }

        if ($processedEntraIds.ContainsKey($entraDevice.deviceId)) {
            continue
        }

        $intuneMatch = $null

        if ($IntuneByDeviceId -and $IntuneByDeviceId.ContainsKey($entraDevice.deviceId)) {
            $intuneMatch = $IntuneByDeviceId[$entraDevice.deviceId]
        }

        $consolidatedObjectEntra = [PSCustomObject]@{
            primary_user               = if ($intuneMatch -and $intuneMatch.USER) { $intuneMatch.USER } else { "unknown" }
            device_name                = if ($entraDevice.displayName) { $entraDevice.displayName } else { "unknown" }
            device_os                  = if ($entraDevice.operatingSystem) { $entraDevice.operatingSystem } else { "unknown" }
            device_os_version          = if ($entraDevice.operatingSystemVersion) { $entraDevice.operatingSystemVersion } else { "unknown" }

            match_status               = "present_in_entra"
            match_reason               = "absent_in_trend"

            issues                     = @()
            visual_tag                 = "normal"
            risk_score                 = 0
            risk_level                 = "low"
            recommended_action         = "no_action"
            is_urgent                  = $false
            priority                   = "normal"

            source_health_status       = "unknown"
            source_health_reason       = "not_evaluated_yet"

            trend_running              = $false
            entra_running              = $true
            intune_running             = if ($intuneMatch) { $true } else { $false }

            recent_activity            = $false
            days_since_last_connection = $null

            duplicate_hostname         = $false
            duplicate_hostname_count   = 1

            is_inactive_device         = $false
            is_very_inactive_device    = $false

            trend_count                = 0
            entra_count                = 1
            intune_count               = if ($intuneMatch) { 1 } else { 0 }

            has_trend                  = $false
            has_entra                  = $true
            has_intune                 = if ($intuneMatch) { $true } else { $false }

            is_registered_in_entra     = $true
            is_managed_in_intune       = if ($intuneMatch) { $true } else { $false }
            is_noncompliant            = if ($intuneMatch -and $intuneMatch.COMPLIANCE -eq "noncompliant") { $true } else { $false }

            trend                      = $null
            entra                      = $entraDevice
            intune                     = $intuneMatch

            trend_agent_guid           = "unknown"
            trend_type                 = "unknown"
            trend_display_name         = "unknown"
            trend_endpoint_name        = "unknown"
            trend_last_connected       = "unknown"
            trend_last_used_ip         = "unknown"
            trend_ip_addresses         = @()
            trend_serial_number        = "unknown"
            trend_os_name              = "unknown"
            trend_os_version           = "unknown"
            trend_os_architecture      = "unknown"
            trend_os_platform          = "unknown"
            trend_cpu_architecture     = "unknown"
            trend_isolation_status     = "unknown"
            trend_service_gateway      = "unknown"
            trend_version_policy       = "unknown"
            trend_agent_update_status  = "unknown"
            trend_agent_update_policy  = "unknown"
            trend_security_policy      = "unknown"
            trend_security_override    = "unknown"
            trend_last_logged_on_user  = "unknown"

            entra_device_id                = if ($entraDevice.deviceId) { $entraDevice.deviceId } else { "unknown" }
            entra_display_name             = if ($entraDevice.displayName) { $entraDevice.displayName } else { "unknown" }
            entra_trust_type               = if ($entraDevice.trustType) { $entraDevice.trustType } else { "unknown" }
            entra_operating_system         = if ($entraDevice.operatingSystem) { $entraDevice.operatingSystem } else { "unknown" }
            entra_operating_system_version = if ($entraDevice.operatingSystemVersion) { $entraDevice.operatingSystemVersion } else { "unknown" }
            entra_last_signin              = if ($entraDevice.approximateLastSignInDateTime) { $entraDevice.approximateLastSignInDateTime } else { "unknown" }
            entra_account_enabled          = if ($null -ne $entraDevice.accountEnabled) { $entraDevice.accountEnabled } else { $false }

            intune_device_id               = if ($intuneMatch -and $intuneMatch.INTUNE_DEVICE_ID) { $intuneMatch.INTUNE_DEVICE_ID } else { "unknown" }
            intune_azure_ad_device_id      = if ($intuneMatch -and $intuneMatch.AZURE_AD_DEVICE_ID) { $intuneMatch.AZURE_AD_DEVICE_ID } else { "unknown" }
            intune_device_name             = if ($intuneMatch -and $intuneMatch.DEVICE) { $intuneMatch.DEVICE } else { "unknown" }
            intune_user                    = if ($intuneMatch -and $intuneMatch.USER) { $intuneMatch.USER } else { "unknown" }
            intune_compliance_state        = if ($intuneMatch -and $intuneMatch.COMPLIANCE) { $intuneMatch.COMPLIANCE } else { "unknown" }
            intune_serial_number           = if ($intuneMatch -and $intuneMatch.SERIAL_NUMBER) { $intuneMatch.SERIAL_NUMBER } else { "unknown" }
            intune_os                      = if ($intuneMatch -and $intuneMatch.OS) { $intuneMatch.OS } else { "unknown" }
            intune_os_version              = if ($intuneMatch -and $intuneMatch.OS_VERSION) { $intuneMatch.OS_VERSION } else { "unknown" }
            intune_enrolled_date           = if ($intuneMatch -and $intuneMatch.ENROLLED_DATE) { $intuneMatch.ENROLLED_DATE } else { "unknown" }
            intune_last_sync               = if ($intuneMatch -and $intuneMatch.LAST_SYNC) { $intuneMatch.LAST_SYNC } else { "unknown" }
            intune_ownership               = if ($intuneMatch -and $intuneMatch.OWNERSHIP_INTUNE) { $intuneMatch.OWNERSHIP_INTUNE } else { "unknown" }
            intune_entra_trust_type        = if ($intuneMatch -and $intuneMatch.ENTRA_TRUST_TYPE) { $intuneMatch.ENTRA_TRUST_TYPE } else { "unknown" }
        }

        if ($consolidatedObjectEntra.entra_running -and $consolidatedObjectEntra.intune_running) {
            $consolidatedObjectEntra.source_health_status = "entra_visible_only"
            $consolidatedObjectEntra.source_health_reason = "present_in_entra_and_intune_without_trend"
        }
        elseif ($consolidatedObjectEntra.entra_running -and -not $consolidatedObjectEntra.intune_running) {
            $consolidatedObjectEntra.source_health_status = "entra_visible_only"
            $consolidatedObjectEntra.source_health_reason = "present_in_entra_without_trend"
        }
        else {
            $consolidatedObjectEntra.source_health_status = "unknown"
            $consolidatedObjectEntra.source_health_reason = "unable_to_classify_source_visibility"
        }

        $consolidatedDevices += $consolidatedObjectEntra
    }

    $devicesMatched = $consolidatedDevices | Where-Object { $_.match_status -eq "matched" }
    $devicesPartial = $consolidatedDevices | Where-Object { $_.match_status -eq "partial" }
    $devicesUnmatched = $consolidatedDevices | Where-Object { $_.match_status -eq "unmatched" }

    Write-Host "[OK] Correlation completed: $($consolidatedDevices.Count) devices processed" -ForegroundColor Green

    return [PSCustomObject]@{
        ConsolidatedDevices = $consolidatedDevices
        DevicesMatched      = $devicesMatched
        DevicesPartial      = $devicesPartial
        DevicesUnmatched    = $devicesUnmatched
    }
}