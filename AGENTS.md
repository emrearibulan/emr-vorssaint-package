# emr package development

The package development branch is `emr/package`. The official app remains separate
from the Island Monitor companion. Preserve app identity, saved preferences and
upstream attribution. The feature name is **Sys Performance**; branding is **emr**.

For release preparation, readiness reviews or publishing, use
[emr-release-review](.agents/skills/emr-release-review/SKILL.md). Consult it when
planning changes that affect installation, updates or the public release contract.
Ordinary edits need only the checks appropriate to the change.

Read `EMRPackage/MAINTAINING.md` for package policy. Public distribution is GitHub
source and release notes only. Update README and the package changelog with each
release; never add app binaries, PKGs, signing credentials or personal assistant
notes. Preparing a release does not itself authorize publication.
