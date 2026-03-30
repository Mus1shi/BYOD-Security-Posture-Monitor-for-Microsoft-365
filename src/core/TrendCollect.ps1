# =====================================================
# TREND DEVICE LOADING
# =====================================================
# Purpose:
# Load Trend workstation datasets either from:
# - the latest processed Live export
# - a fake sample dataset in Demo mode
#
# Exposed functions:
# - Get-TrendDevices
# - Get-TrendDevicesFromSample
#
# Output structure:
# Both functions return the same object format:
# @{
#     Devices = <array>
# }
# =====================================================

function Get-TrendDevices {
    param (
        [Parameter(Mandatory)]
        [string]$ProcessedDataPath
    )

    Write-Host "[STEP] Loading Trend devices" -ForegroundColor Cyan

    if (-not (Test-Path $ProcessedDataPath)) {
        throw "Processed data path not found: $ProcessedDataPath"
    }

    # -------------------------------------------------
    # Find the most recent Trend workstation export
    # -------------------------------------------------
    $latestTrendFile = Get-ChildItem `
        -Path $ProcessedDataPath `
        -Filter "trend_workstations_*.json" `
        -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime |
        Select-Object -Last 1

    if (-not $latestTrendFile) {
        throw "No Trend workstation file found in: $ProcessedDataPath"
    }

    try {
        $rawContent = Get-Content -Path $latestTrendFile.FullName -Raw -ErrorAction Stop
        $devices = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to load Trend workstation file [$($latestTrendFile.FullName)]: $($_.Exception.Message)"
    }

    # -------------------------------------------------
    # Normalize to array
    # -------------------------------------------------
    $devices = @($devices)

    if (-not $devices -or $devices.Count -eq 0) {
        throw "Trend workstation dataset is empty: $($latestTrendFile.FullName)"
    }

    # -------------------------------------------------
    # Defensive normalization
    # -------------------------------------------------
    # Add core properties if a dataset is incomplete.
    # This prevents later pipeline failures.
    # -------------------------------------------------
    foreach ($device in $devices) {
        if (-not ($device.PSObject.Properties.Name -contains "endpointName")) {
            $device | Add-Member -NotePropertyName endpointName -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "osName")) {
            $device | Add-Member -NotePropertyName osName -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "lastSeen")) {
            $device | Add-Member -NotePropertyName lastSeen -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "healthStatus")) {
            $device | Add-Member -NotePropertyName healthStatus -NotePropertyValue $null -Force
        }
    }

    Write-Host "[OK] Trend devices loaded: $($devices.Count)" -ForegroundColor Green
    Write-Host "[INFO] Trend source file: $($latestTrendFile.FullName)" -ForegroundColor White

    return [PSCustomObject]@{
        Devices = $devices
    }
}

function Get-TrendDevicesFromSample {
    param (
        [Parameter(Mandatory)]
        [string]$SamplePath
    )

    Write-Host "[STEP] Loading Trend sample devices" -ForegroundColor Cyan

    if (-not (Test-Path $SamplePath)) {
        throw "Trend sample file not found: $SamplePath"
    }

    try {
        $rawContent = Get-Content -Path $SamplePath -Raw -ErrorAction Stop
        $sampleData = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to read Trend sample file: $($_.Exception.Message)"
    }

    # -------------------------------------------------
    # Normalize the input
    # -------------------------------------------------
    # The sample file may contain either:
    # - a pure array of devices
    # - an object with 'items', 'value', or 'records'
    # -------------------------------------------------
    $devices = @()

    if ($sampleData -is [System.Collections.IEnumerable] -and $sampleData -isnot [string]) {
        if ($sampleData.PSObject.TypeNames -notcontains 'System.Management.Automation.PSCustomObject') {
            $devices = @($sampleData)
        }
    }

    if (-not $devices -or $devices.Count -eq 0) {
        if ($sampleData.PSObject.Properties.Name -contains "items") {
            $devices = @($sampleData.items)
        }
        elseif ($sampleData.PSObject.Properties.Name -contains "value") {
            $devices = @($sampleData.value)
        }
        elseif ($sampleData.PSObject.Properties.Name -contains "records") {
            $devices = @($sampleData.records)
        }
        else {
            $devices = @($sampleData)
        }
    }

    if (-not $devices -or $devices.Count -eq 0) {
        throw "Trend sample dataset is empty."
    }

    # -------------------------------------------------
    # Defensive normalization
    # -------------------------------------------------
    # Ensure the sample file always exposes the fields
    # expected later by correlation and reporting logic.
    # -------------------------------------------------
    foreach ($device in $devices) {

        if (-not ($device.PSObject.Properties.Name -contains "endpointName")) {
            $device | Add-Member -NotePropertyName endpointName -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "osName")) {
            $device | Add-Member -NotePropertyName osName -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "osVersion")) {
            $device | Add-Member -NotePropertyName osVersion -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "lastSeen")) {
            $device | Add-Member -NotePropertyName lastSeen -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "healthStatus")) {
            $device | Add-Member -NotePropertyName healthStatus -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "lastLoggedOnUser")) {
            $device | Add-Member -NotePropertyName lastLoggedOnUser -NotePropertyValue $null -Force
        }

        if (-not ($device.PSObject.Properties.Name -contains "serialNumber")) {
            $device | Add-Member -NotePropertyName serialNumber -NotePropertyValue $null -Force
        }
    }

    Write-Host "[OK] Trend sample devices loaded: $($devices.Count)" -ForegroundColor Green

    return [PSCustomObject]@{
        Devices = $devices
    }
}