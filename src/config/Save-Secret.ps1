# =====================================================
# SAVE SECRET LOCALLY (ENCRYPTED)
# =====================================================
# Purpose:
# Store a sensitive value (API key, client secret, etc.)
# securely on the local machine using Windows encryption.
#
# Security model:
# - Encrypted using current user + machine context
# - Cannot be decrypted on another machine or user
#
# Usage example:
# Save-Secret -Name "GraphClientSecret"
# Save-Secret -Name "TrendApiKey"
# =====================================================

function Save-Secret {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Write-Host "[STEP] Saving secret: $Name" -ForegroundColor Cyan

    # -----------------------------------------
    # Define local secure storage path
    # -----------------------------------------
    $secretFolder = Join-Path $env:USERPROFILE ".byod-secrets"

    if (-not (Test-Path $secretFolder)) {
        New-Item -Path $secretFolder -ItemType Directory -Force | Out-Null
        Write-Host "[INFO] Created secret folder: $secretFolder" -ForegroundColor DarkGray
    }

    $secretPath = Join-Path $secretFolder "$Name.xml"

    # -----------------------------------------
    # Prompt user for secret (secure input)
    # -----------------------------------------
    $secureValue = Read-Host "Enter secret for [$Name]" -AsSecureString

    # -----------------------------------------
    # Convert secure string to encrypted string
    # -----------------------------------------
    $encrypted = $secureValue | ConvertFrom-SecureString

    # -----------------------------------------
    # Save encrypted value to file
    # -----------------------------------------
    $encrypted | Out-File -FilePath $secretPath -Encoding UTF8

    Write-Host "[OK] Secret saved securely: $secretPath" -ForegroundColor Green
}