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

Use the repo-scoped [release-review skill](../.agents/skills/emr-release-review/SKILL.md)
when preparing or reviewing a public release. It produces a readiness report tied
to a full commit SHA and reuses the existing validation scripts.

The **emr source release** workflow is the supported publishing path after these
changes are merged into `emr/package`. Run it from that branch with the full
candidate commit SHA. `draft` is the default mode; `publish` is for a public release
the user has requested. Both modes select an existing commit on `emr/package`,
then run the complete source-package validation on that exact commit before a
separate job receives release-write permission.

The finalizer creates a source tag and draft release, verifies the tag and
source-only release metadata, and publishes only in `publish` mode. It refuses
to move an existing tag or add binary assets. A matching draft can be retried;
an already published matching release is verified without editing it. A new
package change needs a new version and validation. Draft mode creates a remote
tag and draft release; it is not a local dry run.

For example, after the candidate is merged and its version is ready:

```sh
gh workflow run emr-release.yml --ref emr/package \
  -f commit=FULL_40_CHARACTER_CANDIDATE_SHA -f mode=draft
# Select mode=publish only for a requested public release.
```

`python3 EMRPackage/tools/source-release.py inspect --commit FULL_SHA` is the
read-only preflight. `./EMRPackage/tools/validate-release.sh` runs the shared full
validation locally without installing the app. GitHub Actions reruns it for the
selected release commit. The finalizer is an internal workflow step and refuses
ordinary local invocation without the successful exact-commit workflow context.

Configure a branch ruleset for `emr/package` requiring the package CI `validate`
check before merge, with the branch up to date, no routine bypass and no force
pushes/deletions. Keep PR review requirements proportional to the available
maintainers; do not require a second reviewer in a solo repository. Rulesets
require repository admin access and are configured separately from these files.
Direct repository admins can still bypass or change settings; a skill is not a
technical access boundary. Restrict release/tag creation to the intended maintainers
or release automation when enabling stronger enforcement.

Post-release verification checks that the source tag still names the validated
SHA, the release has the intended draft/public state, and public source archive
links are present. A successful dry-run/build does not establish a fresh-machine
install or complete visual review. Perform those when installation/UI changes
make them relevant. The filename preflight blocks known private-note and credential
paths; use review and appropriate secret scanning for content-level exposure.

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

Use the workflow above for tagging and release creation; direct tag/publish
commands do not run the new exact-commit validation path.

The user chose GitHub source-only distribution on 28 October 2026. Do not pursue
Apple Developer membership, Developer ID signing, notarization or binary installers
for this project. Local ad-hoc signing remains part of building the source companion;
it does not require a Developer Program identity. No signing credentials are needed
or bundled. Future feature releases follow the same source-only model unless the
user changes this project decision.
