# =====================================================
# TREND DATA LOADING - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Load Trend endpoint data either from:
# - a local sample JSON file (demo mode)
# - the latest processed Trend workstation file (local mode)
#
# Trend remains the starting point of the correlation flow
# because it represents devices actively seen by endpoint
# security tooling.
# =====================================================

function Get-TrendDevices {
    param (
        [string]$ProcessedDataPath,
        [switch]$DemoMode,
        [string]$SampleTrendFile
    )

    Write-Host "[STEP] Loading Trend devices" -ForegroundColor Cyan

    $trendDevices = @()
    $sourceFile = $null

    # =====================================================
    # DEMO MODE - LOAD LOCAL SAMPLE FILE
    # =====================================================
    if ($DemoMode) {
        Write-Host "[INFO] Demo mode active - loading sample Trend dataset" -ForegroundColor White

        if (-not $SampleTrendFile) {
            throw "Demo mode is enabled, but no SampleTrendFile path was provided."
        }

        if (-not (Test-Path $SampleTrendFile)) {
            throw "Sample Trend file not found: $SampleTrendFile"
        }

        $sampleContent = Get-Content -Path $SampleTrendFile -Raw | ConvertFrom-Json
        $sourceFile = $SampleTrendFile

        if ($sampleContent.items) {
            $trendDevices = @($sampleContent.items)
        }
        elseif ($sampleContent.devices) {
            $trendDevices = @($sampleContent.devices)
        }
        elseif ($sampleContent.value) {
            $trendDevices = @($sampleContent.value)
        }
        elseif ($sampleContent -is [System.Collections.IEnumerable]) {
            $trendDevices = @($sampleContent)
        }
        else {
            throw "Sample Trend file format is not recognized. Expected an array, an 'items' property, a 'devices' property, or a 'value' property."
        }

        Write-Host "[OK] Sample Trend devices loaded: $($trendDevices.Count)" -ForegroundColor Green
        Write-Host "[INFO] Trend source file: $sourceFile" -ForegroundColor White

        return [PSCustomObject]@{
            Devices    = $trendDevices
            SourceFile = $sourceFile
        }
    }

    # =====================================================
    # LOCAL PROCESSED FILE MODE
    # =====================================================
    if (-not $ProcessedDataPath) {
        throw "ProcessedDataPath is required when not running in demo mode."
    }

    if (-not (Test-Path $ProcessedDataPath)) {
        throw "Processed data path not found: $ProcessedDataPath"
    }

    $trendFile = Get-ChildItem -Path $ProcessedDataPath -Filter "trend_workstations_*.json" -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime |
        Select-Object -Last 1

    if (-not $trendFile) {
        throw "No Trend workstation file found in $ProcessedDataPath"
    }

    $trendJson = Get-Content -Path $trendFile.FullName -Raw | ConvertFrom-Json
    $sourceFile = $trendFile.FullName

    if ($trendJson.items) {
        $trendDevices = @($trendJson.items)
    }
    elseif ($trendJson.devices) {
        $trendDevices = @($trendJson.devices)
    }
    elseif ($trendJson.value) {
        $trendDevices = @($trendJson.value)
    }
    elseif ($trendJson -is [System.Collections.IEnumerable]) {
        $trendDevices = @($trendJson)
    }
    else {
        throw "Trend processed file format is not recognized. Expected an array, an 'items' property, a 'devices' property, or a 'value' property."
    }

    Write-Host "[OK] Trend devices loaded: $($trendDevices.Count)" -ForegroundColor Green
    Write-Host "[INFO] Trend source file: $sourceFile" -ForegroundColor White

    return [PSCustomObject]@{
        Devices    = $trendDevices
        SourceFile = $sourceFile
    }
}