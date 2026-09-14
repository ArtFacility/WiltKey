# Builds DEVICE-FARM flavored APKs: both flavors with the local farm relay
# baked in as the default relay (WK_DEFAULT_RELAY), so a fresh install
# connects to the laptop's farm relay from first launch — no manual setup.
#
#   .\build_farm_apks.ps1                 # autodetects this machine's LAN IP
#   .\build_farm_apks.ps1 -RelayUrl http://192.168.1.234:8000
#
# Output: dist\farm\wiltkey-{foss,play}-farm.apk
# NOTE: farm APKs are for the device farm ONLY — never ship/distribute them
# (their default relay is a LAN address). Release APKs are built without the
# define, exactly as always.

param([string]$RelayUrl = '')

$ErrorActionPreference = 'Stop'

if (-not $RelayUrl) {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -match '^192\.168\.' -and $_.PrefixOrigin -ne 'WellKnown' } |
        Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress
    if (-not $ip) { Write-Error "Could not autodetect a 192.168.x.x LAN IP — pass -RelayUrl."; exit 1 }
    $RelayUrl = "http://${ip}:8000"
}
Write-Host "Farm relay: $RelayUrl"

Push-Location (Join-Path $PSScriptRoot '..')
try {
    flutter clean | Out-Null
    flutter pub get | Out-Null
    flutter gen-l10n | Out-Null
    New-Item -ItemType Directory -Force -Path ..\dist\farm | Out-Null

    Write-Host "==> FOSS farm APK..."
    flutter build apk --release --flavor foss --dart-define=WK_FCM=false --dart-define="WK_DEFAULT_RELAY=$RelayUrl"
    Copy-Item build\app\outputs\flutter-apk\app-foss-release.apk ..\dist\farm\wiltkey-foss-farm.apk -Force

    Write-Host "==> Play farm APK..."
    flutter build apk --release --flavor play --dart-define=WK_FCM=true --dart-define=WK_PLAY=true --dart-define="WK_DEFAULT_RELAY=$RelayUrl"
    Copy-Item build\app\outputs\flutter-apk\app-play-release.apk ..\dist\farm\wiltkey-play-farm.apk -Force

    Write-Host "Done: dist\farm\"
} finally {
    Pop-Location
}
