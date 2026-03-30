# =====================================================
# INTUNE DEVICE COLLECTION
# =====================================================
# Purpose:
# Collect Intune managed devices from Microsoft Graph in Live mode
# or load a fake sample dataset in Demo mode.
#
# Exposed functions:
# - Get-IntuneDevices
# - Get-IntuneDevicesFromSample
#
# Output structure:
# Both functions return the same object format:
# @{
#     CleanDevices = <array>
#     ByDeviceId   = <hashtable>
# }
#
# Matching logic:
# Intune azureADDeviceId is matched against Entra deviceId.
# =====================================================

function Get-IntuneDevices {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter(Mandatory)]
        [hashtable]$EntraByDeviceId
    )

    Write-Host "[STEP] Collecting Intune devices" -ForegroundColor Cyan

    # -------------------------------------------------
    # Microsoft Graph endpoint
    # -------------------------------------------------
    # We request only the fields needed for:
    # - correlation
    # - risk analysis
    # - reporting
    # -------------------------------------------------
    $baseUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
    $selectFields = @(
        "id",
        "deviceName",
        "userPrincipalName",
        "complianceState",
        "operatingSystem",
        "osVersion",
        "enrolledDateTime",
        "azureADDeviceId",
        "managedDeviceOwnerType"
    ) -join ","

    $currentUrl = "$baseUrl?`$select=$selectFields"
    $rawDevices = @()
    $pageCount = 0

    try {
        while ($currentUrl) {
            $pageCount++

            $response = Invoke-RestMethod `
                -Method GET `
                -Uri $currentUrl `
                -Headers $Headers `
                -ErrorAction Stop

            if ($response.value) {
                $rawDevices += $response.value
            }

            $nextLink = $null

            if ($response.PSObject.Properties.Name -contains "@odata.nextLink") {
                $nextLink = $response.'@odata.nextLink'
            }
            elseif ($response.PSObject.Properties.Name -contains "nextLink") {
                $nextLink = $response.nextLink
            }

            if ($pageCount % 5 -eq 0) {
                Write-Host "[INFO] Intune pages processed: $pageCount | Total devices so far: $($rawDevices.Count)" -ForegroundColor White
            }

            $currentUrl = $nextLink
        }
    }
    catch {
        throw "Microsoft Graph Intune device collection failed: $($_.Exception.Message)"
    }

    if (-not $rawDevices -or $rawDevices.Count -eq 0) {
        throw "No Intune devices were collected from Microsoft Graph."
    }

    Write-Host "[OK] Intune raw devices: $($rawDevices.Count)" -ForegroundColor Green

    # -------------------------------------------------
    # Build lookup table
    # -------------------------------------------------
    # Key = Intune azureADDeviceId
    # Value = normalized clean export object
    # -------------------------------------------------
    $intuneByDeviceId = @()
    $intuneByDeviceId = @{}

    $cleanDevices = @()

    foreach ($device in $rawDevices) {

        # ---------------------------------------------
        # Normalize Intune export fields
        # ---------------------------------------------
        # Keep a stable output format for reports and
        # future public demo usage.
        # ---------------------------------------------
        $cleanDevice = [PSCustomObject]@{
            SERIAL_NUMBER      = $null
            DEVICE             = $device.deviceName
            USER               = $device.userPrincipalName
            COMPLIANCE         = $device.complianceState
            OS                 = $device.operatingSystem
            OS_VERSION         = $device.osVersion
            ENROLLED_DATE      = $device.enrolledDateTime
            INTUNE_DEVICE_ID   = $device.id
            AZURE_AD_DEVICE_ID = $device.azureADDeviceId
            OWNERSHIP_INTUNE   = $device.managedDeviceOwnerType
        }

        $cleanDevices += $cleanDevice

        if ($device.azureADDeviceId) {
            $intuneByDeviceId[$device.azureADDeviceId] = $cleanDevice
        }
    }

    Write-Host "[OK] Intune enrichment done" -ForegroundColor Green

    return [PSCustomObject]@{
        CleanDevices = $cleanDevices
        ByDeviceId   = $intuneByDeviceId
    }
}

function Get-IntuneDevicesFromSample {
    param (
        [Parameter(Mandatory)]
        [string]$SamplePath,

        [Parameter(Mandatory)]
        [hashtable]$EntraByDeviceId
    )

    Write-Host "[STEP] Loading Intune sample devices" -ForegroundColor Cyan

    if (-not (Test-Path $SamplePath)) {
        throw "Intune sample file not found: $SamplePath"
    }

    # -------------------------------------------------
    # Import CSV sample file
    # -------------------------------------------------
    # Expected demo format:
    # SERIAL_NUMBER;DEVICE;USER;COMPLIANCE;OS;OS_VERSION;
    # ENROLLED_DATE;INTUNE_DEVICE_ID;AZURE_AD_DEVICE_ID;OWNERSHIP_INTUNE
    # -------------------------------------------------
    try {
        $rawDevices = Import-Csv -Path $SamplePath -Delimiter ";" -ErrorAction Stop
    }
    catch {
        throw "Failed to read Intune sample file: $($_.Exception.Message)"
    }

    if (-not $rawDevices -or $rawDevices.Count -eq 0) {
        throw "Intune sample dataset is empty."
    }

    $cleanDevices = @()
    $intuneByDeviceId = @{}

    foreach ($device in $rawDevices) {

        # ---------------------------------------------
        # Defensive normalization
        # ---------------------------------------------
        # Ensure the required demo columns exist even
        # if the sample file is incomplete.
        # ---------------------------------------------
        $requiredFields = @(
            "SERIAL_NUMBER",
            "DEVICE",
            "USER",
            "COMPLIANCE",
            "OS",
            "OS_VERSION",
            "ENROLLED_DATE",
            "INTUNE_DEVICE_ID",
            "AZURE_AD_DEVICE_ID",
            "OWNERSHIP_INTUNE"
        )

        foreach ($field in $requiredFields) {
            if (-not ($device.PSObject.Properties.Name -contains $field)) {
                $device | Add-Member -NotePropertyName $field -NotePropertyValue $null -Force
            }
        }

        # ---------------------------------------------
        # Rebuild a clean normalized object
        # ---------------------------------------------
        # This guarantees the exact same output shape
        # as the Live function.
        # ---------------------------------------------
        $cleanDevice = [PSCustomObject]@{
            SERIAL_NUMBER      = $device.SERIAL_NUMBER
            DEVICE             = $device.DEVICE
            USER               = $device.USER
            COMPLIANCE         = $device.COMPLIANCE
            OS                 = $device.OS
            OS_VERSION         = $device.OS_VERSION
            ENROLLED_DATE      = $device.ENROLLED_DATE
            INTUNE_DEVICE_ID   = $device.INTUNE_DEVICE_ID
            AZURE_AD_DEVICE_ID = $device.AZURE_AD_DEVICE_ID
            OWNERSHIP_INTUNE   = $device.OWNERSHIP_INTUNE
        }

        $cleanDevices += $cleanDevice

        if ($cleanDevice.AZURE_AD_DEVICE_ID) {
            $intuneByDeviceId[$cleanDevice.AZURE_AD_DEVICE_ID] = $cleanDevice
        }
    }

    Write-Host "[OK] Intune sample devices loaded: $($cleanDevices.Count)" -ForegroundColor Green

    # -------------------------------------------------
    # Optional consistency check with Entra sample data
    # -------------------------------------------------
    # This does not block execution.
    # It only gives visibility into how many Intune sample
    # records can be correlated with Entra sample devices.
    # -------------------------------------------------
    $matchedWithEntra = 0

    foreach ($device in $cleanDevices) {
        if (
            $device.AZURE_AD_DEVICE_ID -and
            $EntraByDeviceId.ContainsKey($device.AZURE_AD_DEVICE_ID)
        ) {
            $matchedWithEntra++
        }
    }

    Write-Host "[INFO] Intune sample devices matched to Entra sample devices: $matchedWithEntra / $($cleanDevices.Count)" -ForegroundColor White

    return [PSCustomObject]@{
        CleanDevices = $cleanDevices
        ByDeviceId   = $intuneByDeviceId
    }
}