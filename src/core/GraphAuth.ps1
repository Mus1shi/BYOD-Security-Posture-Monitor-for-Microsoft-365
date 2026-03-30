# =====================================================
# MICROSOFT GRAPH AUTHENTICATION
# =====================================================
# Purpose:
# Request a Microsoft Graph access token using the
# OAuth 2.0 client credentials flow.
#
# Public GitHub version:
# - Safe to publish
# - No secret stored here
# - Intended for Live mode only
#
# Notes:
# - Demo mode should not call this function
# - Client secret must come from a secure local source
# =====================================================

function Get-GraphToken {
    param (
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter(Mandatory)]
        [string]$ClientSecret
    )

    Write-Host "[STEP] Requesting Microsoft Graph access token" -ForegroundColor Cyan

    # -------------------------------------------------
    # Input validation
    # -------------------------------------------------
    # Fail early if one of the required values is missing.
    # This makes Live mode errors easier to understand.
    # -------------------------------------------------
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        throw "TenantId is missing. Please check your Live configuration."
    }

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        throw "ClientId is missing. Please check your Live configuration."
    }

    if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
        throw "ClientSecret is missing. Please check your Live configuration."
    }

    # -------------------------------------------------
    # OAuth token endpoint
    # -------------------------------------------------
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    # -------------------------------------------------
    # Request body for client credentials flow
    # -------------------------------------------------
    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }

    try {
        $response = Invoke-RestMethod `
            -Method POST `
            -Uri $tokenUrl `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded" `
            -ErrorAction Stop
    }
    catch {
        throw "Microsoft Graph token request failed: $($_.Exception.Message)"
    }

    # -------------------------------------------------
    # Validate response
    # -------------------------------------------------
    if (-not $response.access_token) {
        throw "Microsoft Graph token request succeeded but no access token was returned."
    }

    Write-Host "[OK] Access token validated" -ForegroundColor Green
    Write-Host "[STEP] Graph authentication ready" -ForegroundColor Cyan

    return $response.access_token
}