# =====================================================
# LOAD SECRET FROM LOCAL ENCRYPTED STORAGE
# =====================================================
# Purpose:
# Load a previously saved secret and return it
# as a usable plain string.
#
# Usage example:
# $ClientSecret = Load-Secret -Name "GraphClientSecret"
# $TrendKey = Load-Secret -Name "TrendApiKey"
# =====================================================

function Load-Secret {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Write-Host "[STEP] Loading secret: $Name" -ForegroundColor Cyan

    # -----------------------------------------
    # Define storage path
    # -----------------------------------------
    $secretFolder = Join-Path $env:USERPROFILE ".byod-secrets"
    $secretPath = Join-Path $secretFolder "$Name.xml"

    if (-not (Test-Path $secretPath)) {
        throw "Secret not found: $secretPath"
    }

    # -----------------------------------------
    # Read encrypted content
    # -----------------------------------------
    $encrypted = Get-Content -Path $secretPath

    # -----------------------------------------
    # Convert back to SecureString
    # -----------------------------------------
    $secureValue = $encrypted | ConvertTo-SecureString

    # -----------------------------------------
    # Convert SecureString to plain text
    # (required for API usage)
    # -----------------------------------------
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
    $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)

    # Clean memory
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)

    Write-Host "[OK] Secret loaded successfully" -ForegroundColor Green

    return $plainText
}