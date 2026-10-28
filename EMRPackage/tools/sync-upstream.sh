#!/bin/bash
# Merge a new stable upstream release into a review branch; never auto-merge it.
set -euo pipefail
cd "$(dirname "$0")/../.."
CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then CHECK_ONLY=1; elif [[ $# -ne 0 ]]; then exit 2; fi
EMR_REPO=$(python3 -c 'import json; print(json.load(open("EMRPackage/package.json"))["repository"])')
EMR_BASE=$(python3 -c 'import json; print(json.load(open("EMRPackage/package.json"))["developmentBranch"])')
EMR_CURRENT=$(python3 -c 'import json; print(json.load(open("EMRPackage/package.json"))["upstream"]["tag"])')
EMR_LATEST=$(gh api repos/vorssaint/vorssaint-utils/releases/latest --jq .tag_name)
if [[ ! "$EMR_LATEST" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Unsupported upstream release tag: $EMR_LATEST" >&2; exit 1
fi
printf 'Package base: %s\nLatest official stable: %s\n' "$EMR_CURRENT" "$EMR_LATEST"
if [[ "$EMR_CURRENT" == "$EMR_LATEST" ]]; then echo 'Already following the latest stable release.'; exit 0; fi
if [[ "$CHECK_ONLY" == 1 ]]; then echo 'An upstream update is available.'; exit 0; fi
if [[ -n "$(git status --porcelain)" ]]; then echo 'Commit or stash local work before syncing.' >&2; exit 1; fi
EMR_BRANCH="updates/vorssaint-$EMR_LATEST"
if git ls-remote --exit-code --heads origin "$EMR_BRANCH" >/dev/null 2>&1; then
    echo "Review branch already exists: https://github.com/$EMR_REPO/compare/$EMR_BASE...$EMR_BRANCH"
    exit 0
fi
if ! git remote get-url upstream >/dev/null 2>&1; then git remote add upstream https://github.com/vorssaint/vorssaint-utils.git; fi
if [[ "$(git rev-parse --is-shallow-repository)" == true ]]; then git fetch --unshallow upstream; fi
git fetch upstream "refs/tags/$EMR_LATEST:refs/tags/$EMR_LATEST"
git fetch origin "$EMR_BASE"
git switch -c "$EMR_BRANCH" "origin/$EMR_BASE"
if ! git merge --no-edit "$EMR_LATEST"; then
    git merge --abort
    echo 'Upstream conflicts require manual resolution; no replacement package was published.' >&2
    exit 1
fi
EMR_UPSTREAM_SHA=$(git rev-parse "$EMR_LATEST^{commit}")
python3 - "$EMR_LATEST" "$EMR_UPSTREAM_SHA" <<'PY'
import json,sys
from pathlib import Path
p=Path('EMRPackage/package.json'); d=json.loads(p.read_text())
d['upstream']['tag'], d['upstream']['commit'] = sys.argv[1:]
p.write_text(json.dumps(d,indent=2)+'\n')
PY
git add EMRPackage/package.json
git diff --cached --quiet || git commit -m "chore(emr): record upstream $EMR_LATEST"
./Tools/test-dashboard.sh
python3 -m unittest discover -s EMRPackage/tests -v
./build-dashboard.sh
"build/stage.noindex/Island Monitor.app/Contents/MacOS/IslandMonitor" --selftest
./build-dashboard.sh --test-suite=notch --test-suite=settings
git push -u origin "$EMR_BRANCH"
EMR_BODY=$(mktemp)
trap 'rm -f "$EMR_BODY"' EXIT
cat > "$EMR_BODY" <<BODY
Update the emr package source base from $EMR_CURRENT to official Vorssaint $EMR_LATEST.

The companion was built and its self-test, focused usage checks, installer tests,
and Dynamic Island/settings regressions passed before this branch was pushed.
Review the upstream changes and exercise the island on a real Mac before merging.
No app release or installed application has been replaced automatically.
BODY
if ! gh pr create --repo "$EMR_REPO" --base "$EMR_BASE" --head "$EMR_BRANCH" \
    --title "chore(emr): follow Vorssaint $EMR_LATEST" --body-file "$EMR_BODY"; then
    echo "The tested branch was pushed. Repository policy prevented automatic PR creation."
    echo "Create the PR here: https://github.com/$EMR_REPO/compare/$EMR_BASE...$EMR_BRANCH?expand=1"
fi
