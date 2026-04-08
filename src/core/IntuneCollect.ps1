# =====================================================
# INTUNE DEVICE COLLECTION - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Retrieve the full Intune managed device inventory either
# from Microsoft Graph (live mode) or from a local sample
# JSON file (demo mode), then normalize and enrich it with
# Entra trust type information.
# =====================================================

function Get-IntuneDevices {
    param (
        [hashtable]$Headers,
        [hashtable]$EntraByDeviceId,
        [switch]$DemoMode,
        [string]$SampleIntuneFile
    )

    Write-Host "[STEP] Collecting Intune devices" -ForegroundColor Cyan

    # =====================================================
    # PROPERTIES USED FOR NORMALIZATION
    # =====================================================
    $props = @(
        @{ expression = { $_.serialNumber };           label = 'SERIAL_NUMBER' },
        @{ expression = { $_.deviceName };             label = 'DEVICE' },
        @{ expression = { $_.userPrincipalName };      label = 'USER' },
        @{ expression = { $_.complianceState };        label = 'COMPLIANCE' },
        @{ expression = { $_.operatingSystem };        label = 'OS' },
        @{ expression = { $_.osVersion };              label = 'OS_VERSION' },
        @{ expression = { $_.enrolledDateTime };       label = 'ENROLLED_DATE' },
        @{ expression = { $_.lastSyncDateTime };       label = 'LAST_SYNC' },
        @{ expression = { $_.id };                     label = 'INTUNE_DEVICE_ID' },
        @{ expression = { $_.azureADDeviceId };        label = 'AZURE_AD_DEVICE_ID' },
        @{ expression = { $_.managedDeviceOwnerType }; label = 'OWNERSHIP_INTUNE' }
    )

    $allDevices = @()

    # =====================================================
    # DEMO MODE - LOAD LOCAL SAMPLE FILE
    # =====================================================
    if ($DemoMode) {
        Write-Host "[INFO] Demo mode active - loading sample Intune dataset" -ForegroundColor White

        if (-not $SampleIntuneFile) {
            throw "Demo mode is enabled, but no SampleIntuneFile path was provided."
        }

        if (-not (Test-Path $SampleIntuneFile)) {
            throw "Sample Intune file not found: $SampleIntuneFile"
        }

        $sampleContent = Get-Content -Path $SampleIntuneFile -Raw | ConvertFrom-Json

        if ($sampleContent.devices) {
            $allDevices = @($sampleContent.devices)
        }
        elseif ($sampleContent.value) {
            $allDevices = @($sampleContent.value)
        }
        elseif ($sampleContent -is [System.Collections.IEnumerable]) {
            $allDevices = @($sampleContent)
        }
        else {
            throw "Sample Intune file format is not recognized. Expected an array, a 'devices' property, or a 'value' property."
        }

        Write-Host "[OK] Sample Intune devices loaded: $($allDevices.Count)" -ForegroundColor Green
    }

    # =====================================================
    # LIVE MODE - MICROSOFT GRAPH
    # =====================================================
    else {
        if (-not $Headers) {
            throw "Live Intune collection requires Graph headers."
        }

        $url = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=serialNumber,deviceName,userPrincipalName,operatingSystem,osVersion,complianceState,enrolledDateTime,lastSyncDateTime,id,azureADDeviceId,managedDeviceOwnerType"

        while ($url) {
            $response = Invoke-RestMethod -Method GET -Uri $url -Headers $Headers

            if ($response.value) {
                $allDevices += $response.value
            }

            if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
                $url = $response.'@odata.nextLink'
            }
            elseif ($response.PSObject.Properties.Name -contains 'nextLink') {
                $url = $response.nextLink
            }
            else {
                $url = $null
            }
        }

        Write-Host "[OK] Live Intune devices collected: $($allDevices.Count)" -ForegroundColor Green
    }

    # =====================================================
    # NORMALIZATION
    # =====================================================
    $cleanExport = $allDevices | Select-Object $props

    Write-Host "[OK] Intune normalization completed" -ForegroundColor Green

    # =====================================================
    # LOOKUP TABLE
    # =====================================================
    $intuneByDeviceId = @{}

    foreach ($row in $cleanExport) {
        if ($row.AZURE_AD_DEVICE_ID) {
            $intuneByDeviceId[$row.AZURE_AD_DEVICE_ID] = $row
        }
    }

    Write-Host "[OK] Intune lookup table prepared" -ForegroundColor Green

    # =====================================================
    # ENTRA ENRICHMENT
    # =====================================================
    foreach ($row in $cleanExport) {
        Add-Member -InputObject $row -NotePropertyName "ENTRA_TRUST_TYPE" -NotePropertyValue $null -Force

        if (
            $row.AZURE_AD_DEVICE_ID -and
            $EntraByDeviceId -and
            $EntraByDeviceId.ContainsKey($row.AZURE_AD_DEVICE_ID)
        ) {
            $row.ENTRA_TRUST_TYPE = $EntraByDeviceId[$row.AZURE_AD_DEVICE_ID].trustType
        }
    }

    Write-Host "[OK] Intune enrichment completed" -ForegroundColor Green

    # =====================================================
    # RETURN STRUCTURED DATA
    # =====================================================
    return [PSCustomObject]@{
        AllDevices   = $allDevices
        CleanDevices = $cleanExport
        ByDeviceId   = $intuneByDeviceId
    }
}