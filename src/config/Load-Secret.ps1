# =====================================================
# OPTIONAL SECRET LOADER - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Provide a helper function to read locally stored
# encrypted secrets from XML files.
#
# Public repository note:
# - this helper is optional
# - demo mode does not require it
# - it is intended only for local lab usage
#
# Security note:
# Export-Clixml / Import-Clixml secure strings are tied
# to the same Windows user on the same machine.
# =====================================================

function Get-PlainTextSecretFromXml {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Secret path is missing."
    }

    if (-not (Test-Path $Path)) {
        throw "Secret file not found: $Path"
    }

    try {
        $secureSecret = Import-Clixml -Path $Path

        if (-not $secureSecret) {
            throw "Imported secret is empty: $Path"
        }

        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)

        try {
            return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
    catch {
        throw "Failed to load secret from XML file '$Path': $($_.Exception.Message)"
    }
}