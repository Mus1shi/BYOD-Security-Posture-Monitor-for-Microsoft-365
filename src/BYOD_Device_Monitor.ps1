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

 

#récup des identifiants depuis les variable d'env

#évite de stocker directement dans le code

 

$TenantId = $env:GRAPH_TENANT_ID

$ClientId = $env:GRAPH_CLIENT_ID

$ClientSecret = $env:GRAPH_SECRET

$TrendApiKey = $env:TREND_API_KEY

 

#Vérifie que toutes lers valeurs nécessaires sont présentes sinon stop

 

if (-not $TenantId -or -not $ClientId -or -not $ClientSecret -or -not $TrendApiKey) {

    throw "varable missed"

}

 

#Stop le script en cas d'erreur

 

$ErrorActionPreference = "Stop"

 

#==============================

# AUTHENTIFICATION GRAPH (APP-ONLY)

#==============================

 

#Co a Graph avec l'application (mode "app-only")

#Permet au service d'obtenir un token sans utilisateur

 

$tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

 

#Corps de la requête

#.default signifie : "donne-moi ttes les perm déjà accordées"

 

$body = @{

    Client_id     = $ClientId

    scope         = "https://graph.microsoft.com/.default"

    client_secret = $ClientSecret

    grant_type    = "client_credentials"

}

 

#envoi de la requête pour obtenir un access_token

 

$token = Invoke-RestMethod -Method POST -Uri $tokenUri -Body $body -ContentType "application/x-www-form-urlencoded"

Write-Host "Token received OK"

 

if (-not $token.access_token) {

    throw "TOKEN ERROR: access_token is empty. Check tenant/client/secret env vars and app credentials."

}

Write-Host "Access token length: $($token.access_token.Length)" -ForegroundColor Green

 

#création de l'en-tête HTTP avec token d'accès

#chaque appel graph doit contenir "Authorization : Bearer <token>"

 

$headers = @{ Authorization = "Bearer $($token.access_token)" }

 

#Affiche les infos de session pour verifier la co

 

Write-Host "Auth token ready" -ForegroundColor Gray

 

# ==============================

# ENTRA LOOKUP (UNITAIRE)

# ==============================

# Fonction utilisée pour valider rapidement qu’un deviceId Intune existe bien côté Entra

# (à terme, on évite le 1 call = 1 device : on fera du matching "bulk")

# ==============================

 

function Get-EntraDeviceInfoByDeviceId {

   

    param (

        [parameter(Mandatory)] [string] $DeviceId,

        [parameter(Mandatory)] [hashtable] $Headers

    )

 

    $uri = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$DeviceId'&`$select=deviceId,trustType,accountEnabled,displayName"

    $r = Invoke-RestMethod -Method GET -Uri $uri -Headers $Headers

 

    if ($r.value.count -eq 0) { return $null }

    return $r.value[0]

   

}

 

# ==============================

# ENTRA COLLECT (TEST 1 PAGE)

# ==============================

# But : valider que la requête Graph /devices fonctionne et vérifier la présence du nextLink

# Cette fonction sert uniquement de "proof" / test.

# ==============================

 

function Get-EntraDevices {

    param (

        [parameter(Mandatory)] [hashtable] $Headers

    )

   

    $uri = "https://graph.microsoft.com/v1.0/devices?`$select=deviceId,displayName,trustType,operatingSystem,operatingSystemVersion,approximateLastSignInDateTime,accountEnabled"

    $r = Invoke-RestMethod -Method GET -Uri $uri -Headers $Headers

 

   

    $nextLink = $null

 

    if ($r.PSObject.Properties.Name -contains '@odata.nextLink') {

        $nextLink = $r.'@odata.nextLink'

    }

    elseif ($r.PSObject.Properties.Name -contains 'nextLink') {

        $nextLink = $r.nextLink

    }

 

    $fullExport = [pscustomobject]@{

        devices  = $r.value

        nextLink = $nextLink

    }

    return $fullExport

}

 

# ==============================

# PREUVE DE PAGINATION

# ==============================

# On appelle 1 page pour confirmer :

# - nombre de devices retournés

# - présence du nextLink (si >1 page)

# ==============================

 

#$page1 = Get-EntraDevices -Headers $headers

#Write-Host "devices page1 = " $page1.devices.count

 

#if ($null -eq $page1.nextLink) {

#   Write-Host "NextLink est vide !" -ForegroundColor Red

#}else {

#   Write-Host "NextLink Présent !" -ForegroundColor Blue

#}

 

#$page1.devices | Select-Object displayName, trustType, deviceId -First 5

 

# ==============================

# ENTRA COLLECT (FULL)

# ==============================

# Collecte complète des devices Entra via pagination @odata.nextLink

# Output : liste plate de devices (array)

# ==============================

 

function Get-AllEntraDevices {

    param (

        [parameter(Mandatory)] [hashtable] $Headers

    )

   

    $currentUrl = "https://graph.microsoft.com/v1.0/devices?`$select=deviceId,displayName,trustType,operatingSystem,operatingSystemVersion,approximateLastSignInDateTime,accountEnabled"

    $allItems = @()

    $pageCount = 0

 

    try {

 

        while ($currentUrl) {

       

            $resp = Invoke-RestMethod -Method GET -Uri $currentUrl -Headers $Headers

            $pageCount++

 

            #Write-Host "Calling page $pageCount ..." -ForegroundColor Yellow

 

            if ($resp.value) {

                $allItems += $resp.value

            }

 

            # Gestion du nextLink

 

            $nextLink = $null

 

            if ($resp.PSObject.Properties.Name -contains '@odata.nextLink') {

                $nextLink = $resp.'@odata.nextLink'

            }

            elseif ($resp.PSObject.Properties.Name -contains 'nextLink') {

                $nextLink = $resp.nextLink

            }

 

            #Write-Host ("Page {0} collected | Total so far: {1}" -f `

            #    $pageCount, $allItems.Count)

 

            $currentUrl = $nextLink

        }

 

    }

    catch {

        Write-Error "Erreur Graph Entra : $($_.Exception.Message)"

        exit

    }

    return $allItems

 

}

 

# ==============================

# EXPORT ENTRA

# ==============================

# Export "raw" : dataset complet Entra (utile pour debug + corrélation future)

# Export "processed" : subset des devices Registered (trustType = Workplace)

# ==============================

 

$entraAll = Get-AllEntraDevices -Headers $headers

 

$date = Get-Date -Format "yyyyMMdd-HHmm"

 

$rawFullPath = "data/raw/raw_entra_full_devices_$date.json"

 

$fullExport = [pscustomobject]@{

    collectedAt  = (Get-Date).ToString("o")

    totalDevices = $entraAll.Count

    devices      = $entraAll

}

 

$fullExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $rawFullPath -Encoding UTF8

 

Write-Host "Full raw export saved to $rawFullPath" -ForegroundColor Gray

 

Write-Host "TOTAL Entra devices = $($entraAll.Count)" -ForegroundColor Green

 

# ==============================

# FILTER ENTRA : REGISTERED (WORKPLACE)

# ==============================

# Registered = device BYOD "registré" (pas forcément managed)

# Utilisé pour la vue BYOD / comparaison avec Intune et Trend

# ==============================

 

$entraRegistered = $entraAll | Where-Object { $_.trustType -eq "Workplace" }

 

Write-Host "Total Entra registered (Workplace) = $($entraRegistered.Count)" -ForegroundColor Green

 

$registeredPath = "data/processed/entra_registered_devices_$date.json"

 

$registeredExport = [pscustomobject]@{

    collectedAt     = (Get-Date).ToString("o")

    trustTypeFilter = "Workplace"

    totalDevices    = $entraRegistered.Count

    devices         = $entraRegistered

}

 

$registeredExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $registeredPath -Encoding UTF8

 

Write-Host "Registered export saved to $registeredPath" -ForegroundColor Gray

 

# ==============================

# INTUNE COLLECT (FULL)

# ==============================

# Collecte complète des managedDevices via pagination @odata.nextLink

# Output : CSV normalisé (colonnes stables pour corrélation)

# ==============================

 

#==============================

# COLLECTE INTUNE

# Récupération des managedDevices

#==============================

#test si les perms graph sont ok

 

try {

 

    #Normalisation des colonnes pour export propre

    #On projette uniquement les champs utiles

    #Crée un tableau d'objet pour les colonnes, plus propre pour l'export

 

    $props = @(

        @{ expression = { $_.serialNumber }; label = 'SERIAL_NUMBER' },

        @{ expression = { $_.deviceName }; label = 'DEVICE' },

        @{ expression = { $_.userPrincipalName }; label = 'USER' },

        @{ expression = { $_.complianceState }; label = 'COMPLIANCE' } ,

        @{ expression = { $_.operatingSystem }; label = 'OS' },

        @{ expression = { $_.osVersion }; label = 'OS_VERSION' },

        @{ expression = { $_.enrolledDateTime }; label = 'ENROLLED_DATE' },

        @{ expression = { $_.id }; label = 'INTUNE_DEVICE_ID' },

        @{ expression = { $_.azureADDeviceId }; label = 'AZURE_AD_DEVICE_ID' },

        @{ expression = { $_.managedDeviceOwnerType }; label = 'OWNERSHIP_INTUNE' }

    )

 

    # --- PAGINATION START ---

 

    $CurrentUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=serialNumber,deviceName,userPrincipalName,operatingSystem,osVersion,complianceState,enrolledDateTime,id,azureADDeviceId,managedDeviceOwnerType"

    $AllDevices = @()

    $PageCount = 0

 

    while ($CurrentUrl) {

        $Response = Invoke-RestMethod -Method GET -Uri $CurrentUrl -Headers $headers

        $PageCount++

        $countThisPage = @($Response.value).Count

        Write-Host "Page: $PageCount | Devices in page: $countThisPage" -ForegroundColor Blue

 

        $AllDevices += $Response.value

        $CurrentUrl = $Response.'@odata.nextLink'

    }

    $cleanExport = $AllDevices | Select-Object $props

 

    #================================

    #--------Test de jointure--------

    #================================

 

    #====================================

    #--------Intune <-----> Entra--------

    #====================================

    #$listeIntuneWithAAD = $cleanExport | Where-Object { $_.AZURE_AD_DEVICE_ID }

 

    #Write-Host "Intune devices with AzureADDeviceId = $($listeIntuneWithAAD.Count)" -ForegroundColor Green

 

    #$matched = 0

 

    #foreach ($device in $listeIntuneWithAAD) {

 

    #    $entraMatch = $entraAll | Where-Object { $_.deviceId -eq $device.AZURE_AD_DEVICE_ID }

 

    #    if ($entraMatch) {

    #       $matched++

    #  }

 

    #}

 

    #Write-Host "Intune devices matched in Entra = $matched" -ForegroundColor Cyan

 

    # ==============================

    # PLACEHOLDER ENRICHISSEMENT ENTRA

    # ==============================

    # On prépare une colonne ENTRA_TRUST_TYPE dans le dataset Intune

    # Pour l'instant : remplissage sur 1 device (test)

    # Étape suivante : enrichissement en masse via matching bulk Intune ↔ Entra

    # ==============================

 

    foreach ($row in $cleanExport) {

       

       

        if ( $null -eq $row ) {

            continue

        }

 

        Add-Member -InputObject $row -NotePropertyName "ENTRA_TRUST_TYPE" -NotePropertyValue $null -Force

    }

 

    $totalIntuneDevices = $cleanExport.Count

    $intuneWithAADCount = 0

    $matchedInEntraCount = 0

    $notMatchedInEntraCount = 0

    $entraTrustTypeFilledCount = 0

 

    #Boucle sur toutes les ligne Intune

    foreach ($row in $cleanExport) {

 

        if (-not $row.AZURE_AD_DEVICE_ID) {

            continue

        }

 

        $intuneWithAADCount++

 

        #recherche du devic Entra correspondant

        $entraMatch = $entraAll | Where-Object { $_.deviceId -eq $row.AZURE_AD_DEVICE_ID }

 

        if ($entraMatch) {

            $matchedInEntraCount ++

         

            #on remplit la colonne ENTRA_TRUST_TYPE avec la valeur trusType trouvé dans Entra

            $row.ENTRA_TRUST_TYPE = $entraMatch.trustType

         

            if ($row.ENTRA_TRUST_TYPE) {

                $entraTrustTypeFilledCount++

                     

            }

        }

        else {

            $notMatchedInEntraCount++

        }

 

    }

 

    #Write-Host "Total Intune devices = $totalIntuneDevices" -ForegroundColor Yellow

    #Write-Host "Intune devices with AzureADDeviceId = $intuneWithAADCount" -ForegroundColor Yellow

    #Write-Host "Intune devices matched in Entra = $matchedInEntraCount" -ForegroundColor Yellow

    #Write-Host "Intune devices not matched in Entra = $notMatchedInEntraCount" -ForegroundColor Yellow

    #Write-Host "Intune devices enriched with ENTRA_TRUST_TYPE = $entraTrustTypeFilledCount" -ForegroundColor Yellow




    $trendPath = Get-ChildItem -Path "data/processed/" -Filter "trend_workstations_*.json" | Sort-Object -Property CreationTime | Select-Object -Last 1

    $trendJson = Get-content $trendPath -Raw

    $trendDevices = $trendJson  | ConvertFrom-Json

 

    #$trendDevices.GetType().FullName

    #$trendDevices | Select-Object -First 1 | Format-List *

 

    Write-Host "Trend devices loaded =" $trendDevices.count -ForegroundColor Cyan

 

    #$trendDevices | Select-Object endpointName -First 5

 

    #======================================

    #-------- Correlation Trend------------

    #======================================

 

    $CorrelateDevices = @()

 

    foreach ($device in $trendDevices) {

 

        $entraMatch = $null

        $intuneMatch = $null

        $match_reason = $null

        $match_status = $null

 

        $entraMatch = $entraAll | Where-Object { $_.displayName -eq $device.endpointName }

 

        if ($entraMatch) {

 

            #Write-Host "Found Entra match for" $device.endpointName -ForegroundColor Blue

            $intuneMatch = $cleanExport | Where-Object { $_.AZURE_AD_DEVICE_ID -eq $entraMatch.deviceId }

 

            if ($intuneMatch) {

 

                #Write-Host "Found Intune match"

                $match_status = "matched"

                $match_reason = "trend_to_entra_on_name + entra_to_intune_on_deviceId"

 

            }

            else {

 

                $match_status = "partial"

                $match_reason = "trend_to_entra_on_name"

 

            }

        }

        else {  

 

            $match_status = "unmatched"

            $match_reason = "trend_only_no_entra_match"

        }




        $CorrelateObject = [PSCustomObject]@{

            device_name  = $device.endpointName

            trend        = $device

            entra        = $entraMatch

            intune       = $intuneMatch

            match_status = $match_status

            match_reason = $match_reason

   

   

 

        }

        $CorrelateDevices += $CorrelateObject

 

    }

 

    $DevicesMatched = $CorrelateDevices | Where-Object { $_.match_status -eq "matched" }

    $DevicesPartial = $CorrelateDevices | Where-Object { $_.match_status -eq "partial" }

    $DevicesUnmatched = $CorrelateDevices | Where-Object { $_.match_status -eq "unmatched" }

 

    #Write-Host " "

    #Write-Host "=========================="

    #Write-Host "    Correlation Summary   "

    #Write-Host "=========================="

    #write-host " "

    #Write-Host "Total devices : " $CorrelateDevices.count -ForegroundColor Blue

    #write-host "Devices matched : " $DevicesMatched.count -ForegroundColor Blue

    #Write-Host "Devices partial : " $DevicesPartial.count -ForegroundColor Blue

    #Write-Host "Devices unmatched : " $DevicesUnmatched.count -ForegroundColor Blue

    #Write-Host  " "

    #Write-Host "=========================="




    #=============================

    # HELPDESK DATA SET

    #=============================

 

    $helpdeskCases = @()

 

    foreach ($device in $CorrelateDevices) {

 

        if ($device.match_status -eq "unmatched") {

 

            $deviceName = $device.device_name

            $caseStatus = "unmatched"

            $caseReason = "Device found in Trend Micro but not found in Entra ID"

            $recommendedAction = "Investigate device origin and tenant registration"

            $caseUser = "unknown"

            #$caseTrustType = "Trend Only"

   

            $HelpDeskObject = [PSCustomObject]@{

                device_name        = $deviceName

                user               = $caseUser

                reason             = $caseReason

                recommended_action = $recommendedAction

                status             = $caseStatus

                #case_type = $caseTrustType

            }

            $helpdeskCases += $HelpDeskObject

 

        }

        elseif ($device.intune -and $device.intune.COMPLIANCE -eq "noncompliant") {

 

            $deviceName = $device.device_name

            $caseStatus = "noncompliant"

            $caseReason = "Device NONCOMPLIANT"

            $recommendedAction = "Urgently investigate on the case"

            $caseUser = $device.intune.USER

            #$caseTrustType = "Device NON COMPLIANT"

 

            $HelpDeskObject = [PSCustomObject]@{

                device_name        = $deviceName

                user               = $caseUser

                reason             = $caseReason

                recommended_action = $recommendedAction

                status             = $caseStatus

                #case_type = $caseTrustType

            }

            $helpdeskCases += $HelpDeskObject

 

        }

        elseif ($device.match_status -eq "partial") {

 

           

            $deviceName = $device.device_name

            $caseStatus = "partial"

            $caseReason = "Device found in Trend Micro and Entra ID, BUT not in Intune"

            $recommendedAction = "Investigate device origin and tenant registration"

            $caseUser = $null

            #$caseTrustType = "Trend Micro and Entra ID Only"

 

            if ($device.intune.USER) {

                $caseUser = $device.intune.USER

            }

            else {

                $caseUser = "unknown"

            }

 

            $HelpDeskObject = [PSCustomObject]@{

                device_name        = $deviceName

                user               = $caseUser  

                reason             = $caseReason

                recommended_action = $recommendedAction

                status             = $caseStatus

                #case_type = $caseTrustType

            }

            $helpdeskCases += $HelpDeskObject

 

        }

        elseif ($device.entra -and $device.entra.trustType -eq "Workplace") {

 

            $deviceName = $device.device_name

            $caseStatus = "workplace"

            $caseReason = "BYOD device registered in Entra ID"

            $recommendedAction = "Verify if BYOD usage is expected"

            $caseUser = "unknown"

            #$caseTrustType = "Trend Micro and Entra ID Only"

 

            $HelpDeskObject = [PSCustomObject]@{

                device_name        = $deviceName

                user               = $caseUser  

                reason             = $caseReason

                recommended_action = $recommendedAction

                status             = $caseStatus

                #case_type = $caseTrustType

            }

            $helpdeskCases += $HelpDeskObject

        }

    }

 

   # Write-Host ""

    #write-host "Total helpsdesk cases : " $HelpdeskCases.Count

    #Write-Host ""

    #$helpdeskCases | Select-Object -First 5

 

    $HelpDeskCases = $HelpdeskCases | Sort-Object @{

        Expression = {

            switch ($_.status) {

                "unmatched" { 0 }

                "noncompliant" { 1 }

                "partial" { 2 }

                "workplace" { 3 }

                default { 4 }

            }

        }

    }

 

    $date = Get-Date -Format "yyyyMMdd-HHmm"

 

    $HelpDeskReportPathCsv = "./data/reports/helpdesk_report_$date.csv"

    $HelpDeskReportPathJson = "./data/reports/helpdesk_report_$date.json"

 

    $HelpdeskCases | Export-Csv -Path $HelpDeskReportPathCsv -NoTypeInformation -Delimiter ";"

 

    $HelpdeskCases | ConvertTo-Json -Depth 5 | Out-File -FilePath $HelpDeskReportPathJson -Encoding UTF8

 

    #Write-Host "Helpdesk report exported" -ForegroundColor Blue

    #Write-Host "File :" $HelpDeskReportPath -ForegroundColor Blue

    #Write-Host "Total cases :" $HelpdeskCases.Count -ForegroundColor Blue

 

# ============================

# BYOD DEVICE MONITOR REPORT

# ============================

 

$helpdeskNoncompliant = ($HelpdeskCases | Where-Object { $_.status -eq "noncompliant" }).Count

$helpdeskPartial      = ($HelpdeskCases | Where-Object { $_.status -eq "partial" }).Count

$helpdeskUnmatched    = ($HelpdeskCases | Where-Object { $_.status -eq "unmatched" }).Count

$helpdeskWorkplace    = ($HelpdeskCases | Where-Object { $_.status -eq "workplace" }).Count

 

Write-Host ""

Write-Host "============================" -ForegroundColor Cyan

Write-Host "BYOD DEVICE MONITOR REPORT" -ForegroundColor Cyan

Write-Host "============================" -ForegroundColor Cyan

Write-Host ""

Write-Host "Total Trend devices : $($trendDevices.Count)" -ForegroundColor White

Write-Host ""

Write-Host "Matched   : $($DevicesMatched.Count)" -ForegroundColor Green

Write-Host "Partial   : $($DevicesPartial.Count)" -ForegroundColor Yellow

Write-Host "Unmatched : $($DevicesUnmatched.Count)" -ForegroundColor Red

Write-Host ""

Write-Host "Helpdesk cases : $($HelpdeskCases.Count)" -ForegroundColor Magenta

Write-Host ""

Write-Host "Noncompliant : $helpdeskNoncompliant" -ForegroundColor Yellow

Write-Host "Partial      : $helpdeskPartial" -ForegroundColor Yellow

Write-Host "Unmatched    : $helpdeskUnmatched" -ForegroundColor Yellow

Write-Host "Workplace    : $helpdeskWorkplace" -ForegroundColor Yellow

Write-Host ""

Write-Host "Report exported :" -ForegroundColor Cyan

Write-Host $HelpDeskReportPathCsv -ForegroundColor Cyan

Write-Host $HelpDeskReportPathJson -ForegroundColor Cyan

Write-Host ""

Write-Host "============================" -ForegroundColor Cyan

 

    # ==============================

    # Tri Intune par priorité de conformité pour lecture et export CSV

    # ==============================

    # Vérifie que AZURE_AD_DEVICE_ID (Intune) matche deviceId (Entra)

    # ==============================

 

    #Tri des devices par priorité de conformité

    #filtre la colonne compliance par priorité

 

    $cleanExport = $cleanExport | Sort-Object @{

        Expression = {

            switch ($_.COMPLIANCE) {

                "noncompliant" { 0 }

                "inGracePeriod" { 1 }

                "configManager" { 2 }

                default { 3 }

            }

        }

    }

 

    # ==============================

    # EXPORT INTUNE

    # ==============================

    # Export CSV horodaté pour conserver l'historique des runs

    # Base de travail pour la future corrélation multi-sources

    # ==============================

 

    $date = Get-Date -Format "yyyyMMdd-HHmm"

    #$cleanExport | Format-Table

    $cleanExport | Export-CSV -Path ./data/processed/BYOD_Intune_ManagedDevices_$date.csv -NoTypeInformation -Delimiter ";"

}

 

catch {

    #Si l'appel échoue, on affiche le msg

   

    Write-Host "Graph call failed " -ForegroundColor Red

    Write-Host $_.Exception.Message

    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {

        Write-Host $_.ErrorDetails.Message

    }

}

 