# EMR Package for Vorssaint

A personal, open-source package of Mac features, starting with **Sys Performance - emr**.
It runs in the **Island Monitor** companion alongside the official Vorssaint app.

**Vorssaint keeps its normal official updates. Your EMR features and settings live
in the separate companion.** Existing Vorssaint users can add the package; a fresh
installation can install the latest official Vorssaint app and this package together.

This is an unofficial source fork of [Vorssaint](https://github.com/vorssaint/vorssaint-utils),
not a loadable plugin for its signed binary. The source is GPL-3.0-or-later; upstream
names and artwork remain subject to [TRADEMARKS.md](TRADEMARKS.md). The companion has
its own name, icon, bundle ID, settings and update process.

## Included now

**[Sys Performance - emr](EMRPackage/features/sys-performance.md)** adds live hardware
readings, consumption-based colours, a colour picker for readings without capacity,
and a ChatGPT · Codex tile showing remaining session/weekly allowance and local
daily token totals. No account information or personal settings are bundled.

More features can be included in the same package. The versioned
[package catalogue](EMRPackage/package.json) and [maintenance guide](EMRPackage/MAINTAINING.md)
keep them together while following upstream releases.

## Install from source

Requirements: Apple Silicon, macOS 14+, Git, Python 3 and Apple's Xcode Command Line
Tools. No GitHub account or Apple Developer membership is needed to install.
If developer tools are missing, run `xcode-select --install` and complete Apple's
installation first. The build takes several minutes; allow several gigabytes of free workspace.

### Already have Vorssaint

Quit an existing Island Monitor before replacing it. Clone the published source:

```sh
git clone --depth 1 --branch emr-v0.1.0 https://github.com/emrearibulan/emr-vorssaint-package.git emr-package
cd emr-package
./EMRPackage/install.command
```

The installer builds the companion locally, checks it, and installs it in
`/Applications` or your user Applications folder. It does not replace your existing
Vorssaint installation, permissions or updater. If the original Dynamic Island is
on, turn it off in **Vorssaint → Settings → Dynamic Island** to avoid two islands.

### New Vorssaint installation, with EMR Package included

Use the same clone commands, then run:

```sh
./EMRPackage/install.command --with-vorssaint
```

If Vorssaint is missing, this downloads its latest official stable DMG, verifies
its signature/notarization and maintainer identity, and installs the original app
alongside the locally built companion. An existing official app is retained.

The source installer does not disable macOS protections, register privileged fan
services, grant permissions or install a login item. Configure automatic launch in
the companion's General settings if desired.

## Use and update

Open **Island Monitor** from Applications. Its System content entry is named
**Sys Performance - emr**. The colour picker lives at Settings → Dynamic Island →
Content → Sys Performance - emr. Changes appear immediately and are retained.

- Update official Vorssaint through its normal updater or Homebrew.
- Quit Island Monitor, then run `./EMRPackage/update.command` in your source checkout
  to fetch and build the latest published EMR package. Existing colour choices remain.
- To follow development rather than a release, use branch `emr/package`.

The daily upstream workflow prepares tested update branches for review. New
upstream releases may need conflict fixes; custom package releases are reviewed
and published separately. This is source distribution for now, not a notarized
one-click download.

## Share with a friend

> I made an optional Mac feature package for Vorssaint. It adds a “Sys Performance - emr”
> dashboard with hardware colours and Codex usage. It can be added to an existing
> Vorssaint install, or install both from scratch. Apple Silicon + Xcode Command Line
> Tools are required because this version builds from source:
> https://github.com/emrearibulan/emr-vorssaint-package#install-from-source

## Development and verification

```sh
./Tools/test-dashboard.sh
python3 -m unittest discover -s EMRPackage/tests -v
./EMRPackage/install.command --dry-run
./build-dashboard.sh
"build/stage.noindex/Island Monitor.app/Contents/MacOS/IslandMonitor" --selftest
./build-dashboard.sh --test-suite=notch --test-suite=settings
```

See [the maintenance guide](EMRPackage/MAINTAINING.md), [implementation notes](DASHBOARD.md),
and upstream [contribution guidance](CONTRIBUTING.md). Original source and copyright:
Vorssaint, GPL-3.0-or-later. EMR customizations are distributed under the same license.
