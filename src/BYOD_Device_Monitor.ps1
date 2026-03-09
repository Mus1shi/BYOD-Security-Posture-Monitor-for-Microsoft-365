# ==========================================
# BYOD Security Posture Monitor
# Work in Progress
#
# This script is part of an ongoing project
# currently under active development.
# Structure and features may evolve.
# ==========================================

## Disclaimer

This project was developed to support security teams in monitoring BYOD devices in Microsoft 365 environments.

The version published in this repository is sanitized. All sensitive information, tenant identifiers, internal configurations and operational data have been removed or replaced with sample data.


#Les tenants d'env. contenant les clés pour avoir accès aux api.

$TenantId = $env:GRAPH_TENANT_ID
$ClientId = $env:GRAPH_CLIENT_ID
$ClientSecret = $env:GRAPH_SECRET
$TrandApiKey = $env:TREND_API_KEY

#Vérifie que toutes les valeurs nécessaires sont présentes sinon stop

if (-not $TenantId -or -not $ClientId -or -not $ClientSecret -or -not $TrandApiKey) {
    throw "variable missed"
}

$ErrorActionPreference = "Stop"

#==================================
# AUTHENTICATION GRAPH (APP ONLY)
#==================================

#Permet au service d'obtenir un token sans user

$tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.à/token"

#core de la requête

$body = @{
    Client_id = $ClientId
    scope = "https://graph.microsoft.com/.default"
    client_secret = $ClientSecret
    grant_type = "client_credentials"
}

#envoi de la requête pour obtenir un access_token

$token = Invoke-RestMethod -Method POST -Uri $tokenUri -Body $body -ContentType "application/x-www-Form-urlencoded"
Write-Host "Token reveived OK"

if (-not $token.access_token) {
    throw "TOKEN ERROR: access_token is empty. Check tenant/client/secret env vars and app credentials."
}
Write-Host "Access token length: $($token.access_token.length)" -ForegroundColor Green

#===========================
# ENTRA LOOKUP (UNITAIRE)
#===========================
#Fonction utilisée pour valider rapidement qu'un deviceId Intune existe bien côté Entramatching bulk deficnition
#Matching "Bulk" à venir
#==========================