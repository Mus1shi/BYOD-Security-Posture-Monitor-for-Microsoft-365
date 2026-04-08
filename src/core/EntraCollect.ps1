# =====================================================
# ENTRA DEVICE COLLECTION - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Retrieve Entra device inventory either from:
# - Microsoft Graph (live mode)
# - local sample JSON file (demo mode)
#
# Output:
# - full device list
# - Workplace filtered list
# - lookup tables by deviceId and displayName
# =====================================================

function Get-AllEntraDevices {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Headers
    )

    $currentUrl = "https://graph.microsoft.com/v1.0/devices?`$select=deviceId,displayName,trustType,operatingSystem,operatingSystemVersion,approximateLastSignInDateTime,accountEnabled"
    $allItems = @()

    while ($currentUrl) {
        $response = Invoke-RestMethod -Method GET -Uri $currentUrl -Headers $Headers

        if ($response.value) {
            $allItems += $response.value
        }

        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $currentUrl = $response.'@odata.nextLink'
        }
        elseif ($response.PSObject.Properties.Name -contains 'nextLink') {
            $currentUrl = $response.nextLink
        }
        else {
            $currentUrl = $null
        }
    }

    return $allItems
}

function Get-EntraDevices {
    param (
        [hashtable]$Headers,
        [string]$RawDataPath,
        [string]$ProcessedDataPath,
        [switch]$DemoMode,
        [string]$SampleEntraFile
    )

    Write-Host "[STEP] Collecting Entra devices" -ForegroundColor Cyan

    $entraAll = @()
    $date = Get-Date -Format "yyyyMMdd-HHmm"

    # =====================================================
    # DEMO MODE - LOAD LOCAL SAMPLE FILE
    # =====================================================
    if ($DemoMode) {
        Write-Host "[INFO] Demo mode active - loading sample Entra dataset" -ForegroundColor White

        if (-not $SampleEntraFile) {
            throw "Demo mode is enabled, but no SampleEntraFile path was provided."
        }

        if (-not (Test-Path $SampleEntraFile)) {
            throw "Sample Entra file not found: $SampleEntraFile"
        }

        $sampleContent = Get-Content -Path $SampleEntraFile -Raw | ConvertFrom-Json

        if ($sampleContent.devices) {
            $entraAll = @($sampleContent.devices)
        }
        elseif ($sampleContent.value) {
            $entraAll = @($sampleContent.value)
        }
        elseif ($sampleContent -is [System.Collections.IEnumerable]) {
            $entraAll = @($sampleContent)
        }
        else {
            throw "Sample Entra file format is not recognized. Expected an array, a 'devices' property, or a 'value' property."
        }

        Write-Host "[OK] Sample Entra devices loaded: $($entraAll.Count)" -ForegroundColor Green
    }

    # =====================================================
    # LIVE MODE - MICROSOFT GRAPH
    # =====================================================
    else {
        if (-not $Headers) {
            throw "Live Entra collection requires Graph headers."
        }

        $entraAll = Get-AllEntraDevices -Headers $Headers
        Write-Host "[OK] Live Entra devices collected: $($entraAll.Count)" -ForegroundColor Green
    }

    # =====================================================
    # EXPORT RAW SNAPSHOT
    # =====================================================
    $rawFullPath = Join-Path $RawDataPath "raw_entra_full_devices_$date.json"

    $fullExport = [PSCustomObject]@{
        collectedAt  = (Get-Date).ToString("o")
        source       = if ($DemoMode) { "sample_file" } else { "microsoft_graph" }
        totalDevices = $entraAll.Count
        devices      = $entraAll
    }

    $fullExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $rawFullPath -Encoding UTF8

    # =====================================================
    # FILTER WORKPLACE DEVICES
    # =====================================================
    $entraRegistered = $entraAll | Where-Object { $_.trustType -eq "Workplace" }

    $registeredPath = Join-Path $ProcessedDataPath "entra_registered_devices_$date.json"

    $registeredExport = [PSCustomObject]@{
        collectedAt     = (Get-Date).ToString("o")
        source          = if ($DemoMode) { "sample_file" } else { "microsoft_graph" }
        trustTypeFilter = "Workplace"
        totalDevices    = $entraRegistered.Count
        devices         = $entraRegistered
    }

    $registeredExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $registeredPath -Encoding UTF8

    # =====================================================
    # LOOKUP TABLES
    # =====================================================
    $entraByDeviceId = @{}
    $entraByDisplayName = @{}

    foreach ($device in $entraAll) {
        if ($device.deviceId) {
            $entraByDeviceId[$device.deviceId] = $device
        }

        if ($device.displayName) {
            $entraByDisplayName[$device.displayName] = $device
        }
    }

    Write-Host "[OK] Entra lookup tables prepared" -ForegroundColor Green

    # =====================================================
    # RETURN STRUCTURED DATA
    # =====================================================
    return [PSCustomObject]@{
        AllDevices        = $entraAll
        RegisteredDevices = $entraRegistered
        ByDeviceId        = $entraByDeviceId
        ByDisplayName     = $entraByDisplayName
    }
}