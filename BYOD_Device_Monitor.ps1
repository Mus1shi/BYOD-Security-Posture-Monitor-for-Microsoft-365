# Script objective:

#1. App-only authentication to Microsoft Graph
#2. Extraction of managed devices from Intune
#3. Data normalization for export
#4. Enrichment via Entra ID (trustType)
#5. Preparation of a BYOD risk view

# Retrieve credentials from environment variables
# Avoid storing them directly in the code

$TenantId = $env:GRAPH_TENANT_ID
$ClientId = $env:GRAPH_CLIENT_ID
$ClientSecret = $env:GRAPH_SECRET
$TrendApiKey = $env:TREND_API_KEY

 

# Check that all required values are present, otherwise stop

if (-not $TenantId -or -not $ClientId -or -not $ClientSecret -or -not $TrendApiKey) {
    throw "varable missed"
}

#Stop the script if there is an error

$ErrorActionPreference = "Stop"

#==============================
# AUTHENTIFICATION GRAPH (APP-ONLY)
#==============================

# Co to Microsoft Graph using the application (app-only mode)
# Allows the service to obtain a token without a user

$tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

#body request
#.default means : "give me all the perm already accepted"

$body = @{
    Client_id     = $ClientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $ClientSecret
    grant_type    = "client_credentials"
}

# Send the request to obtain an access token

$token = Invoke-RestMethod -Method POST -Uri $tokenUri -Body $body -ContentType "application/x-www-form-urlencoded"

Write-Host "[OK] Graph token acquired" -ForegroundColor Green

if (-not $token.access_token) {
    throw "TOKEN ERROR: access_token is empty. Check tenant/client/secret env vars and app credentials."
}

Write-Host "Access token length: $($token.access_token.Length)" -ForegroundColor Green 

#creation of the HTTP header with token access
#each graph call should countain "Authorization : Bearer <token>"

$headers = @{ Authorization = "Bearer $($token.access_token)" }

Write-Host "[OK] Access token validated" -ForegroundColor Green
write-Host "[STEP] Graph authentification ready" -ForegroundColor Cyan

# ==============================
# ENTRA COLLECT (FULL)
# ==============================
# Full collection of Entra devices using @odata.nextLink pagination
# Output: flat list of devices (array)
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

            # Management of the nextLink

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
# ENTRA EXPORT
# ==============================
# "Raw" export: complete Entra dataset (useful for debugging + future correlation)
# "Processed" export: subset of Registered devices (trustType = Workplace)
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
Write-Host "[OK] Raw Entra export saved" -ForegroundColor Green
Write-Host "TOTAL Entra devices = $($entraAll.Count)" -ForegroundColor Green


# ==============================
# ENTRA FILTER: REGISTERED (WORKPLACE)
# ==============================
# Registered = BYOD "registered" device (not necessarily managed)
# Used for BYOD view / comparison with Intune and Trend
# ==============================

$entraRegistered = $entraAll | Where-Object { $_.trustType -eq "Workplace" }

$entraByDeviceId = @{}
$entraByDisplayName = @{}

foreach ($device in $entraAll) {
    if ($device.deviceId) {
        $entraByDeviceId[$device.deviceId] = $device    
  }else {
    continue
 }
}

foreach ($device in $entraAll) {
    if ($device.displayName) {
        $entraByDisplayName[$device.displayName] = $device 
   }else{
    continue
   }
}

Write-Host "Total Entra registered (workplace) = $($entraRegistered.Count)" -ForegroundColor Green

$registeredPath = "data/processed/entra_registered_devices_$date.json"

$registeredExport = [pscustomobject]@{
    collectedAt     = (Get-Date).ToString("o")
    trustTypeFilter = "Workplace"
    totalDevices    = $entraRegistered.Count
    devices         = $entraRegistered
}
Write-Host"[OK] Entra Workplace devices: $($entraRegistered.Count)

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

 

    #$totalIntuneDevices = $cleanExport.Count

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




    $trendPath = Get-ChildItem -Path "data/processed/" -Filter "trend_workstations_*.json" | Sort-Object -Property CreationTime | Select-Object -Last 1

    $trendJson = Get-content $trendPath -Raw

    $trendDevices = $trendJson  | ConvertFrom-Json

 

   

    Write-Host "Trend devices loaded =" $trendDevices.count -ForegroundColor Cyan

    #======================================

    #-------- Correlation Trend------------

    #======================================

 

    $ConsolidatedDevices = @()

 

    foreach ($device in $trendDevices) {

 

        $entraMatch = $null

        $intuneMatch = $null

        $match_reason = $null

        $match_status = $null

       

 

        $entraMatch = $entraAll | Where-Object { $_.displayName -eq $device.endpointName }

 

        if ($entraMatch) {

 

            $intuneMatch = $cleanExport | Where-Object { $_.AZURE_AD_DEVICE_ID -eq $entraMatch.deviceId }

 

            if ($intuneMatch) {

 

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

 

       

 

        $ConsolidatedObject = [PSCustomObject]@{

            primary_user                   = if ($intuneMatch -and $intuneMatch.USER) { $intuneMatch.USER } elseif ($device.lastLoggedOnUser) { $device.lastLoggedOnUser } else { "unknown" }

            device_os                      = if ($device.osName) { $device.osName } elseif ($intuneMatch -and $intuneMatch.OS) { $intuneMatch.OS } elseif ($entraMatch -and $entraMatch.operatingSystem) { $entraMatch.operatingSystem } else { "unknown" }

            device_os_version              = if ($device.osVersion) { $device.osVersion } elseif ($intuneMatch -and $intuneMatch.OS_VERSION) { $intuneMatch.OS_VERSION } elseif ($entraMatch -and $entraMatch.operatingSystemVersion) { $entraMatch.operatingSystemVersion } else { "unknown" }

            device_name                    = if ($device.endpointName) { $device.endpointName } elseif ($entraMatch -and $entraMatch.displayName) { $entraMatch.displayName } elseif ($intuneMatch -and $intuneMatch.DEVICE) { $intuneMatch.DEVICE } else { "unknown" }

 

            trend_agent_guid               = if ($device.agentGuid) { $device.agentGuid } else { "unknown" }

            trend_type                     = if ($device.type) { $device.type } else { "unknown" }

            trend_display_name             = if ($device.displayName) { $device.displayName } else { "unknown" }

            trend_endpoint_name            = if ($device.endpointName) { $device.endpointName } else { "unknown" }

            trend_last_used_ip             = if ($device.lastUsedIp) { $device.lastUsedIp } else { "unknown" }

            trend_ip_addresses             = if ($device.ipAddresses) { $device.ipAddresses } else { @() }

            trend_serial_number            = if ($device.serialNumber) { $device.serialNumber } else { "unknown" }

            trend_os_name                  = if ($device.osName) { $device.osName } else { "unknown" }

            trend_os_version               = if ($device.osVersion) { $device.osVersion } else { "unknown" }

            trend_os_architecture          = if ($device.osArchitecture) { $device.osArchitecture } else { "unknown" }

            trend_os_platform              = if ($device.osPlatform) { $device.osPlatform } else { "unknown" }

            trend_cpu_architecture         = if ($device.cpuArchitecture) { $device.cpuArchitecture } else { "unknown" }

            trend_isolation_status         = if ($device.isolationStatus) { $device.isolationStatus } else { "unknown" }

            trend_service_gateway          = if ($device.serviceGatewayOrProxy) { $device.serviceGatewayOrProxy } else { "unknown" }

            trend_version_policy           = if ($device.versionControlPolicy) { $device.versionControlPolicy } else { "unknown" }

            trend_agent_update_status      = if ($device.agentUpdateStatus) { $device.agentUpdateStatus } else { "unknown" }

            trend_agent_update_policy      = if ($device.agentUpdatePolicy) { $device.agentUpdatePolicy } else { "unknown" }

            trend_security_policy          = if ($device.securityPolicy) { $device.securityPolicy } else { "unknown" }

            trend_security_override        = if ($device.securityPolicyOverriddenStatus) { $device.securityPolicyOverriddenStatus } else { "unknown" }

            trend_last_logged_on_user      = if ($device.lastLoggedOnUser) { $device.lastLoggedOnUser } else { "unknown" }

 

            entra_device_id                = if ($entraMatch -and $entraMatch.deviceId) { $entraMatch.deviceId } else { "unknown" }

            entra_display_name             = if ($entraMatch -and $entraMatch.displayName) { $entraMatch.displayName } else { "unknown" }

            entra_trust_type               = if ($entraMatch -and $entraMatch.trustType) { $entraMatch.trustType } else { "unknown" }

            entra_operating_system         = if ($entraMatch -and $entraMatch.operatingSystem) { $entraMatch.operatingSystem } else { "unknown" }

            entra_operating_system_version = if ($entraMatch -and $entraMatch.operatingSystemVersion) { $entraMatch.operatingSystemVersion } else { "unknown" }

            entra_last_signin              = if ($entraMatch -and $entraMatch.approximateLastSignInDateTime) { $entraMatch.approximateLastSignInDateTime } else { "unknown" }

            entra_account_enabled          = if ($entraMatch -and $null -ne $entraMatch.accountEnabled) { $entraMatch.accountEnabled } else { $false }

 

            intune_device_id               = if ($intuneMatch -and $intuneMatch.INTUNE_DEVICE_ID) { $intuneMatch.INTUNE_DEVICE_ID } else { "unknown" }

            intune_azure_ad_device_id      = if ($intuneMatch -and $intuneMatch.AZURE_AD_DEVICE_ID) { $intuneMatch.AZURE_AD_DEVICE_ID } else { "unknown" }

            intune_device_name             = if ($intuneMatch -and $intuneMatch.DEVICE) { $intuneMatch.DEVICE } else { "unknown" }

            intune_user                    = if ($intuneMatch -and $intuneMatch.USER) { $intuneMatch.USER } else { "unknown" }

            intune_compliance_state        = if ($intuneMatch -and $intuneMatch.COMPLIANCE) { $intuneMatch.COMPLIANCE } else { "unknown" }

            intune_serial_number           = if ($intuneMatch -and $intuneMatch.SERIAL_NUMBER) { $intuneMatch.SERIAL_NUMBER } else { "unknown" }

            intune_os                      = if ($intuneMatch -and $intuneMatch.OS) { $intuneMatch.OS } else { "unknown" }

            intune_os_version              = if ($intuneMatch -and $intuneMatch.OS_VERSION) { $intuneMatch.OS_VERSION } else { "unknown" }

            intune_enrolled_date           = if ($intuneMatch -and $intuneMatch.ENROLLED_DATE) { $intuneMatch.ENROLLED_DATE } else { "unknown" }

            intune_ownership               = if ($intuneMatch -and $intuneMatch.OWNERSHIP_INTUNE) { $intuneMatch.OWNERSHIP_INTUNE } else { "unknown" }

            intune_entra_trust_type        = if ($intuneMatch -and $intuneMatch.ENTRA_TRUST_TYPE) { $intuneMatch.ENTRA_TRUST_TYPE } else { "unknown" }

 

            match_status                   = $match_status

            match_reason                   = $match_reason

            issues                         = @()

            visual_tag                     = $null

            recommended_action             = $null

 

            duplicate_hostname             = $false

            duplicate_hostname_count       = 1

 

            trend_count                    = 1

            entra_count                    = 0

            intune_count                   = 0

 

            has_trend                      = $true

            has_entra                      = if ($entraMatch) { $true } else { $false }

            has_intune                     = if ($intuneMatch) { $true } else { $false }

 

            is_registered_in_entra         = if ($entraMatch) { $true } else { $false }

            is_managed_in_intune           = if ($intuneMatch) { $true } else { $false }

            is_noncompliant                = if ($intuneMatch -and $intuneMatch.COMPLIANCE -eq "noncompliant") { $true } else { $false }

 

            trend                          = $device

            entra                          = $entraMatch

            intune                         = $intuneMatch

        }

        $ConsolidatedDevices += $ConsolidatedObject

 

    }




    #=======================================================================================================================================================

 

    $DevicesMatched = $ConsolidatedDevices | Where-Object { $_.match_status -eq "matched" }

    $DevicesPartial = $ConsolidatedDevices | Where-Object { $_.match_status -eq "partial" }

    $DevicesUnmatched = $ConsolidatedDevices | Where-Object { $_.match_status -eq "unmatched" }

   

   

   

    # =====================================================================

    # DETECTION DES HOSTNAMES DUPLIQUES

    # =====================================================================

 

    # On groupe tous les devices par nom

    # Cela permet de savoir combien de fois chaque hostname apparaît

 

    $duplicateHostnames = $ConsolidatedDevices | Group-Object device_name | Where-Object { $_.Count -gt 1 }

 

    # =====================================================================

    # AJOUT DES INFORMATIONS DE DOUBLON DANS CHAQUE DEVICE

    # =====================================================================

 

    foreach ($device in $ConsolidatedDevices) {

 

        # On cherche si le nom du device actuel existe dans la liste des doublons

        $duplicateMatch = $duplicateHostnames | Where-Object { $_.Name -eq $device.device_name }

 

        # Si le hostname existe dans la liste des doublons

        if ($duplicateMatch) {

 

            # Le hostname est utilisé plusieurs fois

            $device.duplicate_hostname = $true

 

            # On enregistre combien de fois ce hostname apparaît

            $device.duplicate_hostname_count = $duplicateMatch.Count

 

        }

        else {

 

            # Sinon le hostname est unique

            $device.duplicate_hostname = $false

 

            # Il apparaît une seule fois

            $device.duplicate_hostname_count = 1

        }

    }

   

   

    # =====================================================================

    # AJOUT DES COMPTEURS PAR SOURCE DANS CHAQUE DEVICE

    # =====================================================================

 

    foreach ($device in $ConsolidatedDevices) {

 

        $currentDeviceName = $device.device_name

 

        $device.trend_count = ($ConsolidatedDevices | Where-Object { $_.device_name -eq $currentDeviceName -and $_.has_trend -eq $true }).Count

 

        $device.entra_count = ($ConsolidatedDevices | Where-Object { $_.device_name -eq $currentDeviceName -and $_.has_entra -eq $true }).Count

 

        $device.intune_count = ($ConsolidatedDevices | Where-Object { $_.device_name -eq $currentDeviceName -and $_.has_intune -eq $true }).Count

    }

    $duplicateHostnameCount = $duplicateHostnames.Count

 

    #================================

    #       RISK ENGINE RULES

    #================================

 

    foreach ($device in $ConsolidatedDevices) {

 

        if ($device.match_status -eq "unmatched") {

 

            $device.issues = @("not_registered_in_entra")

            $device.visual_tag = "critical"

            $device.recommended_action = "Investigate device origin and tenant registration"

 

        }

 

        elseif ($device.intune -and $device.intune.COMPLIANCE -eq "noncompliant") {

 

            $device.issues = @("noncompliant_device")

            $device.visual_tag = "critical"

            $device.recommended_action = "Investigate device compliance policy"

 

        }

 

        elseif ($device.entra -and $device.entra.trustType -eq "Workplace") {

 

            $device.issues = @("byod_workplace")

            $device.visual_tag = "warning"

            $device.recommended_action = "Verify if BYOD usage is expected"

 

        }

 

        elseif ($device.match_status -eq "partial") {

 

            $device.issues = @("not_managed_in_intune")

            $device.visual_tag = "warning"

            $device.recommended_action = "Investigate device management status in Intune"

 

        }

    }

 

    foreach ($device in $ConsolidatedDevices) {

        if ($null -eq $device.visual_tag ) {

            $device.visual_tag = "normal"

        }

    }

 

    $tagCountCritical = $ConsolidatedDevices | Where-Object { $_.visual_tag -eq "critical" }

    $tagCountWarning = $ConsolidatedDevices | Where-Object { $_.visual_tag -eq "warning" }

    $tagCountNormal = $ConsolidatedDevices | Where-Object { $_.visual_tag -eq "normal" }

 

    $duplicateHostnameCount = $duplicateHostnames.Count

 

    $tagCountCritical = $ConsolidatedDevices | Where-Object { $_.visual_tag -eq "critical" }

    $tagCountWarning = $ConsolidatedDevices | Where-Object { $_.visual_tag -eq "warning" }

    $tagCountNormal = $ConsolidatedDevices | Where-Object { $_.visual_tag -eq "normal" }

 

    $FullJsonDataset = [PSCustomObject]@{

        generated_at  = $date

        total_records = $ConsolidatedDevices.Count

 

        summary       = [PSCustomObject]@{

            total_devices        = $ConsolidatedDevices.Count

            critical_devices     = $tagCountCritical.Count

            warning_devices      = $tagCountWarning.Count

            normal_devices       = $tagCountNormal.Count

 

            matched_devices      = $DevicesMatched.Count

            partial_devices      = $DevicesPartial.Count

            unmatched_devices    = $DevicesUnmatched.Count

 

            duplicate_hostnames  = $duplicateHostnameCount

 

            trend_present        = ($ConsolidatedDevices | Where-Object { $_.has_trend -eq $true }).Count

            entra_present        = ($ConsolidatedDevices | Where-Object { $_.has_entra -eq $true }).Count

            intune_present       = ($ConsolidatedDevices | Where-Object { $_.has_intune -eq $true }).Count

 

            registered_in_entra  = ($ConsolidatedDevices | Where-Object { $_.is_registered_in_entra -eq $true }).Count

            managed_in_intune    = ($ConsolidatedDevices | Where-Object { $_.is_managed_in_intune -eq $true }).Count

            noncompliant_devices = ($ConsolidatedDevices | Where-Object { $_.is_noncompliant -eq $true }).Count

        }

 

        records       = $ConsolidatedDevices

    }

 

    Write-Host "JSON FINAL CREE" -ForegroundColor Green

    Write-Host "TOTAL RECORDS =" $FullJsonDataset.total_records -ForegroundColor Green

 

    $FullJsonDataset.total_records

    $FullJsonDataset.records.Count

 

   

    Write-Host "device with visual_tag critical: " $tagCountCritical.count

    Write-Host "device with visual_tag warning : " $tagCountWarning.count

    Write-Host "device with visual_tag normal : " $tagCountNormal.count

 

    $fulljsonPath = "./data/reports/Full_devices_report_$date.json"

    $FullJsonDataset | ConvertTo-Json -Depth 10 | Out-File -FilePath $fulljsonPath -Encoding UTF8

   

    #=============================

    # HELPDESK DATA SET

    #=============================

 

    # ==============================

    # HELPDESK DATASET (VIEW)

    # ==============================

 

    $helpdeskCases = @()

 

    foreach ($device in $ConsolidatedDevices) {

 

        if ($device.visual_tag -eq "critical" -or $device.visual_tag -eq "warning") {

 

            $caseUser = "unknown"

 

            if ($device.intune -and $device.intune.USER) {

                $caseUser = $device.intune.USER

            }

 

            $HelpDeskObject = [PSCustomObject]@{

                device_name        = $device.device_name

                user               = $caseUser

                reason             = $device.match_reason

                recommended_action = $device.recommended_action

                status             = $device.match_status

                visual_tag         = $device.visual_tag

                issues             = $device.issues

                entra_trust_type   = $device.entra_trust_type

            }

 

            $helpdeskCases += $HelpDeskObject

        }

    }

 

    # Tri (critical en premier)

    $helpdeskCases = $helpdeskCases | Sort-Object @{

        Expression = {

            switch ($_.visual_tag) {

                "critical" { 0 }

                "warning" { 1 }

                default { 2 }

            }

        }

    }

 

    $date = Get-Date -Format "yyyyMMdd-HHmm"

 

    $HelpDeskReportPathCsv = "./data/reports/helpdesk_report_$date.csv"

    $HelpDeskReportPathJson = "./data/reports/helpdesk_report_$date.json"

 

    $helpdeskCases | Export-Csv -Path $HelpDeskReportPathCsv -NoTypeInformation -Delimiter ";"

 

    $helpdeskCases | ConvertTo-Json -Depth 5 | Out-File -FilePath $HelpDeskReportPathJson -Encoding UTF8

   

    # ============================

    # BYOD DEVICE MONITOR REPORT

    # ============================

 

    $helpdeskNoncompliant = ($HelpdeskCases | Where-Object { $_.issues -contains "noncompliant_device" }).Count

    $helpdeskPartial = ($HelpdeskCases | Where-Object { $_.status -eq "partial" }).Count

    $helpdeskUnmatched = ($HelpdeskCases | Where-Object { $_.status -eq "unmatched" }).Count

    $helpdeskWorkplace = ($HelpdeskCases | Where-Object { $_.entra_trust_type -eq "Workplace" }).Count

 

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

