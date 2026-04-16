# =====================================================
# CORRELATION ENGINE - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

function Normalize-CorrelationKey {
    param (
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return $Value.Trim().ToLowerInvariant()
}

function Get-DeviceNameFromRecord {
    param (
        $Record
    )

    if ($null -eq $Record) {
        return $null
    }

    $candidates = @(
        $Record.device_name,
        $Record.deviceName,
        $Record.displayName,
        $Record.computerDnsName,
        $Record.hostname,
        $Record.DeviceName
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate.Trim()
        }
    }

    return $null
}

function Get-AadDeviceIdFromRecord {
    param (
        $Record
    )

    if ($null -eq $Record) {
        return $null
    }

    $candidates = @(
        $Record.aad_device_id,
        $Record.aadDeviceId,
        $Record.azureADDeviceId,
        $Record.azureAdDeviceId,
        $Record.deviceId,
        $Record.device_id,
        $Record.DeviceId
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate.Trim()
        }
    }

    return $null
}

function Get-PrimaryUserFromRecord {
    param (
        $Record
    )

    if ($null -eq $Record) {
        return $null
    }

    $candidates = @(
        $Record.primary_user,
        $Record.userPrincipalName,
        $Record.user_principal_name,
        $Record.owner,
        $Record.lastLoggedOnUser,
        $Record.email
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate.Trim()
        }
    }

    return $null
}

function Get-PropertyValue {
    param (
        $Record,
        [Parameter(Mandatory)]
        [string[]]$PropertyNames
    )

    if ($null -eq $Record) {
        return $null
    }

    foreach ($propertyName in $PropertyNames) {
        $property = $Record.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $null -ne $property.Value) {
            if ($property.Value -is [string]) {
                if (-not [string]::IsNullOrWhiteSpace($property.Value)) {
                    return $property.Value.Trim()
                }
            }
            else {
                return $property.Value
            }
        }
    }

    return $null
}

function Add-ToLookupIndex {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Index,

        [AllowNull()]
        [string]$Key,

        [Parameter(Mandatory)]
        $Value
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return
    }

    $normalizedKey = Normalize-CorrelationKey -Value $Key

    if (-not $Index.ContainsKey($normalizedKey)) {
        $Index[$normalizedKey] = New-Object System.Collections.Generic.List[object]
    }

    [void]$Index[$normalizedKey].Add($Value)
}

function New-RecordIndex {
    param (
        [Parameter(Mandatory)]
        [array]$Records
    )

    $index = [PSCustomObject]@{
        ByName        = @{}
        ByAadDeviceId = @{}
    }

    foreach ($record in $Records) {
        $deviceName = Get-DeviceNameFromRecord -Record $record
        $aadDeviceId = Get-AadDeviceIdFromRecord -Record $record

        Add-ToLookupIndex -Index $index.ByName -Key $deviceName -Value $record
        Add-ToLookupIndex -Index $index.ByAadDeviceId -Key $aadDeviceId -Value $record
    }

    return $index
}

function Get-IndexedRecords {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Index,

        [AllowNull()]
        [string]$Key
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return @()
    }

    $normalizedKey = Normalize-CorrelationKey -Value $Key

    if ($Index.ContainsKey($normalizedKey)) {
        return @($Index[$normalizedKey])
    }

    return @()
}

function Get-FirstMeaningfulValue {
    param (
        [Parameter(Mandatory)]
        [object[]]$Values
    )

    foreach ($value in $Values) {
        if ($null -eq $value) {
            continue
        }

        if ($value -is [array]) {
            foreach ($item in $value) {
                if ($null -eq $item) {
                    continue
                }

                if ($item -is [string]) {
                    if (-not [string]::IsNullOrWhiteSpace($item)) {
                        return $item.Trim()
                    }
                }
                else {
                    return $item
                }
            }
        }
        else {
            if ($value -is [string]) {
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value.Trim()
                }
            }
            else {
                return $value
            }
        }
    }

    return $null
}

function Get-UniqueStringValues {
    param (
        [Parameter(Mandatory)]
        [object[]]$Values
    )

    $result = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    foreach ($value in $Values) {
        if ($null -eq $value) {
            continue
        }

        if ($value -is [array]) {
            foreach ($subValue in $value) {
                if ([string]::IsNullOrWhiteSpace([string]$subValue)) {
                    continue
                }

                $clean = ([string]$subValue).Trim()
                $normalized = Normalize-CorrelationKey -Value $clean

                if (-not $seen.ContainsKey($normalized)) {
                    $seen[$normalized] = $true
                    [void]$result.Add($clean)
                }
            }
        }
        else {
            if ([string]::IsNullOrWhiteSpace([string]$value)) {
                continue
            }

            $clean = ([string]$value).Trim()
            $normalized = Normalize-CorrelationKey -Value $clean

            if (-not $seen.ContainsKey($normalized)) {
                $seen[$normalized] = $true
                [void]$result.Add($clean)
            }
        }
    }

    return @($result)
}

function Test-ContainsTrue {
    param (
        [Parameter(Mandatory)]
        [object[]]$Values
    )

    foreach ($value in $Values) {
        if ($value -eq $true) {
            return $true
        }
    }

    return $false
}

function Get-DuplicateHostnameMap {
    param (
        [Parameter(Mandatory)]
        [object[]]$Names
    )

    $counts = @{}

    foreach ($name in $Names) {
        if ([string]::IsNullOrWhiteSpace([string]$name)) {
            continue
        }

        $normalized = Normalize-CorrelationKey -Value ([string]$name)
        if (-not $counts.ContainsKey($normalized)) {
            $counts[$normalized] = 0
        }

        $counts[$normalized]++
    }

    return $counts
}

function Resolve-MatchStatus {
    param (
        [Parameter(Mandatory)]
        [bool]$HasTrend,
        [Parameter(Mandatory)]
        [bool]$HasEntra,
        [Parameter(Mandatory)]
        [bool]$HasIntune,
        [Parameter(Mandatory)]
        [bool]$HasDefender
    )

    $trueCount = 0
    foreach ($flag in @($HasTrend, $HasEntra, $HasIntune, $HasDefender)) {
        if ($flag) {
            $trueCount++
        }
    }

    switch ($trueCount) {
        4 { return "full_match_all_sources" }
        3 { return "strong_match_three_sources" }
        2 { return "partial_match_two_sources" }
        default { return "single_source_only" }
    }
}

function Get-DefenderItemsForDevice {
    param (
        $DefenderData,
        [AllowNull()]
        [string]$DeviceName,
        [AllowNull()]
        [string]$AadDeviceId
    )

    if ($null -eq $DefenderData) {
        return @()
    }

    $items = New-Object System.Collections.Generic.List[object]

    foreach ($item in (Get-IndexedRecords -Index $DefenderData.ByDeviceName -Key $DeviceName)) {
        [void]$items.Add($item)
    }

    foreach ($item in (Get-IndexedRecords -Index $DefenderData.ByAadDeviceId -Key $AadDeviceId)) {
        [void]$items.Add($item)
    }

    $uniqueItems = New-Object System.Collections.Generic.List[object]
    $seen = @{}

    foreach ($item in $items) {
        $identityPart = Get-FirstMeaningfulValue -Values @(
            $item.alert_id,
            $item.machine_id,
            $item.kb_id,
            $item.device_id,
            $item.device_name,
            $item.aad_device_id
        )

        $fingerprint = "{0}|{1}" -f $item.source, $identityPart

        if (-not $seen.ContainsKey($fingerprint)) {
            $seen[$fingerprint] = $true
            [void]$uniqueItems.Add($item)
        }
    }

    return @($uniqueItems)
}

function Group-DefenderSignals {
    param (
        [Parameter(Mandatory)]
        [array]$Items
    )

    return [PSCustomObject]@{
        Alerts     = @($Items | Where-Object { $_.source -eq "defender_alert" })
        Machines   = @($Items | Where-Object { $_.source -eq "defender_machine" })
        Hunting    = @($Items | Where-Object { $_.source -eq "defender_hunting" })
        MissingKbs = @($Items | Where-Object { $_.source -eq "defender_missing_kb" })
    }
}

function Build-UnifiedDevice {
    param (
        $TrendRecord,
        [Parameter(Mandatory)]
        [array]$EntraRecords,
        [Parameter(Mandatory)]
        [array]$IntuneRecords,
        [Parameter(Mandatory)]
        [array]$DefenderItems,
        [Parameter(Mandatory)]
        [hashtable]$DuplicateHostnames
    )

    $defenderGroups = Group-DefenderSignals -Items $DefenderItems

    $deviceName = Get-FirstMeaningfulValue -Values @(
        (Get-DeviceNameFromRecord -Record $TrendRecord),
        ($EntraRecords | ForEach-Object { Get-DeviceNameFromRecord -Record $_ }),
        ($IntuneRecords | ForEach-Object { Get-DeviceNameFromRecord -Record $_ }),
        ($DefenderItems | ForEach-Object { Get-DeviceNameFromRecord -Record $_ })
    )

    $aadDeviceId = Get-FirstMeaningfulValue -Values @(
        (Get-AadDeviceIdFromRecord -Record $TrendRecord),
        ($EntraRecords | ForEach-Object { Get-AadDeviceIdFromRecord -Record $_ }),
        ($IntuneRecords | ForEach-Object { Get-AadDeviceIdFromRecord -Record $_ }),
        ($DefenderItems | ForEach-Object { Get-AadDeviceIdFromRecord -Record $_ })
    )

    $primaryUser = Get-FirstMeaningfulValue -Values @(
        (Get-PrimaryUserFromRecord -Record $TrendRecord),
        ($IntuneRecords | ForEach-Object { Get-PrimaryUserFromRecord -Record $_ }),
        ($EntraRecords | ForEach-Object { Get-PrimaryUserFromRecord -Record $_ })
    )

    $deviceOs = Get-FirstMeaningfulValue -Values @(
        (Get-PropertyValue -Record $TrendRecord -PropertyNames @("platform", "operatingSystem")),
        ($IntuneRecords | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("operatingSystem") }),
        ($EntraRecords | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("operatingSystem") }),
        ($defenderGroups.Machines | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("os_platform") })
    )

    $deviceOsVersion = Get-FirstMeaningfulValue -Values @(
        ($IntuneRecords | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("osVersion") }),
        ($EntraRecords | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("operatingSystemVersion") })
    )

    $hasTrend = ($null -ne $TrendRecord)
    $hasEntra = ($EntraRecords.Count -gt 0)
    $hasIntune = ($IntuneRecords.Count -gt 0)
    $hasDefenderAlert = ($defenderGroups.Alerts.Count -gt 0)
    $hasDefenderMachine = ($defenderGroups.Machines.Count -gt 0)
    $hasDefenderHunting = ($defenderGroups.Hunting.Count -gt 0)
    $hasMissingKbs = ($defenderGroups.MissingKbs.Count -gt 0)
    $hasDefender = ($hasDefenderAlert -or $hasDefenderMachine -or $hasDefenderHunting -or $hasMissingKbs)

    $matchStatus = Resolve-MatchStatus `
        -HasTrend $hasTrend `
        -HasEntra $hasEntra `
        -HasIntune $hasIntune `
        -HasDefender $hasDefender

    $normalizedName = Normalize-CorrelationKey -Value $deviceName
    $duplicateHostnameCount = 0
    if ($normalizedName -and $DuplicateHostnames.ContainsKey($normalizedName)) {
        $duplicateHostnameCount = [int]$DuplicateHostnames[$normalizedName]
    }

    $intuneComplianceState = Get-FirstMeaningfulValue -Values @(
        $IntuneRecords | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("complianceState") }
    )

    $entraTrustType = Get-FirstMeaningfulValue -Values @(
        $EntraRecords | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("trustType") }
    )

    $defenderOnboardingStatus = Get-FirstMeaningfulValue -Values @(
        $defenderGroups.Machines | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("onboarding_status") }
    )

    $defenderMachineActive = Test-ContainsTrue -Values @(
        $defenderGroups.Machines | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("is_active") }
    )

    $missingKbIds = Get-UniqueStringValues -Values @(
        $defenderGroups.MissingKbs | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("kb_id") }
    )

    $missingKbNames = Get-UniqueStringValues -Values @(
        $defenderGroups.MissingKbs | ForEach-Object { Get-PropertyValue -Record $_ -PropertyNames @("kb_name") }
    )

    $issues = New-Object System.Collections.Generic.List[string]

    if (-not $hasEntra) { [void]$issues.Add("missing_in_entra") }
    if (-not $hasIntune) { [void]$issues.Add("missing_in_intune") }
    if (-not $hasTrend) { [void]$issues.Add("missing_in_trend") }
    if (-not $hasDefender) { [void]$issues.Add("missing_in_defender") }

    if ($hasDefenderAlert) { [void]$issues.Add("defender_alert_present") }
    if ($hasMissingKbs) { [void]$issues.Add("missing_security_updates") }

    if ($hasTrend -and -not $hasDefenderMachine) {
        [void]$issues.Add("defender_visibility_gap")
    }

    if ($hasEntra -and -not $hasIntune) {
        [void]$issues.Add("registered_not_managed")
    }

    if ($intuneComplianceState -and ($intuneComplianceState -ne "compliant")) {
        [void]$issues.Add("device_noncompliant")
    }

    if ($entraTrustType -eq "Workplace") {
        [void]$issues.Add("probable_private_byod")
    }

    if ($duplicateHostnameCount -gt 1) {
        [void]$issues.Add("duplicate_hostname")
    }

    if ($hasDefenderMachine -and -not $defenderMachineActive) {
        [void]$issues.Add("inactive_defender_device")
    }

    $defenderVisibilityStatus = if ($hasDefender) {
        if ($hasDefenderMachine -and $hasDefenderHunting) {
            "strong_visibility"
        }
        elseif ($hasDefenderAlert -or $hasMissingKbs) {
            "partial_visibility_with_security_signal"
        }
        else {
            "partial_visibility"
        }
    }
    else {
        "no_visibility"
    }

    return [PSCustomObject]@{
        device_name                = $deviceName
        primary_user               = $primaryUser
        aad_device_id              = $aadDeviceId
        device_os                  = $deviceOs
        device_os_version          = $deviceOsVersion

        has_trend                  = $hasTrend
        has_entra                  = $hasEntra
        has_intune                 = $hasIntune
        has_defender_alert         = $hasDefenderAlert
        has_defender_machine       = $hasDefenderMachine
        has_defender_hunting       = $hasDefenderHunting
        has_missing_kbs            = $hasMissingKbs

        source_presence            = [PSCustomObject]@{
            trend    = $hasTrend
            entra    = $hasEntra
            intune   = $hasIntune
            defender = $hasDefender
        }

        match_status               = $matchStatus
        defender_visibility_status = $defenderVisibilityStatus

        intune_compliance_state    = $intuneComplianceState
        entra_trust_type           = $entraTrustType
        defender_onboarding_status = $defenderOnboardingStatus
        defender_machine_active    = $defenderMachineActive

        missing_kb_count           = $missingKbIds.Count
        missing_kb_ids             = $missingKbIds
        missing_kb_names           = $missingKbNames

        duplicate_hostname         = ($duplicateHostnameCount -gt 1)
        duplicate_hostname_count   = $duplicateHostnameCount

        issues                     = @($issues)

        trend_data                 = $TrendRecord
        entra_data                 = @($EntraRecords)
        intune_data                = @($IntuneRecords)
        defender_alerts            = @($defenderGroups.Alerts)
        defender_machines          = @($defenderGroups.Machines)
        defender_hunting           = @($defenderGroups.Hunting)
        defender_missing_kbs       = @($defenderGroups.MissingKbs)
    }
}

function Add-OrUpdateUnifiedDevice {
    param (
        [Parameter(Mandatory)]
        [hashtable]$DeviceMap,
        [Parameter(Mandatory)]
        $UnifiedDevice
    )

    $preferredKey = Get-FirstMeaningfulValue -Values @(
        $UnifiedDevice.aad_device_id,
        $UnifiedDevice.device_name
    )

    if ([string]::IsNullOrWhiteSpace([string]$preferredKey)) {
        $preferredKey = [guid]::NewGuid().ToString()
    }

    $normalizedKey = Normalize-CorrelationKey -Value ([string]$preferredKey)

    if (-not $DeviceMap.ContainsKey($normalizedKey)) {
        $DeviceMap[$normalizedKey] = $UnifiedDevice
        return
    }

    $existing = $DeviceMap[$normalizedKey]

    $existing.issues = @($existing.issues + $UnifiedDevice.issues | Select-Object -Unique)

    $existing.has_trend = ($existing.has_trend -or $UnifiedDevice.has_trend)
    $existing.has_entra = ($existing.has_entra -or $UnifiedDevice.has_entra)
    $existing.has_intune = ($existing.has_intune -or $UnifiedDevice.has_intune)
    $existing.has_defender_alert = ($existing.has_defender_alert -or $UnifiedDevice.has_defender_alert)
    $existing.has_defender_machine = ($existing.has_defender_machine -or $UnifiedDevice.has_defender_machine)
    $existing.has_defender_hunting = ($existing.has_defender_hunting -or $UnifiedDevice.has_defender_hunting)
    $existing.has_missing_kbs = ($existing.has_missing_kbs -or $UnifiedDevice.has_missing_kbs)

    if (-not $existing.primary_user -and $UnifiedDevice.primary_user) { $existing.primary_user = $UnifiedDevice.primary_user }
    if (-not $existing.device_os -and $UnifiedDevice.device_os) { $existing.device_os = $UnifiedDevice.device_os }
    if (-not $existing.device_os_version -and $UnifiedDevice.device_os_version) { $existing.device_os_version = $UnifiedDevice.device_os_version }
    if (-not $existing.intune_compliance_state -and $UnifiedDevice.intune_compliance_state) { $existing.intune_compliance_state = $UnifiedDevice.intune_compliance_state }
    if (-not $existing.entra_trust_type -and $UnifiedDevice.entra_trust_type) { $existing.entra_trust_type = $UnifiedDevice.entra_trust_type }
    if (-not $existing.defender_onboarding_status -and $UnifiedDevice.defender_onboarding_status) { $existing.defender_onboarding_status = $UnifiedDevice.defender_onboarding_status }

    $existing.defender_machine_active = ($existing.defender_machine_active -or $UnifiedDevice.defender_machine_active)

    $existing.missing_kb_ids = @($existing.missing_kb_ids + $UnifiedDevice.missing_kb_ids | Select-Object -Unique)
    $existing.missing_kb_names = @($existing.missing_kb_names + $UnifiedDevice.missing_kb_names | Select-Object -Unique)
    $existing.missing_kb_count = $existing.missing_kb_ids.Count

    $existing.entra_data = @($existing.entra_data + $UnifiedDevice.entra_data)
    $existing.intune_data = @($existing.intune_data + $UnifiedDevice.intune_data)
    $existing.defender_alerts = @($existing.defender_alerts + $UnifiedDevice.defender_alerts)
    $existing.defender_machines = @($existing.defender_machines + $UnifiedDevice.defender_machines)
    $existing.defender_hunting = @($existing.defender_hunting + $UnifiedDevice.defender_hunting)
    $existing.defender_missing_kbs = @($existing.defender_missing_kbs + $UnifiedDevice.defender_missing_kbs)

    if (-not $existing.trend_data -and $UnifiedDevice.trend_data) {
        $existing.trend_data = $UnifiedDevice.trend_data
    }

    $existing.duplicate_hostname_count = [Math]::Max([int]$existing.duplicate_hostname_count, [int]$UnifiedDevice.duplicate_hostname_count)
    $existing.duplicate_hostname = ($existing.duplicate_hostname_count -gt 1)

    $existing.source_presence = [PSCustomObject]@{
        trend    = $existing.has_trend
        entra    = $existing.has_entra
        intune   = $existing.has_intune
        defender = ($existing.has_defender_alert -or $existing.has_defender_machine -or $existing.has_defender_hunting -or $existing.has_missing_kbs)
    }

    $existing.match_status = Resolve-MatchStatus `
        -HasTrend $existing.has_trend `
        -HasEntra $existing.has_entra `
        -HasIntune $existing.has_intune `
        -HasDefender $existing.source_presence.defender

    $existing.defender_visibility_status = if ($existing.source_presence.defender) {
        if ($existing.has_defender_machine -and $existing.has_defender_hunting) {
            "strong_visibility"
        }
        elseif ($existing.has_defender_alert -or $existing.has_missing_kbs) {
            "partial_visibility_with_security_signal"
        }
        else {
            "partial_visibility"
        }
    }
    else {
        "no_visibility"
    }
}

function Invoke-Correlation {
    param (
        [Parameter(Mandatory)]
        [array]$EntraDevices,
        [Parameter(Mandatory)]
        [array]$IntuneDevices,
        [Parameter(Mandatory)]
        [array]$TrendDevices,
        $DefenderData
    )

    Write-Log "Building correlation indexes..."

    $entraIndex = New-RecordIndex -Records $EntraDevices
    $intuneIndex = New-RecordIndex -Records $IntuneDevices

    $allKnownNames = @()
    $allKnownNames += ($TrendDevices | ForEach-Object { Get-DeviceNameFromRecord -Record $_ })
    $allKnownNames += ($EntraDevices | ForEach-Object { Get-DeviceNameFromRecord -Record $_ })
    $allKnownNames += ($IntuneDevices | ForEach-Object { Get-DeviceNameFromRecord -Record $_ })

    if ($null -ne $DefenderData) {
        $allKnownNames += ($DefenderData.Alerts | ForEach-Object { $_.device_name })
        $allKnownNames += ($DefenderData.Machines | ForEach-Object { $_.device_name })
        $allKnownNames += ($DefenderData.Hunting | ForEach-Object { $_.device_name })
        $allKnownNames += ($DefenderData.MissingKbs | ForEach-Object { $_.device_name })
    }

    $duplicateHostnames = Get-DuplicateHostnameMap -Names $allKnownNames
    $deviceMap = @{}
    $processedNameKeys = @{}
    $processedIdKeys = @{}

    foreach ($trendDevice in $TrendDevices) {
        $deviceName = Get-DeviceNameFromRecord -Record $trendDevice
        $aadDeviceId = Get-AadDeviceIdFromRecord -Record $trendDevice

        $entraMatches = @()
        $intuneMatches = @()

        if ($aadDeviceId) {
            $entraMatches += Get-IndexedRecords -Index $entraIndex.ByAadDeviceId -Key $aadDeviceId
            $intuneMatches += Get-IndexedRecords -Index $intuneIndex.ByAadDeviceId -Key $aadDeviceId
        }

        if (($entraMatches.Count -eq 0) -and $deviceName) {
            $entraMatches += Get-IndexedRecords -Index $entraIndex.ByName -Key $deviceName
        }

        if (($intuneMatches.Count -eq 0) -and $deviceName) {
            $intuneMatches += Get-IndexedRecords -Index $intuneIndex.ByName -Key $deviceName
        }

        $defenderItems = Get-DefenderItemsForDevice `
            -DefenderData $DefenderData `
            -DeviceName $deviceName `
            -AadDeviceId $aadDeviceId

        $unifiedDevice = Build-UnifiedDevice `
            -TrendRecord $trendDevice `
            -EntraRecords @($entraMatches) `
            -IntuneRecords @($intuneMatches) `
            -DefenderItems @($defenderItems) `
            -DuplicateHostnames $duplicateHostnames

        Add-OrUpdateUnifiedDevice -DeviceMap $deviceMap -UnifiedDevice $unifiedDevice

        if ($deviceName) {
            $processedNameKeys[(Normalize-CorrelationKey -Value $deviceName)] = $true
        }

        if ($aadDeviceId) {
            $processedIdKeys[(Normalize-CorrelationKey -Value $aadDeviceId)] = $true
        }
    }

    foreach ($entraDevice in $EntraDevices) {
        $deviceName = Get-DeviceNameFromRecord -Record $entraDevice
        $aadDeviceId = Get-AadDeviceIdFromRecord -Record $entraDevice

        $alreadyProcessed = $false

        if ($aadDeviceId -and $processedIdKeys.ContainsKey((Normalize-CorrelationKey -Value $aadDeviceId))) {
            $alreadyProcessed = $true
        }
        elseif ($deviceName -and $processedNameKeys.ContainsKey((Normalize-CorrelationKey -Value $deviceName))) {
            $alreadyProcessed = $true
        }

        if ($alreadyProcessed) {
            continue
        }

        $intuneMatches = @()

        if ($aadDeviceId) {
            $intuneMatches += Get-IndexedRecords -Index $intuneIndex.ByAadDeviceId -Key $aadDeviceId
        }

        if (($intuneMatches.Count -eq 0) -and $deviceName) {
            $intuneMatches += Get-IndexedRecords -Index $intuneIndex.ByName -Key $deviceName
        }

        $defenderItems = Get-DefenderItemsForDevice `
            -DefenderData $DefenderData `
            -DeviceName $deviceName `
            -AadDeviceId $aadDeviceId

        $unifiedDevice = Build-UnifiedDevice `
            -TrendRecord $null `
            -EntraRecords @($entraDevice) `
            -IntuneRecords @($intuneMatches) `
            -DefenderItems @($defenderItems) `
            -DuplicateHostnames $duplicateHostnames

        Add-OrUpdateUnifiedDevice -DeviceMap $deviceMap -UnifiedDevice $unifiedDevice
    }

    foreach ($intuneDevice in $IntuneDevices) {
        $deviceName = Get-DeviceNameFromRecord -Record $intuneDevice
        $aadDeviceId = Get-AadDeviceIdFromRecord -Record $intuneDevice

        $alreadyProcessed = $false

        if ($aadDeviceId -and $processedIdKeys.ContainsKey((Normalize-CorrelationKey -Value $aadDeviceId))) {
            $alreadyProcessed = $true
        }
        elseif ($deviceName -and $processedNameKeys.ContainsKey((Normalize-CorrelationKey -Value $deviceName))) {
            $alreadyProcessed = $true
        }

        if ($alreadyProcessed) {
            continue
        }

        $entraMatches = @()

        if ($aadDeviceId) {
            $entraMatches += Get-IndexedRecords -Index $entraIndex.ByAadDeviceId -Key $aadDeviceId
        }

        if (($entraMatches.Count -eq 0) -and $deviceName) {
            $entraMatches += Get-IndexedRecords -Index $entraIndex.ByName -Key $deviceName
        }

        $defenderItems = Get-DefenderItemsForDevice `
            -DefenderData $DefenderData `
            -DeviceName $deviceName `
            -AadDeviceId $aadDeviceId

        $unifiedDevice = Build-UnifiedDevice `
            -TrendRecord $null `
            -EntraRecords @($entraMatches) `
            -IntuneRecords @($intuneDevice) `
            -DefenderItems @($defenderItems) `
            -DuplicateHostnames $duplicateHostnames

        Add-OrUpdateUnifiedDevice -DeviceMap $deviceMap -UnifiedDevice $unifiedDevice
    }

    $result = @($deviceMap.Values | Sort-Object -Property device_name)

    Write-Log "Correlation completed: $($result.Count) unified devices" "SUCCESS"
    return $result
}