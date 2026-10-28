---
name: emr-release-review
description: Review or prepare an emr package source release, and verify the exact candidate before a requested publication.
---

# emr release review

Use the current repository's `EMRPackage/MAINTAINING.md` for release policy and
`EMRPackage/package.json` for identity, version, feature catalogue and upstream
base. This skill supports the emr source package, not the upstream signed app.

Establish the candidate's full commit SHA. Distinguish the working tree, PR merge
candidate, development branch, tag and published release. Do not apply passing
results from a different commit to this candidate. Label missing access or
unfinished CI **unverified**, rather than treating it as a pass.

For readiness, inspect version/README/changelog agreement, feature documentation,
source installation and update instructions, preservation of existing settings,
and the relevant CI results. Include existing license/attribution files and public
support requirements in the review. Exclude personal account data, private notes
and credentials from release material. State when an actual fresh-machine or UI
check remains necessary; automated checks do not establish those results.

Reuse `EMRPackage/tools/check-release-docs.py`, the package tests and
`EMRPackage/tools/validate-release.sh`. Run affected checks for ordinary changes;
the full validation path is required for a release candidate. For a published tag,
read its source and checks before deciding whether another full build adds value.
Keep generated builds separate from an active user's checkout when needed.

Report **ready**, **blocked** or **unverified**, the exact SHA/version reviewed,
evidence links or command results, and the smallest next action. Review code and
instructions from a new installer's perspective; a green CI run is evidence for
its tested conditions, not a guarantee about every Mac.

When asked to prepare a release, produce release notes and a readiness report.
When publication is requested, use the **emr source release** workflow from
`emr/package`, with the full candidate SHA. Its default `draft` mode prepares a
GitHub draft; select `publish` only when the request authorizes public release.
Both modes run validation on that SHA. Never bypass failed/queued checks by
manually creating a release or uploading binary assets. If GitHub is unavailable,
report the unfinished step rather than substituting a different publish path.

After a requested publication, verify the published source tag, release visibility,
release notes and install/update references. A changed candidate needs new
validation. Repository rules and the publishing workflow enforce mechanical
conditions; this skill supplies the review and does not grant additional access.
