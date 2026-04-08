# =====================================================
# SAVE SECRETS TO SECURE XML - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Optional local helper to store secrets as encrypted XML
# files using the current Windows user context.
#
# Public repository note:
# - this script is NOT required for demo mode
# - it is only provided for local lab testing
# - no production secret should ever be committed to Git
#
# Security note:
# Export-Clixml secure strings can only be decrypted by
# the same Windows user on the same machine.
# =====================================================

param (
    [string]$OutputFolder = (Join-Path $PSScriptRoot "..\..\local_secrets")
)

# Resolve to an absolute path
$OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)

# Ensure the folder exists
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

# =====================================================
# FUNCTION: Save-SecretFromEnvOrPrompt
# =====================================================
# Logic:
# 1. Try process-level environment variable
# 2. Try user-level environment variable
# 3. Try machine-level environment variable
# 4. If not found, prompt securely
# 5. Save as encrypted XML
# =====================================================

function Save-SecretFromEnvOrPrompt {
    param (
        [Parameter(Mandatory)]
        [string]$EnvName,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Write-Host "[STEP] Processing secret: $EnvName" -ForegroundColor Cyan

    $secureValue = $null
    $plainValue = [System.Environment]::GetEnvironmentVariable($EnvName, "Process")

    if (-not $plainValue) {
        $plainValue = [System.Environment]::GetEnvironmentVariable($EnvName, "User")
    }

    if (-not $plainValue) {
        $plainValue = [System.Environment]::GetEnvironmentVariable($EnvName, "Machine")
    }

    if ($plainValue) {
        Write-Host "[INFO] Using existing environment variable: $EnvName" -ForegroundColor Yellow
        $secureValue = ConvertTo-SecureString $plainValue -AsPlainText -Force
    }
    else {
        Write-Host "[INFO] Environment variable not found: $EnvName" -ForegroundColor Yellow
        $secureValue = Read-Host "Enter value for $EnvName" -AsSecureString
    }

    if (-not $secureValue) {
        throw "Failed to capture a value for $EnvName"
    }

    $secureValue | Export-Clixml -Path $OutputPath
    Write-Host "[OK] Saved $EnvName to $OutputPath" -ForegroundColor Green
}

# =====================================================
# SECRET FILE MAP
# =====================================================
# Adjust freely for local testing needs.
# The public demo does not require these files.
# =====================================================

$secretMap = @(
    @{ EnvName = "GRAPH_TENANT_ID";       FileName = "graph_tenant_id.xml" },
    @{ EnvName = "GRAPH_CLIENT_ID";       FileName = "graph_client_id.xml" },
    @{ EnvName = "GRAPH_CLIENT_SECRET";   FileName = "graph_client_secret.xml" },
    @{ EnvName = "TREND_API_KEY";         FileName = "trend_api_key.xml" },
    @{ EnvName = "DEFENDER_TENANT_ID";    FileName = "defender_tenant_id.xml" },
    @{ EnvName = "DEFENDER_CLIENT_ID";    FileName = "defender_client_id.xml" },
    @{ EnvName = "DEFENDER_CLIENT_SECRET"; FileName = "defender_client_secret.xml" }
)

foreach ($entry in $secretMap) {
    $outputPath = Join-Path $OutputFolder $entry.FileName
    Save-SecretFromEnvOrPrompt -EnvName $entry.EnvName -OutputPath $outputPath
}

Write-Host ""
Write-Host "[OK] Secret export completed." -ForegroundColor Green
Write-Host "[INFO] Files created in: $OutputFolder" -ForegroundColor White
Write-Host ""

Get-ChildItem -Path $OutputFolder | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize