# emr package for Vorssaint

**Personal Mac additions, starting with Sys Performance: live hardware readings and Codex usage in the Dynamic Island.**

emr package is an open-source collection built from [Vorssaint](https://github.com/vorssaint/vorssaint-utils). It runs in a separate companion app called **Island Monitor**, alongside the official app. This keeps the official Vorssaint updater and the custom features on independent update paths.

**Version:** 0.1.3 · **Source base:** Vorssaint v3.4.2 · **Distribution:** GitHub source only

[Install](#install-from-source) · [Use](#first-launch) · [Update](#updates) · [Troubleshooting](#troubleshooting) · [Release history](EMRPackage/CHANGELOG.md)

## Features

### 1. [Sys Performance](EMRPackage/features/sys-performance.md)

The first feature is a system performance view for the opened Dynamic Island. It brings the following available readings together:

| Card | What it shows |
| --- | --- |
| CPU / GPU | Current utilisation. |
| Memory | Used memory as a percentage of total capacity. |
| Battery | Remaining charge on Macs with a battery. |
| Storage | Available space on the system/internal disk. |
| Network | Download and upload speeds in the configured bytes/bits unit. |
| Power | System power draw and adapter information when available. |
| Fans | Fan speed on supported hardware. |
| ChatGPT · Codex | Reported session and weekly allowance remaining, plus today's local token total. |

Click a hardware card for its metric details. Click the Codex card to open **AI Agents**. Availability depends on the Mac, enabled monitor features and available data. The compact dashboard does not reproduce every graph or sensor from the full monitor panel.

The [package catalogue](EMRPackage/package.json) gives each addition a stable ID. Future features will join the same versioned package and update process.

### Colours based on consumed capacity

When capacity is known, values are coloured by **consumption ÷ capacity**:

| Capacity consumed | Colour |
| --- | --- |
| Below 60% | Green |
| 60% to below 80% | Yellow |
| 80% to below 90% | Orange |
| 90% or more | Red |

Battery colour reflects charge consumed; storage colour reflects space used. Power uses reported adapter capacity when available, and fan speed uses reported maximum RPM. The Codex card uses whichever valid session/weekly window has the higher consumed fraction.

For readings without a known capacity, such as network speed, choose your own colour under:

**Island Monitor → Settings → Dynamic Island → Content → Sys Performance → Colour for readings without capacity**

Changes appear immediately in the dashboard and settings preview. The selection survives updates; **Reset to white** restores the default.

### Understanding Codex usage

- **Session left / Week left** are remaining fractions of reported Codex account limits. These are not ChatGPT conversation/message limits.
- **Tokens today** comes from this Mac's available Codex logs, including cached input. It is a local activity total, not an account-wide billing statement.
- The card's tooltip includes the last report and reset times when available.
- Missing or expired allowance reports show **Limits unavailable**. Expired windows are never assumed to have reset to 100% remaining.

Hardware monitoring works without Codex. Usage information requires your own local Codex installation and available records. No user account, credentials, usage history or personal colour preference is bundled.

## Install from source

### Requirements

- **Apple Silicon Mac**, **macOS 14 or newer**. Intel builds are not currently supported.
- **Git**, **Python 3**, and recent **Xcode Command Line Tools** with Swift and the macOS SDK.
- Internet access and several gigabytes of free build space. The first build can take several minutes.

No GitHub account or Apple Developer membership is needed to build the public source. If Apple's tools are missing, run this and finish the installation dialog:

```sh
xcode-select --install
```

Check your tools:

```sh
git --version
python3 --version
xcrun swiftc --version
```

### Already have Vorssaint

Quit **Island Monitor** if an earlier version is running. Choose a source folder in Terminal and run:

```sh
git clone --depth 1 --branch emr-v0.1.3 https://github.com/emrearibulan/emr-vorssaint-package.git emr-package
cd emr-package
./EMRPackage/install.command
```

The installer builds and self-tests **Island Monitor.app**, verifies its local signature, installs it in `/Applications` when writable or `~/Applications` otherwise, and opens it. It retains your existing official Vorssaint app and preferences.

A **detached HEAD** notice is expected when cloning a specific release tag.

### Install both together

Clone the same source above, then use this installer command instead:

```sh
./EMRPackage/install.command --with-vorssaint
```

If Vorssaint is missing, this also downloads its latest official stable DMG, checks its signature, bundle identity, signing team and macOS assessment, and installs it. An existing official installation is kept.

### Other installation options

```sh
# Show the plan without downloading, building or changing apps.
./EMRPackage/install.command --dry-run

# Build and self-test without installing.
./EMRPackage/install.command --build-only

# Install without opening the companion afterwards.
./EMRPackage/install.command --no-launch
```

Source builds use local ad-hoc signing as part of the normal build. This project is distributed as open source in GitHub; it does not provide an Apple Developer-signed/notarized app or installer. Installation does not grant permissions, register privileged fan services or enable launch at login.

## First launch

1. Open **Island Monitor** from the Applications folder used by the installer.
2. If the official Vorssaint island is enabled, turn it off under **Vorssaint → Settings → Dynamic Island** to avoid overlap.
3. In **Island Monitor → Settings → Dynamic Island → Content**, keep **Sys Performance** enabled.
4. Open the island by hovering over it or using **Open Dynamic Island** in settings. Select **Sys Performance**.
5. Choose the colour for readings without capacity using the picker described above.

A fresh companion installation enables monitoring and Codex usage with Sys Performance as its home section. Updates preserve existing choices. To start it automatically, enable **Settings → General → Launch at login** yourself.

Some features/displays may show macOS permission guidance. Review those requests in the companion's settings; the installer does not grant them.

## Updates

| Component | Update path |
| --- | --- |
| Official Vorssaint | Its normal official updater or your original installation method. |
| emr package / Island Monitor | The source update command below. |

Quit **Island Monitor**, then run this from your original `emr-package` source folder:

```sh
./EMRPackage/update.command
```

The updater fetches the latest published emr source release into a temporary checkout, builds and installs it, then removes that temporary checkout. Saved settings, including your chosen colour, are retained. Your original source folder stays on its cloned version; its update command can still fetch newer releases. If you removed that folder, clone the current release again.

The installer refuses to replace a running companion or an unrelated app. If final installation verification fails, it restores the previous companion app.

### Following official Vorssaint releases

A daily GitHub workflow checks for a new official stable release. It attempts the merge on a review branch and runs package, build and regression checks. Conflicts stop for manual work; successful runs prepare a pull request or compare link. The workflow does not automatically merge, publish or change installed apps.

See the [maintenance guide](EMRPackage/MAINTAINING.md) and [actual workflow results](https://github.com/emrearibulan/emr-vorssaint-package/actions). A configured workflow does not mean its latest run passed.

### Documentation with every release

Every published package update must include an updated README and [changelog](EMRPackage/CHANGELOG.md) in the release commit. Update the version, install tag, feature catalogue and any affected instructions before publishing. The documentation check in CI verifies the current version/tag and bundled feature documentation. The [release checklist](EMRPackage/MAINTAINING.md#publishing-a-source-release) covers the remaining review.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Two islands overlap | Disable the original island in official Vorssaint and use Island Monitor for Sys Performance. |
| Sys Performance is missing | Check Island Monitor's Dynamic Island → Content settings and confirm you opened the companion. |
| A hardware card is missing or has no reading | Check its monitor feature and any requested permission. Sensors and battery/fan readings vary by hardware. |
| Codex says Limits unavailable | Check for recent local Codex usage/report data and open AI Agents for context. Unavailable limits are not treated as unused allowance. |
| A value uses the custom colour | Its capacity is unavailable; this is expected for readings such as network speed. |
| Installer says the companion is running | Quit Island Monitor, then run the installer/updater again. |
| App is missing from system Applications | Check `~/Applications`. |
| Swift/SDK build errors | Check requirements and update the developer tools; include the exact error and tool versions in a report. |
| Official download/identity verification fails | Install official Vorssaint from its upstream project and report the failure. Do not bypass verification. |

[Open an issue](https://github.com/emrearibulan/emr-vorssaint-package/issues) with the package version, macOS version, chip, reproduction steps and relevant error. Remove credentials, account details and private project paths from screenshots/logs before posting.

## Data and permissions

Hardware readings come from this Mac; the displayed daily token total comes from locally available Codex records. Each installation uses its own available data. No preconfigured account or private usage data is included in the source package.

Installation/updates contact GitHub and, when requested, download official Vorssaint releases. Features inherited from upstream can have their own network and data-access behaviour; review enabled features and permissions in settings. The companion starts with a monitoring-focused profile.

## Uninstall

Turn off the companion's **Launch at login** setting if enabled, quit **Island Monitor**, and move **Island Monitor.app** to the Trash. You may then re-enable the official Vorssaint island. Removing the companion does not remove official Vorssaint. Remove the source/build folder separately if no longer needed.

## Share with a friend

> I made emr package for Vorssaint. Its first feature, Sys Performance, shows Mac performance, usage-based colours, a custom colour picker and Codex usage in the Dynamic Island. Add it to an existing Vorssaint install or install both together. This version builds from source on an Apple Silicon Mac with macOS 14+, Python 3, Git and Xcode Command Line Tools. Instructions: https://github.com/emrearibulan/emr-vorssaint-package#install-from-source

## Development

Stable releases use `emr-vMAJOR.MINOR.PATCH` tags. New work starts from **`emr/package`**:

```sh
git clone --branch emr/package https://github.com/emrearibulan/emr-vorssaint-package.git emr-package-dev
cd emr-package-dev
```

| Location | Purpose |
| --- | --- |
| `EMRPackage/package.json` | Package version, upstream base, stable app identity and feature catalogue. |
| `EMRPackage/features/` | Documentation for each addition. |
| `EMRPackage/install.command`, `update.command` | Source install/update entry points. |
| `EMRPackage/tools/` | Installer, release documentation checks and upstream review automation. |
| `build-dashboard.sh` | Companion adapter around the upstream build. |
| `Sources/Vorssaint/UI/Notch/NotchSystemView.swift` | Sys Performance cards and colours. |
| `Sources/Vorssaint/UI/Settings/NotchSystemSettings.swift` | Colour preference UI. |
| `Sources/Vorssaint/Services/Notch/DashboardUsageSupport.swift` | Usage bands and Codex allowance validation. |

Run checks appropriate to your change:

```sh
python3 EMRPackage/tools/check-release-docs.py
python3 -m unittest discover -s EMRPackage/tests -v
./EMRPackage/install.command --dry-run
./Tools/test-dashboard.sh
./build-dashboard.sh
"build/stage.noindex/Island Monitor.app/Contents/MacOS/IslandMonitor" --selftest
codesign --verify --deep --strict "build/stage.noindex/Island Monitor.app"
./build-dashboard.sh --test-suite=notch --test-suite=settings
```

Future additions join the same versioned package. Keep feature IDs and preference keys stable, preserve user choices, and follow the [maintenance guide](EMRPackage/MAINTAINING.md). See [implementation notes](DASHBOARD.md) and inherited [contribution guidance](CONTRIBUTING.md) for more context.

## Credits and license

Based on [Vorssaint](https://github.com/vorssaint/vorssaint-utils), with credit to its maintainer and contributors. This is an independent, unofficial source fork; the addition is not a loadable plugin for the official app.

Source and emr customizations are **GPL-3.0-or-later**; see [LICENSE](LICENSE) and source notices. Upstream names, artwork and identity are covered separately by [TRADEMARKS.md](TRADEMARKS.md). Island Monitor uses its own app name, icon, bundle identity and update process.
