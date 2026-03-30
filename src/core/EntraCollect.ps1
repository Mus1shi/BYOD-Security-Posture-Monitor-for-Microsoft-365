# =====================================================
# ENTRA DEVICE COLLECTION
# =====================================================
# Purpose:
# Collect Entra ID devices from Microsoft Graph in Live mode
# or load a fake sample dataset in Demo mode.
#
# Exposed functions:
# - Get-EntraDevices
# - Get-EntraDevicesFromSample
#
# Output structure:
# Both functions return the same object format:
# @{
#     AllDevices    = <array>
#     ByDeviceId    = <hashtable>
#     ByDisplayName = <hashtable>
# }
# =====================================================

function Get-EntraDevices {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter(Mandatory)]
        [string]$RawDataPath,

        [Parameter(Mandatory)]
        [string]$ProcessedDataPath
    )

    Write-Host "[STEP] Collecting Entra devices" -ForegroundColor Cyan

    # -------------------------------------------------
    # Ensure output folders exist
    # -------------------------------------------------
    foreach ($folder in @($RawDataPath, $ProcessedDataPath)) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }

    # -------------------------------------------------
    # Microsoft Graph endpoint
    # -------------------------------------------------
    # We request only the fields needed by the project.
    # This keeps the dataset smaller and easier to process.
    # -------------------------------------------------
    $baseUrl = "https://graph.microsoft.com/v1.0/devices"
    $selectFields = @(
        "id",
        "deviceId",
        "displayName",
        "trustType",
        "operatingSystem",
        "operatingSystemVersion",
        "approximateLastSignInDateTime",
        "accountEnabled"
    ) -join ","

    $currentUrl = "$baseUrl?`$select=$selectFields"
    $allDevices = @()
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
                $allDevices += $response.value
            }

            $nextLink = $null

            if ($response.PSObject.Properties.Name -contains "@odata.nextLink") {
                $nextLink = $response.'@odata.nextLink'
            }
            elseif ($response.PSObject.Properties.Name -contains "nextLink") {
                $nextLink = $response.nextLink
            }

            if ($pageCount % 5 -eq 0) {
                Write-Host "[INFO] Entra pages processed: $pageCount | Total devices so far: $($allDevices.Count)" -ForegroundColor White
            }

            $currentUrl = $nextLink
        }
    }
    catch {
        throw "Microsoft Graph Entra device collection failed: $($_.Exception.Message)"
    }

    if (-not $allDevices -or $allDevices.Count -eq 0) {
        throw "No Entra devices were collected from Microsoft Graph."
    }

    Write-Host "[OK] Entra devices collected: $($allDevices.Count)" -ForegroundColor Green

    # -------------------------------------------------
    # Build lookup tables
    # -------------------------------------------------
    # ByDeviceId:
    #   Used to match Intune azureADDeviceId <-> Entra deviceId
    #
    # ByDisplayName:
    #   Used to match Trend endpointName <-> Entra displayName
    # -------------------------------------------------
    $entraByDeviceId = @{}
    $entraByDisplayName = @{}

    foreach ($device in $allDevices) {
        if ($device.deviceId) {
            $entraByDeviceId[$device.deviceId] = $device
        }

        # Keep the first occurrence if duplicate names exist.
        # Duplicate names are possible in real environments.
        if ($device.displayName -and -not $entraByDisplayName.ContainsKey($device.displayName)) {
            $entraByDisplayName[$device.displayName] = $device
        }
    }

    # -------------------------------------------------
    # Export raw full dataset
    # -------------------------------------------------
    $date = Get-Date -Format "yyyyMMdd-HHmm"

    $rawExportPath = Join-Path $RawDataPath "raw_entra_full_devices_$date.json"
    $allDevices | ConvertTo-Json -Depth 10 | Out-File -FilePath $rawExportPath -Encoding UTF8

    # -------------------------------------------------
    # Export processed subset:
    # Workplace devices only
    # -------------------------------------------------
    # These are often useful in BYOD-related investigations.
    # -------------------------------------------------
    $workplaceDevices = $allDevices | Where-Object { $_.trustType -eq "Workplace" }

    $processedExportPath = Join-Path $ProcessedDataPath "entra_registered_devices_$date.json"
    $workplaceDevices | ConvertTo-Json -Depth 10 | Out-File -FilePath $processedExportPath -Encoding UTF8

    Write-Host "[OK] Entra raw export saved: $rawExportPath" -ForegroundColor Green
    Write-Host "[OK] Entra processed Workplace export saved: $processedExportPath" -ForegroundColor Green

    return [PSCustomObject]@{
        AllDevices    = $allDevices
        ByDeviceId    = $entraByDeviceId
        ByDisplayName = $entraByDisplayName
    }
}

function Get-EntraDevicesFromSample {
    param (
        [Parameter(Mandatory)]
        [string]$SamplePath
    )

    Write-Host "[STEP] Loading Entra sample devices" -ForegroundColor Cyan

    if (-not (Test-Path $SamplePath)) {
        throw "Entra sample file not found: $SamplePath"
    }

    try {
        $rawContent = Get-Content -Path $SamplePath -Raw -ErrorAction Stop
        $sampleData = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to read Entra sample file: $($_.Exception.Message)"
    }

    # -------------------------------------------------
    # Normalize the input
    # -------------------------------------------------
    # The sample file may contain either:
    # - a pure array of devices
    # - an object with a property such as 'items', 'value', or 'records'
    # -------------------------------------------------
    $allDevices = @()

    if ($sampleData -is [System.Collections.IEnumerable] -and $sampleData -isnot [string]) {
        # If the root JSON element is already an array
        if ($sampleData.PSObject.TypeNames -notcontains 'System.Management.Automation.PSCustomObject') {
            $allDevices = @($sampleData)
        }
    }

    if (-not $allDevices -or $allDevices.Count -eq 0) {
        if ($sampleData.PSObject.Properties.Name -contains "value") {
            $allDevices = @($sampleData.value)
        }
        elseif ($sampleData.PSObject.Properties.Name -contains "items") {
            $allDevices = @($sampleData.items)
        }
        elseif ($sampleData.PSObject.Properties.Name -contains "records") {
            $allDevices = @($sampleData.records)
        }
        else {
            $allDevices = @($sampleData)
        }
    }

    if (-not $allDevices -or $allDevices.Count -eq 0) {
        throw "Entra sample dataset is empty."
    }

    # -------------------------------------------------
    # Build lookup tables
    # -------------------------------------------------
    $entraByDeviceId = @{}
    $entraByDisplayName = @{}

    foreach ($device in $allDevices) {

        # Defensive normalization:
        # Ensure the most important properties exist even in fake data.
        if (-not ($device.PSObject.Properties.Name -contains "deviceId")) {
            $device | Add-Member -NotePropertyName deviceId -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "displayName")) {
            $device | Add-Member -NotePropertyName displayName -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "trustType")) {
            $device | Add-Member -NotePropertyName trustType -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "approximateLastSignInDateTime")) {
            $device | Add-Member -NotePropertyName approximateLastSignInDateTime -NotePropertyValue $null -Force
        }

        if ($device.deviceId) {
            $entraByDeviceId[$device.deviceId] = $device
        }

        if ($device.displayName -and -not $entraByDisplayName.ContainsKey($device.displayName)) {
            $entraByDisplayName[$device.displayName] = $device
        }
    }

    Write-Host "[OK] Entra sample devices loaded: $($allDevices.Count)" -ForegroundColor Green

    return [PSCustomObject]@{
        AllDevices    = $allDevices
        ByDeviceId    = $entraByDeviceId
        ByDisplayName = $entraByDisplayName
    }
}