# Encodes android/upload-keystore.jks for GitHub Actions secrets.
# Usage: powershell -File scripts/encode_keystore_for_github.ps1
param(
    [string]$KeystorePath = (Join-Path $PSScriptRoot "..\android\upload-keystore.jks")
)

$resolved = Resolve-Path $KeystorePath -ErrorAction Stop
$bytes = [IO.File]::ReadAllBytes($resolved)
$base64 = [Convert]::ToBase64String($bytes)

Write-Host ""
Write-Host "=== GitHub Actions secrets (Settings -> Secrets and variables -> Actions) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "ANDROID_KEYSTORE_BASE64"
Write-Host "(paste the full line below)"
Write-Host ""
Write-Host $base64
Write-Host ""
Write-Host "ANDROID_KEYSTORE_PASSWORD  -> your store password"
Write-Host "ANDROID_KEY_PASSWORD       -> your key password (often same as store)"
Write-Host "ANDROID_KEY_ALIAS          -> upload"
Write-Host ""
Write-Host "Keystore file: $resolved" -ForegroundColor DarkGray
