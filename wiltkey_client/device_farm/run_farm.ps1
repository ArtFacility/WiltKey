# WiltKey device-farm orchestrator — installs builds on attached Android devices
# and runs Maestro UI flows against them.
#
#   .\run_farm.ps1                       # keep-mode: full suite (needs a paired device for chat_flow)
#   .\run_farm.ps1 -Mode fresh           # uninstall+reinstall each device, run onboarding flow
#   .\run_farm.ps1 -Mode quick           # tabs smoke only — the "just rebuilt APKs" sanity check
#   .\run_farm.ps1 -Serial R58xxx        # single device
#   .\run_farm.ps1 -SkipInstall          # don't (re)install, just run flows
#
# Requires: devices attached with USB debugging on (see README.md), Maestro CLI
# installed (see paths below), and the farm relay running (RUN_FARM_RELAY.ps1).

param(
    [ValidateSet('keep', 'fresh', 'quick')]
    [string]$Mode = 'keep',
    [string]$Serial = '',
    [ValidateSet('', 'foss', 'play')]
    [string]$Flavor = '',
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Continue'

# ---- Toolchain paths (edit if your layout differs) ---------------------------
$Adb        = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
$MaestroBin = 'C:\maestro\maestro\bin'
$JavaHome   = 'C:\Program Files\Android\Android Studio\jbr'
$ApkDir     = Join-Path $PSScriptRoot '..\..\dist'
# -------------------------------------------------------------------------------

$env:JAVA_HOME = $JavaHome
$env:MAESTRO_CLI_NO_ANALYTICS = 'true'
$env:Path = "$MaestroBin;$(Split-Path $Adb);$env:Path"

if (-not (Test-Path $Adb)) { Write-Error "adb not found at $Adb"; exit 1 }
if (-not (Get-Command maestro -ErrorAction SilentlyContinue)) { Write-Error "maestro not on PATH (checked $MaestroBin)"; exit 1 }

$pkg = @{ foss = 'xyz.artfacility.wiltkey.foss'; play = 'xyz.artfacility.wiltkey' }
$apkName = @{ foss = 'wiltkey-foss-release.apk'; play = 'wiltkey-play-release.apk' }

# ---- Load device map ----------------------------------------------------------
$config = Get-Content (Join-Path $PSScriptRoot 'devices.json') -Raw | ConvertFrom-Json
$serialMap = @{}
foreach ($d in $config.devices) { $serialMap[$d.serial] = $d }

# ---- Discover attached devices ------------------------------------------------
$adbList = & $Adb devices -l | Select-String -Pattern "device\b" | Where-Object { $_ -notmatch 'List of devices' }
$attached = @()
foreach ($line in $adbList) {
    $cols = ($line -replace '\s+', ' ').Split(' ')
    $attached += $cols[0]
}
if ($Serial) { $attached = $attached | Where-Object { $_ -eq $Serial } }
if (-not $attached) { Write-Error "No attached devices (mode filter: '$Serial'). Is USB debugging on?"; exit 1 }

Write-Host "Attached devices: $($attached -join ', ')"

# ---- Flow sets ----------------------------------------------------------------
$flowsFresh = @('flows\onboarding.yaml', 'flows\tabs_smoke.yaml', 'flows\pin_lock.yaml')
$flowsKeep  = @('flows\tabs_smoke.yaml', 'flows\pin_lock.yaml', 'flows\avatar_editor.yaml', 'flows\story_publish.yaml', 'flows\chat_flow.yaml')
$flowsQuick = @('flows\tabs_smoke.yaml')

switch ($Mode) {
    'fresh' { $flowSet = $flowsFresh }
    'quick' { $flowSet = $flowsQuick }
    default { $flowSet = $flowsKeep }
}

# ---- Run ----------------------------------------------------------------------
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$resultsDir = Join-Path $PSScriptRoot "results\$stamp"
New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

$allOk = $true
$summary = @()

foreach ($serial in $attached) {
    $dev = $serialMap[$serial]
    $devFlavor = if ($dev) { $dev.flavor } else { 'foss' }
    if ($dev -eq $null) { Write-Warning "Serial '$serial' not in devices.json — defaulting to FOSS." }
    if ($Flavor -and $devFlavor -ne $Flavor) { Write-Host "Skipping $serial (flavor $devFlavor ≠ $Flavor)"; continue }
    $devName = if ($dev) { $dev.name } else { $serial }
    $appId = $pkg[$devFlavor]
    $devDir = Join-Path $resultsDir $serial
    New-Item -ItemType Directory -Force -Path $devDir | Out-Null
    $devSummary = [ordered]@{ device = "$devName [$serial]"; flavor = $devFlavor; results = @() }
    Write-Host "`n=== $devName [$serial] flavor=$devFlavor ===" -ForegroundColor Cyan

    if (-not $SkipInstall) {
        if ($Mode -eq 'fresh') {
            Write-Host "  uninstalling (fresh run)..."
            & $Adb -s $serial uninstall $appId 2>$null | Out-Null
        }
        $apk = Join-Path $ApkDir $apkName[$devFlavor]
        if (-not (Test-Path $apk)) { Write-Error "APK missing: $apk — build both flavors first."; exit 1 }
        Write-Host "  installing $($apkName[$devFlavor])..."
        & $Adb -s $serial install -r $apk | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Error "install failed on $serial"; $allOk = $false; continue }
    }

    foreach ($flow in $flowSet) {
        $flowName = [IO.Path]::GetFileNameWithoutExtension($flow)
        Write-Host "  ▶ $flowName" -NoNewline
        $log = Join-Path $devDir "$flowName.log"
        & maestro test --udid $serial `
            -e "APP_ID=$appId" -e "PIN=$($config.pin)" -e "RELAY_URL=$($config.relayUrl)" `
            --debug-output $devDir `
            (Join-Path $PSScriptRoot $flow) *>> $log
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✓" -ForegroundColor Green
            $devSummary.results += @{ flow = $flowName; ok = $true }
        } else {
            Write-Host " ✗ (see $log)" -ForegroundColor Red
            $devSummary.results += @{ flow = $flowName; ok = $false }
            $allOk = $false
        }
    }
    $summary += $devSummary
}

# ---- Summary -------------------------------------------------------------------
Write-Host "`n===== FARM SUMMARY =====" -ForegroundColor Cyan
foreach ($s in $summary) {
    Write-Host "$($s.device) [$($s.flavor)]"
    foreach ($r in $s.results) {
        $mark = if ($r.ok) { '✓' } else { '✗' }
        Write-Host "  $mark $($r.flow)"
    }
}
Write-Host "Results: $resultsDir"
if (-not $allOk) { exit 1 }
