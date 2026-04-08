# =====================================================
# TREND VISION ONE - FULL ENDPOINT COLLECTION
# PUBLIC DEMO / OPTIONAL LIVE COLLECTION VERSION
# =====================================================
# Purpose:
# Collect Trend Vision One endpoints through API pagination,
# export the raw full dataset, then generate a processed
# workstation-only dataset.
#
# Public repository note:
# - this function is optional
# - it is disabled by default in demo mode
# - it requires a valid TREND_API_KEY in environment variables
# =====================================================

function Invoke-TrendCollectEndpoint {
    param (
        [Parameter(Mandatory)]
        [string]$RawDataPath,

        [Parameter(Mandatory)]
        [string]$ProcessedDataPath,

        [string]$ApiKey = $env:TREND_API_KEY,

        [string]$BaseUrl = "https://api.eu.xdr.trendmicro.com",

        [switch]$NoPreview
    )

    Write-Host "[STEP] Starting Trend endpoint collection" -ForegroundColor Cyan

    if (-not $ApiKey) {
        throw "TREND_API_KEY is missing. Live Trend collection requires a valid API key in environment variables or via -ApiKey."
    }

    foreach ($folder in @($RawDataPath, $ProcessedDataPath)) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }

    $endpointUrl = "$BaseUrl/v3.0/endpointSecurity/endpoints"

    $headers = @{
        Authorization = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }

    $currentUrl = $endpointUrl
    $allItems = @()
    $pageCount = 0

    try {
        while ($currentUrl) {
            $pageCount++

            $response = Invoke-RestMethod `
                -Method GET `
                -Uri $currentUrl `
                -Headers $headers

            if ($response.items) {
                $allItems += $response.items
            }
            elseif ($response.value) {
                $allItems += $response.value
            }

            $nextLink = $null

            if ($response.PSObject.Properties.Name -contains "@odata.nextLink") {
                $nextLink = $response.'@odata.nextLink'
            }
            elseif ($response.PSObject.Properties.Name -contains "nextLink") {
                $nextLink = $response.nextLink
            }

            if ($pageCount % 5 -eq 0) {
                Write-Host "[INFO] Trend pages processed: $pageCount | Total endpoints so far: $($allItems.Count)" -ForegroundColor White
            }

            $currentUrl = $nextLink
        }
    }
    catch {
        throw "Trend Vision One API collection failed: $($_.Exception.Message)"
    }

    Write-Host "[OK] Trend collection complete" -ForegroundColor Green
    Write-Host "[INFO] Total endpoints collected: $($allItems.Count)" -ForegroundColor White
    Write-Host "[INFO] Pages processed: $pageCount" -ForegroundColor White

    # =====================================================
    # EXPORT RAW FULL DATASET
    # =====================================================
    $date = Get-Date -Format "yyyyMMdd-HHmm"

    $rawFullPath = Join-Path $RawDataPath "raw_trend_endpoints_full_$date.json"

    $fullExport = [PSCustomObject]@{
        collectedAt = (Get-Date).ToString("o")
        source      = "trend_vision_one_api"
        pages       = $pageCount
        totalItems  = $allItems.Count
        items       = $allItems
    }

    $fullExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $rawFullPath -Encoding UTF8

    Write-Host "[OK] Raw Trend export saved: $rawFullPath" -ForegroundColor Green

    # =====================================================
    # FILTER WORKSTATIONS
    # =====================================================
    $workstations = $allItems | Where-Object {
        $_.osName -and $_.osName -notmatch "Server"
    }

    Write-Host "[INFO] Workstations detected: $($workstations.Count)" -ForegroundColor Magenta

    # =====================================================
    # EXPORT PROCESSED WORKSTATION DATASET
    # =====================================================
    $workstationsPath = Join-Path $ProcessedDataPath "trend_workstations_$date.json"

    $processedExport = [PSCustomObject]@{
        collectedAt = (Get-Date).ToString("o")
        source      = "trend_vision_one_api"
        totalItems  = $workstations.Count
        devices     = $workstations
    }

    $processedExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $workstationsPath -Encoding UTF8

    Write-Host "[OK] Processed workstation export saved: $workstationsPath" -ForegroundColor Green

    # =====================================================
    # OPTIONAL PREVIEW
    # =====================================================
    if (-not $NoPreview) {
        Write-Host "[STEP] Preview of first 20 Trend workstations" -ForegroundColor Cyan

        $workstations |
            Select-Object endpointName, osName, agentVersion, lastSeen, healthStatus |
            Select-Object -First 20 |
            Format-Table
    }

    return [PSCustomObject]@{
        RawFullPath       = $rawFullPath
        WorkstationsPath  = $workstationsPath
        TotalItems        = $allItems.Count
        WorkstationsCount = $workstations.Count
        PagesProcessed    = $pageCount
    }
}