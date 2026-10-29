# Maintaining Vorssaint with emr

## Architecture

The active development branch is `emr/integrated-vorssaint`, based directly on
Vorssaint `main`. Historical `emr/package` releases through 0.3.0 build a companion;
they are retained but are not the new product architecture.

`Sources/Vorssaint/Extensions/emr/` contains the source extension. Compile it with
the host via `build-emr.sh`; it has no standalone executable or independent island.
The host bridges are system-page content, top-level labels, shortcut actions,
settings and sizing. Reuse the host's metric and agent services, feature gates,
window management and defaults. Do not apply the old monitor-only first-run preset.

The combined app retains `Vorssaint.app`, executable `Vorssaint` and bundle ID
`com.vorssaint.utils`. Source releases are ad-hoc signed locally, without Keychain
setup or Developer Program credentials. Retain original licence and credits.

## Upstream changes

`EMRPackage/package.json` pins the reviewed upstream main commit. Run:

```sh
./EMRPackage/tools/sync-upstream.sh --check
./EMRPackage/tools/sync-upstream.sh
```

The sync script starts a review branch from active emr development, merges current
upstream main and updates the pinned commit. It stops on conflicts and never
publishes, installs or silently drops custom changes. Test and review that branch
before merging. Following main can include unreleased upstream changes; record
the exact commit rather than presenting it as a new official release version.

## Add another emr feature

1. Branch from active emr development.
2. Put implementation in its own subfolder under `Extensions/emr`; keep host
   edits small and documented. The module is source-integrated, not an arbitrary
   third-party runtime plugin loader.
3. Register stable preferences with host backup support, availability gates and
   a catalogue entry. Keep existing saved choices and every upstream feature.
4. Use the supplied emr icon before added top-level titles only. Keep lowercase
   branding, plain accessible titles and unchanged individual shortcut names.
5. Add appropriate regression checks, update feature docs and publish together.

## Release and migration checks

Run the documentation check, installer/migration tests, focused feature suites,
native build/self-test/signature verification, and island/settings/repository
regressions. Check install, restart, a single island, colour preservation, app and
website launch, icon refresh and other Vorssaint features on a real Mac. Report
manual checks that remain unobserved instead of treating them as passed.

The source updater must reject a legacy companion release. The app must not
install an official binary over itself and erase emr. Keep original updater
behaviour for developer builds without emr metadata.

Back up the installed host and preferences before migration; import only missing
emr fields and retire the legacy app after verified installation. Preserve the
old preferences domain and a previous-app backup. Do not bundle local settings.

Every source release must update package version/status, README install tag,
feature instructions and CHANGELOG together. Publish only source and release
notes; no compiled app, credentials or signing material. Retain historical tags.
