# =====================================================
# DEFENDER DEVICE COLLECTION - PUBLIC VERSION
# =====================================================
# Purpose:
# Collect Microsoft Defender for Endpoint devices
# and prepare a lookup map for correlation.
#
# Status:
# - OPTIONAL module
# - not required for demo mode
# - can be enabled later without refactoring
#
# API:
# https://api.security.microsoft.com/api/machines
# =====================================================

# =====================================================
# AUTHENTICATION
# =====================================================

function Get-DefenderAccessToken {
    param (
        [Parameter(Mandatory)] [string]$TenantId,
        [Parameter(Mandatory)] [string]$ClientId,
        [Parameter(Mandatory)] [string]$ClientSecret
    )

    try {
        Write-Host "[STEP] Authenticating to Defender API" -ForegroundColor Cyan

        $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

        $body = @{
            client_id     = $ClientId
            scope         = "https://api.security.microsoft.com/.default"
            client_secret = $ClientSecret
            grant_type    = "client_credentials"
        }

        $token = Invoke-RestMethod `
            -Method POST `
            -Uri $tokenUri `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded"

        if (-not $token.access_token) {
            throw "Defender token is empty"
        }

        Write-Host "[OK] Defender authentication successful" -ForegroundColor Green

        return $token.access_token
    }
    catch {
        Write-Host "[ERROR] Defender authentication failed" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

# =====================================================
# DEVICE COLLECTION
# =====================================================

function Get-DefenderDevices {
    param (
        [Parameter(Mandatory)] [string]$AccessToken
    )

    Write-Host "[STEP] Collecting Defender devices" -ForegroundColor Cyan

    $headers = @{
        Authorization = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    $uri = "https://api.security.microsoft.com/api/machines"
    $devices = @()

    try {
        do {
            $response = Invoke-RestMethod `
                -Method GET `
                -Uri $uri `
                -Headers $headers

            if ($response.value) {
                $devices += $response.value
                Write-Host "[INFO] Defender page collected: $($response.value.Count)" -ForegroundColor White
            }

            if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
                $uri = $response.'@odata.nextLink'
            }
            else {
                $uri = $null
            }

        } while ($uri)

        Write-Host "[OK] Defender devices collected: $($devices.Count)" -ForegroundColor Green

        return $devices
    }
    catch {
        Write-Host "[ERROR] Defender device collection failed" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

# =====================================================
# DEVICE MAP (AadDeviceId → Defender device)
# =====================================================

function New-DefenderDeviceMap {
    param (
        [Parameter(Mandatory)] [array]$DefenderDevices
    )

    $map = @{}

    foreach ($device in $DefenderDevices) {

        if (-not $device.aadDeviceId) {
            continue
        }

        if (-not $map.ContainsKey($device.aadDeviceId)) {
            $map[$device.aadDeviceId] = $device
        }
    }

    Write-Host "[OK] Defender device map created: $($map.Count)" -ForegroundColor Green

    return $map
}

# =====================================================
# OPTIONAL NORMALIZATION (FUTURE USE)
# =====================================================
# This block is not used yet but ready for future integration
# into correlation / risk engine.
# =====================================================

function Get-DefenderDeviceSummary {
    param (
        [Parameter(Mandatory)] $Device
    )

    return [PSCustomObject]@{
        defender_device_id         = $Device.id
        defender_aad_device_id     = $Device.aadDeviceId
        defender_dns_name          = $Device.computerDnsName
        defender_os_platform       = $Device.osPlatform

        defender_risk_score        = $Device.riskScore
        defender_exposure_level    = $Device.exposureLevel

        defender_onboarding_status = $Device.onboardingStatus
        defender_health_status     = $Device.healthStatus

        defender_last_seen         = $Device.lastSeen
        defender_first_seen        = $Device.firstSeen
    }
}