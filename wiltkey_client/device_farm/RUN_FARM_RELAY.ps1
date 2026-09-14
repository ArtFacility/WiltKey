# WiltKey DEVICE FARM relay launcher — local relay tuned for automation runs.
#
#   .\RUN_FARM_RELAY.ps1
#
# Differences from RUN_LOCAL_RELAY.ps1 (manual testing):
#   • WK_ISSUANCE_DIFFICULTY=1  → PoW solves in ~1 hash (no wait in flows)
#   • WK_CHALLENGE_MODE=off     → no human-verification puzzle mid-flow
#   • WK_ISSUANCE_DAILY_IP=500  → reinstall freely; the cap never bites
#   • Own Postgres DB (wiltkey_farm) → farm state never mixes with manual tests
#   • Isolated storage dir → large-file state disposable
#
# Farm devices point at:  http://<this-laptop-LAN-IP>:8000
# (baked into farm APKs via --dart-define=WK_DEFAULT_RELAY; manual testers
#  can also set it in Settings → dev relay)

# --- 1. Postgres (REQUIRED: the device-token gate fails closed without it) ---
$svc = Get-Service postgresql-x64-18 -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Running') {
    Write-Host "Starting Postgres service (needs admin)..."
    Start-Service postgresql-x64-18
}

$env:POSTGRES_URL = $env:POSTGRES_URL
if (-not $env:POSTGRES_URL) {
    Write-Warning "POSTGRES_URL not set — set it before running, e.g.:"
    Write-Warning '  $env:POSTGRES_URL = "postgres://postgres:YOURPASSWORD@localhost:5432/wiltkey_farm?sslmode=disable"'
    Write-Warning "Create the (empty) database first if needed:"
    Write-Warning '  & "C:\Program Files\PostgreSQL\18\bin\createdb.exe" -U postgres wiltkey_farm'
    exit 1
}

# --- 2. Farm tuning ----------------------------------------------------------
$env:PORT = '8000'
$env:WK_ISSUANCE_DIFFICULTY = '1'
$env:WK_CHALLENGE_MODE = 'off'
$env:WK_ISSUANCE_DAILY_IP = '500'

Write-Host "Starting FARM relay on port $env:PORT (PoW difficulty 1, puzzle off, cap 500/IP/day)..."
& "$PSScriptRoot\..\wiltkey_server\wiltkey-relay-local.exe"
