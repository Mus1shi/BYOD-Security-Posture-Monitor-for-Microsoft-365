# =====================================================
# MICROSOFT GRAPH AUTHENTICATION - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Authenticate to Microsoft Graph using app-only credentials.
#
# Public repository note:
# - this function is intended for optional live testing only
# - the public demo version does not require real credentials
# - demo mode should skip Graph authentication entirely
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

    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        throw "TenantId is missing."
    }

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        throw "ClientId is missing."
    }

    if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
        throw "ClientSecret is missing."
    }

    $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    $body = @{
        client_id     = $ClientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }

    try {
        $tokenResponse = Invoke-RestMethod `
            -Method POST `
            -Uri $tokenUri `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded"

        if (-not $tokenResponse.access_token) {
            throw "Microsoft Graph token response does not contain access_token."
        }

        Write-Host "[OK] Microsoft Graph access token acquired" -ForegroundColor Green
        return $tokenResponse.access_token
    }
    catch {
        Write-Host "[ERROR] Microsoft Graph authentication failed" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}