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

function Get-EntraDeviceInfoByDeviceId {
    param (
        [parameter(Mandatory)] [string] $DeviceId,
        [parameter(Mandatory)] [hashtable] $Headers
    )

    $uri = "https://graph.microsoft.com/v1.0/devices?`$filter=devideId eq '$DeviceId'&`$select=deviceId,trustType,accountEnabled,displayName"
    $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $Headers

    if ($resp.value.count -eq 0) { return $null }
    return $resp.value[0]
    
}

#=============================
# ENTRA COLLECT (TEST 1 PAGE)
#=============================
#But : Valider que la requête Grapah /devices fonctionne et vérifier la présence du NextLink
# Cette fonction sert uniquement de "proof /test"
#=============================

function Get-EntraDevices {
    param (
    [parameter(Mandatory)] [hashtable] $Headers
)
 
$uri = "https://graph.microsoft.com/V1.0/devices?`$select=deviceId,displayName,trustType,operatingSystem,operatingSystemVersion,approximateLastSignInDateTime,accountEnabled"
$resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $Headers

$nextLink = $null

   if ($resp.PRObject.Properties.Name -contains '@odata.nextLink') {
    $nextLink = $resp.'@odata.nextLink'
   }
   elseif ($resp.PRObject.Properties.Name -contains 'nextLink') {
    $nextLink = $resp.nextLink
   }

   $fullExport = [PSCustomObject]@{
    devices = $resp.value
    nextLink = $nextLink
   }
return $fullExport
}

#===============================
# PREUVE DE PAGINATION
#===============================
# On appelle une page pour confirmer : le nbr de device retorunés et la présence du nextlink

$page1 = Get-EntraDevices -Headers $headers
write-host "devices page1 = " $page1.devices.count

if ($null -eq $page1.nextLink) {
    Write-Host "NextLink est vide !" -ForegroundColor Red
}else {
    Write-Host "NextLink est présent !" -ForegroundColor Blue
}

$page1.devices | Select-Object displayname, trustType, deviceEd -First 5


#==============================
# ENTRA COLLECT (FULL)
#==============================
# Collecte complète des devices Entra via pagination @odata.nextLink
# Output : liste plate de devixes (array)
#==============================


function Get-AllEntraDevices {
    param (
        [parameter (Mandatory)] [hashtable] $Headers
    )

    $Currenturl = "https://graph.microsoft.com/V1.0/devices?`$select=deviceId,displayName,trustType,operatingSystem,operatingSystemVersion,approximateLastSignInDateTime,accountEnabled"
    $allItems = @()
    $pageCount = 0

    try {
        while ($currentUrl){

            $resp = Invoke-RestMethod -Method GET -uri $Currenturl -Headers $Headers
            $pageCount++

            write-host "Calling page $pageCount ..." -ForegroundColor Yellow

            if ($resp.value) {
                $allItems += $resp.value
            }

            #Gestion du NextLink

            $nextLink = $null

            if ($resp.PSObject.Properties.Name -contains '@odata.nextLink') {
                $nextLink = $resp.'@odata.nextLink'
            }
            elseif ($resp.PSObject.Properties.Name -contains 'nextlink') {
                $nextLink = $resp.nextLink
            }

            Write-Host ("Page {0} collected | Total so far: {1}" -f `
                $pageCount, $allItems.Count)
            
            $currentUrl = $nextLink
        }
    }
catch {
    Write-Error "Erreur graph Entra : $($_.Exception.Message)"
    exit
}
return $allItems

}











