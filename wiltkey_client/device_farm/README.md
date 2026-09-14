# WiltKey Device Farm

Automated UI testing on real Android devices — the "Google Play pre-launch
report" equivalent, running locally on your own hardware.

**Stack:** [Maestro](https://docs.maestro.dev) (YAML gesture flows, drives the
real release APK — no app code changes) + a small PowerShell orchestrator +
a local relay tuned for automation (instant PoW, no puzzle).

---

## First run checklist (the short version)

1. Plug devices in (USB debugging on, RSA prompt approved) → `adb devices -l`.
2. Copy each serial into `devices.json` (FOSS for the Huawei; `play` only for GMS devices).
3. `.\RUN_FARM_RELAY.ps1` (needs `POSTGRES_URL` pointing at the `wiltkey_farm` DB — see the script header).
4. `.\build_farm_apks.ps1` → farm APKs land in `dist\farm\`.
5. `.\run_farm.ps1 -Mode fresh` — expect the first run to be the *tuning* run:
   failure logs + screenshots land in `results\<timestamp>\<serial>\` and show
   exactly which tap points need nudging per OEM (PIN fields, story sheet,
   chat-row positions). Fix the `point:` values in the failing flow, re-run.
6. Once fresh passes: pair devices manually once, then `.\run_farm.ps1`
   (keep mode) for the recurring suite; `-Mode quick` after every rebuild.

---

## One-time setup

### 1. Install Maestro (done on this machine)
- Downloaded `maestro.zip` from the
  [Maestro releases](https://github.com/mobile-dev-inc/maestro/releases) →
  extracted to `C:\maestro` → `C:\maestro\maestro\bin` on PATH.
- Java: Maestro needs Java 17+; the farm scripts point `JAVA_HOME` at
  Android Studio's bundled JBR (`jbr`) — no separate install needed.

### 2. Prepare each device (manual, once per device)
1. Settings → About → tap Build number 7× → enable **Developer options**.
2. Enable **USB debugging**.
3. **OEM install permissions** (the fiddly bit):
   - **Xiaomi/MIUI**: Developer options → *Install via USB* ON, *USB
     debugging (Security settings)* ON (requires a Mi account + SIM sometimes),
     and approve the prompts the first install triggers.
   - **Samsung**: just approve the "allow USB debugging" RSA prompt and the
     install confirmation.
   - **Huawei**: enable USB debugging; it may need the "allow ADB debugging"
     prompt. **FOSS flavor only** — old Huawei devices have no Google services,
     so never assign them the `play` flavor.
4. Disable battery optimization for reliable long runs (Settings → Battery).
5. Keep the screen unlocked during runs (or set the timeout long).

### 3. Map your devices
Edit `devices.json`: run `adb devices -l`, copy each serial in, assign
`foss`/`play` (Play flavor only on devices with Google services).

### 4. Build the farm APKs
```powershell
.\build_farm_apks.ps1        # autodetects the LAN IP, bakes it as the default relay
```
Output: `dist\farm\wiltkey-*-farm.apk`. These differ from release APKs only by
`--dart-define=WK_DEFAULT_RELAY=http://<laptop>:8000` — a fresh install
connects to the farm relay from first launch with zero manual setup. **Never
distribute farm APKs.**

### 5. Start the farm relay
```powershell
.\RUN_FARM_RELAY.ps1         # port 8000, PoW difficulty 1, puzzle off, own DB (wiltkey_farm)
```
(Pairs with the manual-test relay in `dist\RUN_LOCAL_RELAY.ps1` — same port
family, isolated database, so farm state never mixes with your test data.)

---

## Running

```powershell
.\run_farm.ps1 -Mode quick            # sanity check after a rebuild (~1 min/device)
.\run_farm.ps1                        # keep-mode suite (state persists between runs)
.\run_farm.ps1 -Mode fresh            # uninstall+reinstall → full onboarding flow
.\run_farm.ps1 -Serial R58T1234ABC    # single device
.\run_farm.ps1 -Flavor play           # only the GMS devices
```

Per-flow logs + Maestro debug output (screenshots, view hierarchy) land in
`results\<timestamp>\<serial>\`. The orchestrator exits non-zero if anything
failed — usable as a release gate later.

## Flow inventory

| Flow | Install mode | What it covers |
|---|---|---|
| `onboarding.yaml` | fresh | Language → welcome → theme → profile → avatar → notifications → social → PIN → securing screen → lands on Chats |
| `tabs_smoke.yaml` | keep | Unlock, all 4 tabs render & switch, lands on Chats |
| `pin_lock.yaml` | keep | Wrong PIN rejected, correct PIN unlocks |
| `avatar_editor.yaml` | keep | Open editor, redraw (Random), save |
| `story_publish.yaml` | keep | Text-tag story: compose → publish → feed ring flips to "Your Story" |
| `chat_flow.yaml` | keep | Open first paired chat, send a text, assert the sent bubble |
| `smoke_quick.yaml` | any | Minimal boot+tabs check (same as quick mode) |

## What automation does NOT cover (by design)

- **BLE pairing / QR camera scans** — physical-world steps; pair devices once
  manually, then the keep-mode suite exercises everything after pairing.
- **Internal crypto/pad state** — covered by the Dart unit suite
  (`flutter test --concurrency=1`); the farm asserts UI, not keystream math.
- **Play Billing flows** — needs real store listings; test manually.

## Tuning & troubleshooting

- **PIN/tap coordinates**: PIN fields and some custom widgets are
  screen-percentage taps (`point: "50%, 45%"`). Different aspect ratios (Huawei
  elongated screens!) may need nudging — the values live at the top of each
  flow.
- **MIUI popups mid-run**: if an OEM dialog steals focus, add a
  `tapOn`/`back` step for it in the affected flow, or dismiss it once manually
  (MIUI remembers most confirmations).
- **First-run debugging**: `maestro studio` lets you record taps interactively
  against a connected device and emit YAML — very useful for adding flows.
- Relay not reachable from devices? Check the laptop firewall allows inbound
  :8000 on the private network profile.
