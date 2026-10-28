# Island Monitor — local dashboard companion

This is a personal, unofficial customization of Vorssaint v3.4.2, upstream commit
833967fd45153fc9dc95651d34c867f5c4aee7f1. Original source:
https://github.com/vorssaint/vorssaint-utils. Source remains GPL-3.0-or-later;
see LICENSE. The local app has its own name, icon, bundle identifier and settings,
and does not use the official updater or signing identity.

## Dashboard

CPU, GPU, memory, disk, battery, power and fan values use consumed capacity when
a real denominator is available: green <60%, yellow 60–79%, orange 80–89%, red
≥90%. For disk and battery, the displayed available/remaining quantity is coloured
by its consumed complement, so nearly full storage and an almost empty battery
turn red. Power uses the reported adapter rating, when available. Fans use the
reported maximum RPM. Network throughput and other readings with no known
capacity use a colour selected in Settings → Dynamic Island → Content → Sys Performance,
under “Colour for readings without capacity”. White is the default. The picker
updates both the live dashboard and its settings preview immediately, including
secondary readings such as network upload speed. “Reset to white” restores the
default; this preference is saved and included in settings backups. The fan maximum is obtained using a read-only probe;
colouring does not install a fan helper or change cooling settings.

The Connected Devices tile is replaced by ChatGPT · Codex. It shows the latest
reported session allowance remaining, weekly allowance remaining, and today's
Codex token count from this Mac, including cached input. The colour follows the
more consumed of the two allowances. Hover for report/reset times; click to open
AI Agents. These are Codex plan limits, not ChatGPT conversation/message limits.
Past reset times and missing/invalid limits show unavailable until a new report
arrives; they are never converted to an invented 100% allowance.

## Build and verify

Apple Silicon, macOS 14+, Xcode Command Line Tools; no package dependencies.

```sh
./build-dashboard.sh
./Tools/test-dashboard.sh
./build-dashboard.sh --test-suite=notch
"build/stage.noindex/Island Monitor.app/Contents/MacOS/IslandMonitor" --selftest
```

The build is ad-hoc signed locally. No keychain certificate is created and no
privileged fan helper is installed. `build-dashboard.sh` generates a temporary
build script from the upstream builder and uses a distinct identity:
`local.emre.islandmonitor.dev`. The first launch enables only monitors, the island,
and Codex usage. Other Vorssaint tools remain in the official installed app.

## Using it alongside Vorssaint

Keep only one Dynamic Island enabled. The installed local companion provides the
custom dashboard. Vorssaint's original Dynamic Island has been turned off; the
rest of its toolkit remains available. To revert, quit Island Monitor, open
Vorssaint Settings → Dynamic Island, and switch Enable Dynamic Island back on.

The companion can be opened from Applications. Its login-start setting is
independent of Vorssaint's. The original app's macOS permissions and signed bundle
have not been replaced. Updates to Vorssaint do not update this custom companion.

## Validation on this Mac

Base dashboard build:

- Built successfully using Swift 6.4 with the macOS 26 SDK compatibility flags.
- 26 focused colour/allowance checks passed, including boundary values, unknown
  capacities, expired resets, invalid readings and provider isolation.
- Dynamic Island regression suite passed: 66,330 checks. Native window checks
  required normal macOS access rather than the restricted terminal sandbox.
- Packaged app self-test: SELFTEST OK. Installed code signature verified.
- Verified live on macOS 27.0.1: consumption colours, fan RPM, session/week usage,
  token totals, tile-to-AI-Agents navigation, and System as the reopening page.

Colour-setting update:

- Added a native colour picker in Dynamic Island → Content → Sys Performance, with an
  immediate preview and a reset-to-white action. The preference participates in
  settings export/import through the registered defaults.
- Settings regression suite passed: 534 checks. Rebuilt app self-test passed and
  its installed signature verified.
- The user confirmed colour selection works. Verified the live preview renders
  network and power values in the selected colour and that the chosen value is
  saved to the companion's preferences. The user's chosen colour was preserved.

## emr package source distribution

The content entry is now **Sys Performance**. The package repository is
https://github.com/emrearibulan/emr-vorssaint-package, development branch
`emr/package`. See README.md and EMRPackage/MAINTAINING.md for install/update
commands, the feature catalogue and upstream-release review workflow.

The source installer preserves existing official Vorssaint installations, verifies
new official downloads using their signature, signing team and macOS assessment,
and builds the companion locally. A fresh official-app download and verification
was exercised in a temporary folder without modifying the installed official app.
