# =====================================================
# TREND VISION ONE - FULL ENDPOINT COLLECTION
# =====================================================
# Purpose:
# Collect all Trend Vision One endpoints through API pagination,
# export the raw full dataset, then split and export:
# - workstations
#
# Public GitHub version:
# - Safe to publish
# - Live collection only
# - Demo mode must not call this function
#
# Notes:
# - The Trend API key is read from $env:TREND_API_KEY
# - This function is intended for private/internal execution
# - In Demo mode, sample datasets should be loaded instead
# =====================================================

function Invoke-TrendCollectEndpoint {
    param (
        [Parameter(Mandatory)]
        [string]$RawDataPath,

        [Parameter(Mandatory)]
        [string]$ProcessedDataPath,

        [switch]$NoPreview
    )

    Write-Host "[STEP] Starting Trend full endpoint collection" -ForegroundColor Cyan

    # -------------------------------------------------
    # Read Trend API key from environment variable
    # -------------------------------------------------
    # The public GitHub version must never store the API
    # key directly in code or in a committed config file.
    # -------------------------------------------------
    $apiKey = $env:TREND_API_KEY

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "TREND_API_KEY is not set in environment variables."
    }

    # -------------------------------------------------
    # Ensure output folders exist
    # -------------------------------------------------
    foreach ($folder in @($RawDataPath, $ProcessedDataPath)) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
            Write-Host "[INFO] Created missing folder: $folder" -ForegroundColor DarkGray
        }
    }

    # -------------------------------------------------
    # API configuration
    # -------------------------------------------------
    # This uses the official Trend Vision One API base URL.
    # Adjust privately if your internal environment differs.
    # -------------------------------------------------
    $baseUrl = "https://api.eu.xdr.trendmicro.com"
    $endpointUrl = "$baseUrl/v3.0/endpointSecurity/endpoints"

    $headers = @{
        Authorization = "Bearer $apiKey"
        "Content-Type" = "application/json"
    }

    # -------------------------------------------------
    # Pagination and full collection
    # -------------------------------------------------
    # The API may return a nextLink-style pagination token.
    # We keep collecting until no next page is available.
    # -------------------------------------------------
    $currentUrl = $endpointUrl
    $allItems = @()
    $pageCount = 0

    try {
        while ($currentUrl) {
            $pageCount++

            $response = Invoke-RestMethod `
                -Method GET `
                -Uri $currentUrl `
                -Headers $headers `
                -ErrorAction Stop

            if ($response.items) {
                $allItems += $response.items
            }

            $nextLink = $null

            # -----------------------------------------
            # Support different next-page property names
            # -----------------------------------------
            if ($response.PSObject.Properties.Name -contains "@odata.nextLink") {
                $nextLink = $response.'@odata.nextLink'
            }
            elseif ($response.PSObject.Properties.Name -contains "nextLink") {
                $nextLink = $response.nextLink
            }

            if ($pageCount % 5 -eq 0) {
                Write-Host "[INFO] Trend pages processed: $pageCount | Total so far: $($allItems.Count)" -ForegroundColor White
            }

            $currentUrl = $nextLink
        }
    }
    catch {
        throw "Trend Vision One API collection failed: $($_.Exception.Message)"
    }

    if (-not $allItems -or $allItems.Count -eq 0) {
        throw "Trend Vision One collection completed but returned no endpoint data."
    }

    Write-Host "[OK] Trend collection complete" -ForegroundColor Green
    Write-Host "[INFO] Total endpoints collected: $($allItems.Count)" -ForegroundColor White
    Write-Host "[INFO] Pages processed: $pageCount" -ForegroundColor White

    # -------------------------------------------------
    # Export full raw dataset
    # -------------------------------------------------
    $date = Get-Date -Format "yyyyMMdd-HHmm"

    $rawFullPath = Join-Path $RawDataPath "raw_trend_endpoints_full_$date.json"

    $fullExport = [PSCustomObject]@{
        collectedAt = (Get-Date).ToString("o")
        pages       = $pageCount
        totalItems  = $allItems.Count
        items       = $allItems
    }

    $fullExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $rawFullPath -Encoding UTF8

    Write-Host "[OK] Full raw export saved: $rawFullPath" -ForegroundColor Green

    # -------------------------------------------------
    # Filtering - exclude servers
    # -------------------------------------------------
    # The BYOD project focuses on endpoint/workstation-style
    # devices, so servers are filtered out from the main
    # processed export.
    # -------------------------------------------------
    $workstations = $allItems | Where-Object {
        if ($_.PSObject.Properties.Name -contains "osName" -and $_.osName) {
            $_.osName -notmatch "Server"
        }
        else {
            # If osName is missing, keep the record instead of
            # discarding potentially useful endpoint data.
            $true
        }
    }

    Write-Host "[INFO] Workstations detected: $($workstations.Count)" -ForegroundColor Magenta

    # -------------------------------------------------
    # Export filtered workstation dataset
    # -------------------------------------------------
    $workstationsPath = Join-Path $ProcessedDataPath "trend_workstations_$date.json"

    $workstations | ConvertTo-Json -Depth 10 | Out-File -FilePath $workstationsPath -Encoding UTF8

    Write-Host "[OK] Workstations export saved: $workstationsPath" -ForegroundColor Green

    # -------------------------------------------------
    # Optional preview
    # -------------------------------------------------
    # Useful during manual collection or troubleshooting.
    # Disabled when -NoPreview is used.
    # -------------------------------------------------
    if (-not $NoPreview) {
        Write-Host "[STEP] Preview of first 20 workstations" -ForegroundColor Cyan

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