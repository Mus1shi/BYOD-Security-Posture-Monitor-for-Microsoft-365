. "$PSScriptRoot\tools\Invoke-TrendCollectEndpoint.ps1"
. "$PSScriptRoot\core\GraphAuth.ps1"
. "$PSScriptRoot\core\EntraCollect.ps1"
. "$PSScriptRoot\core\IntuneCollect.ps1"
. "$PSScriptRoot\core\TrendCollect.ps1"
. "$PSScriptRoot\processing\Correlation.ps1"
. "$PSScriptRoot\processing\RiskEngine.ps1"
. "$PSScriptRoot\output\Reports.ps1"
. "$PSScriptRoot\output\Mail.ps1"

try {
    Write-Host "[STEP] Starting Devices Monitor" -ForegroundColor Cyan

    #========================================
    #                AUTH
    #========================================

    $accessToken = Get-Graphtoken -TenantId $TenantId -ClientId -ClientSecret $ClientSecret

    $headers = @{
        Authorization = "Bearer $accessToken"
    }

    #========================================
    #               ENTRA
    #========================================
    
    $entraData = Get-EntraDevices `
            -Headers $headers `
            -RawDataPath $RawDataPath `
            -ProcessedDataPath $ProcessedDataPath `

    $entraByDeviceId = $entraData.BydeviceId
    $entraByDisplayName = $entraData.BydisplayName

    #Intune

    $intuneData = Get-IntuneDevices `
            -Headers $headers `
            -EntraByDeviceId $entraByDeviceId
            

}
catch {
    
}