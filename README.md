# Vorssaint with emr

Vorssaint with personal improvements built into the same application. There is
one **Vorssaint.app**, one settings domain and one Dynamic Island. emr is a
modular source extension maintained in this fork; it is not a second application
or a runtime plugin for an untouched official binary.

**Version:** 0.4.0

Upstream: [Vorssaint](https://github.com/vorssaint/vorssaint-utils), `main` at
`1cdbd59b1c7dccd036ec1713b2ea048334990d06`. The original app's functionality,
licence and credits remain. See the [upstream README](docs/UPSTREAM_README.md).

## Included features

| Feature | What it adds |
| --- | --- |
| [Sys Performance](EMRPackage/features/sys-performance.md) | Capacity-based reading colours, a selectable colour for readings without capacity, and a Codex usage tile in the system island page. |
| [App shortcuts](EMRPackage/features/app-shortcuts.md) | Individual app, CrossOver game and website shortcuts around the island, including fetched website icons. |

A triangular emr icon before the title identifies top-level added features.
Individual shortcuts and child controls keep their plain names. Website icons
are fetched directly from the selected sites; browser cookies are not used.
Codex usage reflects reported Codex limits and local token logs, not ChatGPT chat
limits. Values can be unavailable when this Mac has no relevant usage data.

## Requirements

- Apple Silicon Mac, macOS 14 or newer.
- Apple's Command Line Tools, Python 3 and Git. Install tools with
  `xcode-select --install` if missing.
- Internet access to fetch source and website icons.

Distribution is GitHub source only. The local build uses ad-hoc signing and does
not use a Developer Program account, change Keychain identities or require full
Xcode. macOS may require Accessibility or Screen Recording permissions to be
re-authorized for the rebuilt Vorssaint app. Do not reset unrelated permissions.

## Install

This is the new integrated architecture. Historical tags through `emr-v0.3.0`
build the separate Island Monitor companion and should not be used for it.

Quit Vorssaint before installing. If you have Island Monitor, turn off its launch
at login setting and quit it too, then use the migration command below.

```sh
git clone --depth 1 --branch emr-v0.4.0 https://github.com/emrearibulan/emr-vorssaint-package.git vorssaint-emr
cd vorssaint-emr
./EMRPackage/install.command
```

For an existing **Island Monitor** installation, replace the last command with:

```sh
./EMRPackage/install.command --migrate-island-monitor
```

The installer builds the full app and runs its self-test before replacing
`Vorssaint.app`. Both apps must be fully closed; this is checked before building
and again before replacement. It backs up the existing app and preferences and
restores them if final verification or migration fails. An unrelated app at the
destination is never replaced. Duplicate installations in system and user
Applications folders must be consolidated first.

Migration imports only missing emr colour, shortcut and side-layout preferences.
An existing Vorssaint choice wins. The old companion's monitor-only feature
profile, onboarding shortcuts and other settings are never copied. The companion
app is retired after successful installation; its app and preferences are backed
up, and its original preferences domain is retained. If Vorssaint already had a
custom side layout, migrated shortcuts remain available for you to place.

## First launch

Open **Vorssaint**. Enable Dynamic Island in its Settings if you previously turned
it off to avoid the companion's overlapping island. Use the Features hub to enable
the metric families and AI Agents you want. emr does not remove other Vorssaint
features or force a monitor-only preset.

- **Settings → Dynamic Island → Content → Sys Performance:** choose the colour
  for readings without a known capacity.
- **Settings → Dynamic Island → Layout → App shortcuts:** add apps, games or
  websites one by one. Choose Left, Right or Bottom for each. Every side has
  three slots, including hidden built-in section buttons.
- **Add Website…:** enter an http/https address and optional name. A bare hostname
  uses HTTPS. Refresh its icon from the shortcut row. If no usable icon is found,
  the globe fallback still launches the saved address in your default browser.

## Updates

From your source folder, quit Vorssaint and run:

```sh
./EMRPackage/update.command
```

This fetches the latest published **integrated** emr source release, builds and
installs it. It refuses old companion-only releases. Your original clone can stay on its
release tag; the update command fetches a fresh source checkout for each update.
The in-app upstream update check remains useful, but installing an official DMG
would remove the emr additions. This build blocks that binary replacement and
points to the source update command.

The fork follows Vorssaint by merging upstream changes, testing them together
with emr and publishing a new combined source version. Upstream releases do not
automatically become tested emr releases. Conflicts require review.

### Upgrade from the old companion package

After quitting both apps, the old source folder's update command can fetch the
new architecture and migrate it:

```sh
./EMRPackage/update.command --migrate-island-monitor
```

## Backups and rollback

Each successful replacement prints its backup path under:

```text
~/Library/Application Support/emr/backups.noindex/<timestamp>/
```

The backup contains the previous `Vorssaint.app`, its saved preferences and, when
migrating, `Island Monitor.app` and a preferences snapshot. To roll back, quit
Vorssaint and restore the previous app from that folder to its original
Applications location. Restore preferences only if you want the pre-migration
settings; this overwrites choices changed since the backup:

```sh
# Replace /path/to/backup with the path printed by your installer.
defaults import com.vorssaint.utils "/path/to/backup/preferences.plist"
```

For a fresh installation there may be no previous host app or settings. The
`preferences-state.json` records whether a host domain existed. Keep backups
private; they can contain your personal shortcut paths and settings. Do not
commit them or share them with friends.

## Develop and share

emr code lives under `Sources/Vorssaint/Extensions/emr/`, with SysPerformance and
AppShortcuts subfolders. It reuses Vorssaint's host services and window lifecycle;
there is no independent emr executable. The source package catalogue lives in
`EMRPackage/package.json`.

```sh
./build-emr.sh
./EMRPackage/install.command --build-only
python3 -m unittest discover -s EMRPackage/tests -v
./Tools/test-dashboard.sh
./Tools/test-launcher.sh
./build-emr.sh --test-suite=notch --test-suite=settings --test-suite=repository
```

Share the GitHub release link and its source-build instructions. Existing
Vorssaint users install this edition in place, retaining settings. Share the
source package, never another user's saved configuration or credentials.

See [maintenance](EMRPackage/MAINTAINING.md) and the
[package changelog](EMRPackage/CHANGELOG.md). Every published update must include
an updated README and changelog. GPL-3.0-or-later applies; preserve upstream
copyright and licence notices when sharing modified source.
