# Maintaining emr package

## Source and release model

`emr/package` is the package development branch. The fork retains the original
upstream history; the `upstream` remote points at vorssaint/vorssaint-utils.
`EMRPackage/package.json` records the independently versioned package, exact
upstream base commit/tag, stable app identity and the catalogue of bundled features.
The installed app remains `Island Monitor.app` with bundle ID
`local.emre.islandmonitor.dev` so existing colour choices survive updates.

The official Vorssaint app and its updater are independent. We do not modify,
inject code into or redistribute a modified binary under the official app's
identity. A downloaded official app is assessed by macOS and checked for the
maintainer's bundle ID and signing team. Future signing-team changes need review.

## Following Vorssaint releases

The daily `emr upstream release check` workflow runs from the repository's default
`emr/package` branch. It checks the latest stable upstream release, and does nothing
while the package already follows it. When a new tag appears it:

1. Starts `updates/vorssaint-vX.Y.Z` from the package branch and merges that tag.
2. Stops on merge conflicts instead of overwriting custom work.
3. Records the exact upstream commit in package.json.
4. Runs installer tests, usage checks, a complete companion build/self-test, and
   the Dynamic Island/settings regression suites.
5. Pushes the tested review branch and opens a pull request when repository policy
   allows GitHub Actions to create PRs. Otherwise the workflow prints the compare
   link for manual PR creation.

It never auto-merges or publishes a new package. Review the source and test the
island on an actual Mac before merging. Scheduled jobs can be delayed or disabled
by GitHub (including inactive public repositories), so this is also runnable manually:

```sh
./EMRPackage/tools/sync-upstream.sh --check
./EMRPackage/tools/sync-upstream.sh
```

The script requires a clean checkout, `gh` authentication and the macOS build
requirements. Workflows need to be enabled for this fork. Upstream incompatibility
can require actual engineering work; no release-tracking arrangement guarantees
that custom UI changes will merge unchanged forever.

## Adding another feature

1. Create `emr/feature-name` from `emr/package`.
2. Keep services, views and settings focused; reuse the upstream feature catalogue
   for availability and permissions. Request new permissions only when needed.
3. Add a stable ID and documentation entry under `EMRPackage/features/`, and a
   catalogue entry in package.json. Implement its first-run/default registration
   in DashboardLocalProfile or a dedicated migration; a catalogue entry alone
   does not implement or enable an arbitrary feature.
4. Give each new preference a registered, backup-compatible key. Preserve existing
   choices during migrations; do not reset all preferences at a package update.
5. Add meaningful tests and extend emr package CI for the new behavior.
6. Bump the package version, test, and release the whole package together.

The current catalogue contains one feature; it is deliberately a package catalogue
rather than a downloader for arbitrary third-party scripts/plugins.

## Publishing a source release

Use a new `emr-vMAJOR.MINOR.PATCH` tag on a tested package commit. Match package.json,
write release notes, and create a stable GitHub release with that tag. Friends
install from the tagged source; `EMRPackage/update.command` fetches the latest
published emr source release and builds it locally. Quit the running companion
before updating. Its preferences stay in the same domain and its previous app is
restored if final installation verification fails.

Every published update must update README.md and EMRPackage/CHANGELOG.md in the release commit.
Before tagging:

1. Bump package.json and update the README version, installation tag, feature list and affected instructions.
2. Add the release as the first version in EMRPackage/CHANGELOG.md, describing what changed and any migration steps.
3. Run `python3 EMRPackage/tools/check-release-docs.py` and the checks appropriate to the change. CI also runs the documentation check.
4. Review the README from a new user's perspective; automated checks do not validate every instruction.
5. Publish only GitHub source and release notes. Do not upload app binaries, PKGs or signing material.

For example, after documentation and tests have passed:

```sh
git tag emr-v0.1.3
git push origin emr-v0.1.3
gh release create emr-v0.1.3 --repo emrearibulan/emr-vorssaint-package \
  --title 'emr package 0.1.3' --notes-file release-notes.md
```

The user chose GitHub source-only distribution on 28 October 2026. Do not pursue
Apple Developer membership, Developer ID signing, notarization or binary installers
for this project. Local ad-hoc signing remains part of building the source companion;
it does not require a Developer Program identity. No signing credentials are needed
or bundled. Future feature releases follow the same source-only model unless the
user changes this project decision.
