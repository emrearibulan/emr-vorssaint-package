# emr: dependent Vorssaint extension

Status: feasibility assessment. No installable extension or new release.

**Required host: the unmodified official Vorssaint application.** A patched host,
a full customized build and a separate companion are outside the chosen design.

## Required behaviour

emr is an optional package loaded and managed by Vorssaint. It has no independent
macOS app, login item, executable entry point or Dynamic Island window. Without a
compatible Vorssaint host it cannot run. Installing or removing emr adds or removes
its features inside the same app. Keep Vorssaint's other features and settings.

The first two extension features are **Sys Performance** and **App shortcuts**.
The latter includes individual app, game and website icons. Website icons come
from the selected sites. Keep the supplied transparent lowercase emr logo before
these top-level feature titles only, and preserve user-selected colours.

## Verified upstream baseline

This development branch starts directly from `vorssaint/vorssaint-utils` `main`,
commit `1cdbd59b` (29 October 2026). The current host defines its features in a
closed Swift `AppFeature` enumeration and wires them to services in
`FeatureRuntime`. Island pages and quick actions are also closed enumerations.
No external extension discovery, registration or loading interface was found in
this source. The existing feature hub's install/uninstall controls toggle
features already compiled into Vorssaint; they do not install third-party code.

Consequently a package cannot register new features in the unmodified official
app through a supported interface today. A companion app and a full customized
build are not substitutes for the required dependent extension.

## Host support required first

The official host would need a generic extension interface before an independent
emr package could supply these features. A potential interface would:

- Discover explicitly installed packages and check their identifier, required
  host and extension API version before activation.
- Register island content, side actions and settings using stable extension IDs.
- Provide the host's metric and usage snapshots through a documented interface;
  emr should not duplicate host sampling or start another island window.
- Let the host enable, disable and remove packages, preserve saved settings, and
  stop extension work when its features or the island are disabled.
- Keep built-in features working with no extension installed and reject
  incompatible packages with a useful message instead of loading them.

The runtime format and loading mechanism are not yet selected or implemented.
The interface must be reviewed against macOS code-loading/signing constraints;
merely copying a bundle into the official signed app does not add host support.

## Official versus development host

The chosen requirement excludes depending on an extension-capable patched host.
The maintainer must first ship compatible host support in an official release.
Until then, implementing the requested package against a hypothetical interface
would not produce an installable extension for the required host. Upstream updates
cannot be promised to preserve an interface upstream has not implemented.

Do not silently replace the official application, disable its updater, publish
the previous full-build prototype as a DLC, or claim stock-app compatibility.
The development branch and proposal do not change installed applications.

## Current outcome

No host source changes, installer changes, app replacement or release are part of
this branch. It records the compatibility gap and the extension-only requirement.
Do not send an upstream issue or pull request without explicit authorization.
An upstream support request can be drafted if requested.

## Existing work and eventual migration

The historical `emr/package` branch and releases through `emr-v0.3.0` preserve the
existing implementation and tests, but build **Island Monitor**, a separate app.
They are legacy companion releases, not dependent extensions. Do not direct users
to those installers as an emr extension installation method.

Once the host interface is available, port feature behaviour into the separate
extension package and test host-absent rejection, version mismatches, install,
disable, removal, restart, preserved settings and a single island instance.
Import only the old emr colour, shortcuts and relevant layout choices; never
replace all of the user's Vorssaint settings with the old companion profile.
Retire the old app only after the extension works and both settings sets have
been backed up. Update the README with each future published extension release.
