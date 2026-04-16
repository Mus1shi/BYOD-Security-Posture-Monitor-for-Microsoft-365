# =====================================================
# CORRELATION ENGINE - SECURITY DEVICE MONITOR (PUBLIC DEMO)
# =====================================================

function Normalize-CorrelationString {
    param (
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return $Value.Trim().ToLower()
}

function Get-CorrelationDeviceName {
    param (
        [Parameter(Mandatory)]
        $Item
    )

    $candidates = @(
        $Item.device_name,
        $Item.deviceName,
        $Item.displayName,
        $Item.computerDnsName,
        $Item.hostname,
        $Item.DeviceName
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate.Trim()
        }
    }

    return $null
}

function Get-CorrelationAadDeviceId {
    param (
        [Parameter(Mandatory)]
        $Item
    )

    $candidates = @(
        $Item.aad_device_id,
        $Item.azureADDeviceId,
        $Item.azureAdDeviceId,
        $Item.deviceId,
        $Item.device_id,
        $Item.DeviceId
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate.Trim()
        }
    }

    return $null
}

function Get-CorrelationPrimaryUser {
    param (
        [Parameter(Mandatory)]
        $Item
    )

    $candidates = @(
        $Item.primary_user,
        $Item.userPrincipalName,
        $Item.user_principal_name,
        $Item.owner,
        $Item.lastLoggedOnUser,
        $Item.email
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate.Trim()
        }
    }

    return $null
}

function Add-CorrelationIndexItem {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Index,

        [AllowNull()]
        [string]$Key,

        [Parameter(Mandatory)]
        $Item
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return
    }

    $normalizedKey = Normalize-CorrelationString -Value $Key

    if (-not $Index.ContainsKey($normalizedKey)) {
        $Index[$normalizedKey] = @()
    }

    $Index[$normalizedKey] += $Item
}

function New-CorrelationIndex {
    param (
        [Parameter(Mandatory)]
        [array]$Items
    )

    $index = @{
        ByName = @{}
        ByAadDeviceId = @{}
    }

    foreach ($item in $Items) {
        $deviceName = Get-CorrelationDeviceName -Item $item
        $aadDeviceId = Get-CorrelationAadDeviceId -Item $item

        Add-CorrelationIndexItem -Index $index.ByName -Key $deviceName -Item $item
        Add-CorrelationIndexItem -Index $index.ByAadDeviceId -Key $aadDeviceId -Item $item
    }

    return $index
}

function Get-IndexedItems {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Index,

        [AllowNull()]
        [string]$Key
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return @()
    }

    $normalizedKey = Normalize-CorrelationString -Value $Key

    if ($Index.ContainsKey($normalizedKey)) {
        return @($Index[$normalizedKey])
    }

    return @()
}

function Get-FirstNonEmptyValue {
    param (
        [Parameter(Mandatory)]
        [object[]]$Values
    )

    foreach ($value in $Values) {
        if ($null -eq $value) {
            continue
        }

        if ($value -is [string]) {
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value.Trim()
            }
        }
        else {
            return $value
        }
    }

    return $null
}

function Get-UniqueStringList {
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

        if ($value -is [System.Array]) {
            foreach ($subValue in $value) {
                if ([string]::IsNullOrWhiteSpace([string]$subValue)) {
                    continue
                }

                $normalized = Normalize-CorrelationString -Value ([string]$subValue)
                if (-not $seen.ContainsKey($normalized)) {
                    $seen[$normalized] = $true
                    $result.Add(([string]$subValue).Trim())
                }
            }
        }
        else {
            if ([string]::IsNullOrWhiteSpace([string]$value)) {
                continue
            }

            $normalized = Normalize-CorrelationString -Value ([string]$value)
            if (-not $seen.ContainsKey($normalized)) {
                $seen[$normalized] = $true
                $result[$result.Count] = ([string]$value).Trim()
            }
        }
    }

    return @($result)
}

function Get-UniqueStringListSafe {
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

        if ($value -is [System.Array]) {
            foreach ($subValue in $value) {
                if ([string]::IsNullOrWhiteSpace([string]$subValue)) {
                    continue
                }

                $clean = ([string]$subValue).Trim()
                $normalized = Normalize-CorrelationString -Value $clean

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
            $normalized = Normalize-CorrelationString -Value $clean

            if (-not $seen.ContainsKey($normalized)) {
                $seen[$normalized] = $true
                [void]$result.Add($clean)
            }
        }
    }

    return @($result)
}

function Test-AnyTrue {
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

function Resolve-MatchStatus {
    param (
        [bool]$HasTrend,
        [bool]$HasEntra,
        [bool]$HasIntune,
        [bool]$HasDefender
    )

    $sourceCount = @($HasTrend, $HasEntra, $HasIntune, $HasDefender | Where-Object { $_ -eq $true }).Count

    if ($sourceCount -ge 4) {
        return "full_match_all_sources"
    }

    if ($sourceCount -eq 3) {
        return "strong_match_three_sources"
    }

    if ($sourceCount -eq 2) {
        return "partial_match_two_sources"
    }

    return "single_source_only"
}

function Get-DefenderItemsForDevice {
    param (
        [Parameter(Mandatory)]
        $DefenderData,

        [AllowNull()]
        [string]$DeviceName,

        [AllowNull()]
        [string]$AadDeviceId
    )

    $results = @()

    if ($null -eq $DefenderData) {
        return @()
    }

    $results += Get-IndexedItems -Index $DefenderData.ByDeviceName -Key $DeviceName
    $results += Get-IndexedItems -Index $DefenderData.ByAadDeviceId -Key $AadDeviceId

    if (-not $results -or $results.Count -eq 0) {
        return @()
    }

    $unique = @()
    $seen = @{}

    foreach ($item in $results) {
        $fingerprint = "{0}|{1}|{2}|{3}" -f `
            $item.source,
            $item.device_name,
            $item.aad_device_id,
            ($item.alert_id ?? $item.machine_id ?? $item.kb_id ?? $item.device_id)

        if (-not $seen.ContainsKey($fingerprint)) {
            $seen[$fingerprint] = $true
            $unique += $item
        }
    }

    return $unique
}

function Group-DefenderSignals {
    param (
        [Parameter(Mandatory)]
        [array]$DefenderItems
    )

    $alerts = @($DefenderItems | Where-Object { $_.source -eq "defender_alert" })
    $machines = @($DefenderItems | Where-Object { $_.source -eq "defender_machine" })
    $hunting = @($DefenderItems | Where-Object { $_.source -eq "defender_hunting" })
    $missingKbs = @($DefenderItems | Where-Object { $_.source -eq "defender_missing_kb" })

    return [PSCustomObject]@{
        Alerts     = $alerts
        Machines   = $machines
        Hunting    = $hunting
        MissingKbs = $missingKbs
    }
}

function Get-DuplicateHostnameMap {
    param (
        [Parameter(Mandatory)]
        [array]$AllNames
    )

    $map = @{}
    $counts = @{}

    foreach ($name in $AllNames) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $normalized = Normalize-CorrelationString -Value $name

        if (-not $counts.ContainsKey($normalized)) {
            $counts[$normalized] = 0
        }

        $counts[$normalized]++
    }

    foreach ($key in $counts.Keys) {
        $map[$key] = $counts[$key]
    }

    return $map
}

function Build-CorrelatedDevice {
    param (
        [Parameter(Mandatory)]
        $TrendItem,

        [Parameter(Mandatory)]
        [array]$EntraMatches,

        [Parameter(Mandatory)]
        [array]$IntuneMatches,

        [Parameter(Mandatory)]
        [array]$DefenderItems,

        [Parameter(Mandatory)]
        [hashtable]$DuplicateHostnames
    )

    $defenderGroups = Group-DefenderSignals -DefenderItems $DefenderItems

    $deviceName = Get-FirstNonEmptyValue -Values @(
        (Get-CorrelationDeviceName -Item $TrendItem),
        ($EntraMatches | ForEach-Object { Get-CorrelationDeviceName -Item $_ }),
        ($IntuneMatches | ForEach-Object { Get-CorrelationDeviceName -Item $_ }),
        ($DefenderItems | ForEach-Object { Get-CorrelationDeviceName -Item $_ })
    )

    $aadDeviceId = Get-FirstNonEmptyValue -Values @(
        (Get-CorrelationAadDeviceId -Item $TrendItem),
        ($EntraMatches | ForEach-Object { Get-CorrelationAadDeviceId -Item $_ }),
        ($IntuneMatches | ForEach-Object { Get-CorrelationAadDeviceId -Item $_ }),
        ($DefenderItems | ForEach-Object { Get-CorrelationAadDeviceId -Item $_ })
    )

    $primaryUser = Get-FirstNonEmptyValue -Values @(
        (Get-CorrelationPrimaryUser -Item $TrendItem),
        ($IntuneMatches | ForEach-Object { Get-CorrelationPrimaryUser -Item $_ }),
        ($EntraMatches | ForEach-Object { Get-CorrelationPrimaryUser -Item $_ })
    )

    $hasTrend = $null -ne $TrendItem
    $hasEntra = $EntraMatches.Count -gt 0
    $hasIntune = $IntuneMatches.Count -gt 0
    $hasDefenderAlert = $defenderGroups.Alerts.Count -gt 0
    $hasDefenderMachine = $defenderGroups.Machines.Count -gt 0
    $hasDefenderHunting = $defenderGroups.Hunting.Count -gt 0
    $hasMissingKbs = $defenderGroups.MissingKbs.Count -gt 0
    $hasAnyDefender = $hasDefenderAlert -or $hasDefenderMachine -or $hasDefenderHunting -or $hasMissingKbs

    $matchStatus = Resolve-MatchStatus `
        -HasTrend $hasTrend `
        -HasEntra $hasEntra `
        -HasIntune $hasIntune `
        -HasDefender $hasAnyDefender

    $duplicateCount = 0
    $normalizedName = Normalize-CorrelationString -Value $deviceName
    if ($normalizedName -and $DuplicateHostnames.ContainsKey($normalizedName)) {
        $duplicateCount = [int]$DuplicateHostnames[$normalizedName]
    }

    $issues = New-Object System.Collections.Generic.List[string]

    if (-not $hasEntra) {
        [void]$issues.Add("missing_in_entra")
    }

    if (-not $hasIntune) {
        [void]$issues.Add("missing_in_intune")
    }

    if (-not $hasTrend) {
        [void]$issues.Add("missing_in_trend")
    }

    if (-not $hasAnyDefender) {
        [void]$issues.Add("missing_in_defender")
    }

    if ($hasDefenderAlert) {
        [void]$issues.Add("defender_alert_present")
    }

    if ($hasMissingKbs) {
        [void]$issues.Add("missing_security_updates")
    }

    if ($hasTrend -and -not $hasDefenderMachine) {
        [void]$issues.Add("defender_visibility_gap")
    }

    if ($hasEntra -and -not $hasIntune) {
        [void]$issues.Add("registered_not_managed")
    }

    if ($duplicateCount -gt 1) {
        [void]$issues.Add("duplicate_hostname")
    }

    $intuneComplianceState = Get-FirstNonEmptyValue -Values @(
        $IntuneMatches | ForEach-Object { $_.complianceState }
    )

    if ($intuneComplianceState -and $intuneComplianceState -ne "compliant") {
        [void]$issues.Add("device_noncompliant")
    }

    $entraTrustType = Get-FirstNonEmptyValue -Values @(
        $EntraMatches | ForEach-Object { $_.trustType }
    )

    if ($entraTrustType -eq "Workplace") {
        [void]$issues.Add("probable_private_byod")
    }

    $machineOnboardingStatus = Get-FirstNonEmptyValue -Values @(
        $defenderGroups.Machines | ForEach-Object { $_.onboarding_status }
    )

    $machineIsActive = Test-AnyTrue -Values @(
        $defenderGroups.Machines | ForEach-Object { $_.is_active }
    )

    if ($hasDefenderMachine -and -not $machineIsActive) {
        [void]$issues.Add("inactive_defender_device")
    }

    $missingKbIds = Get-UniqueStringListSafe -Values @(
        $defenderGroups.MissingKbs | ForEach-Object { $_.kb_id }
    )

    $missingKbNames = Get-UniqueStringListSafe -Values @(
        $defenderGroups.MissingKbs | ForEach-Object { $_.kb_name }
    )

    $defenderVisibilityStatus = if ($hasAnyDefender) {
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

    $deviceOs = Get-FirstNonEmptyValue -Values @(
        $TrendItem.platform,
        ($IntuneMatches | ForEach-Object { $_.operatingSystem }),
        ($EntraMatches | ForEach-Object { $_.operatingSystem }),
        ($defenderGroups.Machines | ForEach-Object { $_.os_platform })
    )

    $deviceOsVersion = Get-FirstNonEmptyValue -Values @(
        ($IntuneMatches | ForEach-Object { $_.osVersion }),
        ($EntraMatches | ForEach-Object { $_.operatingSystemVersion })
    )

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
            defender = $hasAnyDefender
        }

        match_status               = $matchStatus
        defender_visibility_status = $defenderVisibilityStatus

        intune_compliance_state    = $intuneComplianceState
        entra_trust_type           = $entraTrustType
        defender_onboarding_status = $machineOnboardingStatus
        defender_machine_active    = $machineIsActive

        missing_kb_count           = $missingKbIds.Count
        missing_kb_ids             = $missingKbIds
        missing_kb_names           = $missingKbNames

        duplicate_hostname         = ($duplicateCount -gt 1)
        duplicate_hostname_count   = $duplicateCount

        issues                     = @($issues | Select-Object -Unique)

        trend_data                 = $TrendItem
        entra_data                 = @($EntraMatches)
        intune_data                = @($IntuneMatches)
        defender_alerts            = @($defenderGroups.Alerts)
        defender_machines          = @($defenderGroups.Machines)
        defender_hunting           = @($defenderGroups.Hunting)
        defender_missing_kbs       = @($defenderGroups.MissingKbs)
    }
}

function Add-OrMergeCandidate {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Candidates,

        [Parameter(Mandatory)]
        $Device
    )

    $key = Get-FirstNonEmptyValue -Values @(
        $Device.aad_device_id,
        $Device.device_name
    )

    if ([string]::IsNullOrWhiteSpace([string]$key)) {
        $key = [guid]::NewGuid().ToString()
    }

    $normalizedKey = Normalize-CorrelationString -Value ([string]$key)

    if (-not $Candidates.ContainsKey($normalizedKey)) {
        $Candidates[$normalizedKey] = $Device
        return
    }

    $existing = $Candidates[$normalizedKey]

    $existingIssues = @($existing.issues)
    $newIssues = @($Device.issues)

    $mergedIssues = @($existingIssues + $newIssues | Select-Object -Unique)

    $existing.issues = $mergedIssues

    if (-not $existing.has_entra -and $Device.has_entra) { $existing.has_entra = $true }
    if (-not $existing.has_intune -and $Device.has_intune) { $existing.has_intune = $true }
    if (-not $existing.has_trend -and $Device.has_trend) { $existing.has_trend = $true }
    if (-not $existing.has_defender_alert -and $Device.has_defender_alert) { $existing.has_defender_alert = $true }
    if (-not $existing.has_defender_machine -and $Device.has_defender_machine) { $existing.has_defender_machine = $true }
    if (-not $existing.has_defender_hunting -and $Device.has_defender_hunting) { $existing.has_defender_hunting = $true }
    if (-not $existing.has_missing_kbs -and $Device.has_missing_kbs) { $existing.has_missing_kbs = $true }

    if (-not $existing.primary_user -and $Device.primary_user) { $existing.primary_user = $Device.primary_user }
    if (-not $existing.device_os -and $Device.device_os) { $existing.device_os = $Device.device_os }
    if (-not $existing.device_os_version -and $Device.device_os_version) { $existing.device_os_version = $Device.device_os_version }

    $existing.missing_kb_ids = @($existing.missing_kb_ids + $Device.missing_kb_ids | Select-Object -Unique)
    $existing.missing_kb_names = @($existing.missing_kb_names + $Device.missing_kb_names | Select-Object -Unique)
    $existing.missing_kb_count = $existing.missing_kb_ids.Count

    $existing.defender_alerts = @($existing.defender_alerts + $Device.defender_alerts)
    $existing.defender_machines = @($existing.defender_machines + $Device.defender_machines)
    $existing.defender_hunting = @($existing.defender_hunting + $Device.defender_hunting)
    $existing.defender_missing_kbs = @($existing.defender_missing_kbs + $Device.defender_missing_kbs)

    $existing.entra_data = @($existing.entra_data + $Device.entra_data)
    $existing.intune_data = @($existing.intune_data + $Device.intune_data)

    $existing.source_presence = [PSCustomObject]@{
        trend    = ($existing.has_trend -or $Device.has_trend)
        entra    = ($existing.has_entra -or $Device.has_entra)
        intune   = ($existing.has_intune -or $Device.has_intune)
        defender = (
            $existing.has_defender_alert -or
            $existing.has_defender_machine -or
            $existing.has_defender_hunting -or
            $existing.has_missing_kbs -or
            $Device.has_defender_alert -or
            $Device.has_defender_machine -or
            $Device.has_defender_hunting -or
            $Device.has_missing_kbs
        )
    }

    $existing.match_status = Resolve-MatchStatus `
        -HasTrend $existing.has_trend `
        -HasEntra $existing.has_entra `
        -HasIntune $existing.has_intune `
        -HasDefender $existing.source_presence.defender
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

    $entraIndex = New-CorrelationIndex -Items $EntraDevices
    $intuneIndex = New-CorrelationIndex -Items $IntuneDevices

    $allNames = @()
    $allNames += $TrendDevices | ForEach-Object { Get-CorrelationDeviceName -Item $_ }
    $allNames += $EntraDevices | ForEach-Object { Get-CorrelationDeviceName -Item $_ }
    $allNames += $IntuneDevices | ForEach-Object { Get-CorrelationDeviceName -Item $_ }

    if ($null -ne $DefenderData) {
        $allNames += $DefenderData.Machines | ForEach-Object { $_.device_name }
        $allNames += $DefenderData.Hunting | ForEach-Object { $_.device_name }
        $allNames += $DefenderData.Alerts | ForEach-Object { $_.device_name }
    }

    $duplicateHostnames = Get-DuplicateHostnameMap -AllNames $allNames

    $correlated = @{}
    $processedNameKeys = @{}
    $processedIdKeys = @{}

    foreach ($trendDevice in $TrendDevices) {
        $deviceName = Get-CorrelationDeviceName -Item $trendDevice
        $aadDeviceId = Get-CorrelationAadDeviceId -Item $trendDevice

        $entraMatches = @()
        $intuneMatches = @()

        if ($aadDeviceId) {
            $entraMatches += Get-IndexedItems -Index $entraIndex.ByAadDeviceId -Key $aadDeviceId
            $intuneMatches += Get-IndexedItems -Index $intuneIndex.ByAadDeviceId -Key $aadDeviceId
        }

        if (($entraMatches.Count -eq 0) -and $deviceName) {
            $entraMatches += Get-IndexedItems -Index $entraIndex.ByName -Key $deviceName
        }

        if (($intuneMatches.Count -eq 0) -and $deviceName) {
            $intuneMatches += Get-IndexedItems -Index $intuneIndex.ByName -Key $deviceName
        }

        $defenderItems = Get-DefenderItemsForDevice `
            -DefenderData $DefenderData `
            -DeviceName $deviceName `
            -AadDeviceId $aadDeviceId

        $device = Build-CorrelatedDevice `
            -TrendItem $trendDevice `
            -EntraMatches @($entraMatches) `
            -IntuneMatches @($intuneMatches) `
            -DefenderItems @($defenderItems) `
            -DuplicateHostnames $duplicateHostnames

        Add-OrMergeCandidate -Candidates $correlated -Device $device

        if ($deviceName) {
            $processedNameKeys[(Normalize-CorrelationString -Value $deviceName)] = $true
        }

        if ($aadDeviceId) {
            $processedIdKeys[(Normalize-CorrelationString -Value $aadDeviceId)] = $true
        }
    }

    foreach ($entraDevice in $EntraDevices) {
        $deviceName = Get-CorrelationDeviceName -Item $entraDevice
        $aadDeviceId = Get-CorrelationAadDeviceId -Item $entraDevice

        $alreadyProcessed = $false

        if ($aadDeviceId -and $processedIdKeys.ContainsKey((Normalize-CorrelationString -Value $aadDeviceId))) {
            $alreadyProcessed = $true
        }
        elseif ($deviceName -and $processedNameKeys.ContainsKey((Normalize-CorrelationString -Value $deviceName))) {
            $alreadyProcessed = $true
        }

        if ($alreadyProcessed) {
            continue
        }

        $intuneMatches = @()
        if ($aadDeviceId) {
            $intuneMatches += Get-IndexedItems -Index $intuneIndex.ByAadDeviceId -Key $aadDeviceId
        }
        if (($intuneMatches.Count -eq 0) -and $deviceName) {
            $intuneMatches += Get-IndexedItems -Index $intuneIndex.ByName -Key $deviceName
        }

        $defenderItems = Get-DefenderItemsForDevice `
            -DefenderData $DefenderData `
            -DeviceName $deviceName `
            -AadDeviceId $aadDeviceId

        $device = Build-CorrelatedDevice `
            -TrendItem $null `
            -EntraMatches @($entraDevice) `
            -IntuneMatches @($intuneMatches) `
            -DefenderItems @($defenderItems) `
            -DuplicateHostnames $duplicateHostnames

        Add-OrMergeCandidate -Candidates $correlated -Device $device
    }

    foreach ($intuneDevice in $IntuneDevices) {
        $deviceName = Get-CorrelationDeviceName -Item $intuneDevice
        $aadDeviceId = Get-CorrelationAadDeviceId -Item $intuneDevice

        $alreadyProcessed = $false

        if ($aadDeviceId -and $processedIdKeys.ContainsKey((Normalize-CorrelationString -Value $aadDeviceId))) {
            $alreadyProcessed = $true
        }
        elseif ($deviceName -and $processedNameKeys.ContainsKey((Normalize-CorrelationString -Value $deviceName))) {
            $alreadyProcessed = $true
        }

        if ($alreadyProcessed) {
            continue
        }

        $entraMatches = @()
        if ($aadDeviceId) {
            $entraMatches += Get-IndexedItems -Index $entraIndex.ByAadDeviceId -Key $aadDeviceId
        }
        if (($entraMatches.Count -eq 0) -and $deviceName) {
            $entraMatches += Get-IndexedItems -Index $entraIndex.ByName -Key $deviceName
        }

        $defenderItems = Get-DefenderItemsForDevice `
            -DefenderData $DefenderData `
            -DeviceName $deviceName `
            -AadDeviceId $aadDeviceId

        $device = Build-CorrelatedDevice `
            -TrendItem $null `
            -EntraMatches @($entraMatches) `
            -IntuneMatches @($intuneDevice) `
            -DefenderItems @($defenderItems) `
            -DuplicateHostnames $duplicateHostnames

        Add-OrMergeCandidate -Candidates $correlated -Device $device
    }

    $result = @($correlated.Values | Sort-Object device_name)

    Write-Log "Correlation completed: $($result.Count) unified devices"
    return $result
}