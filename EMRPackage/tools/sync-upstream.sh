#!/bin/zsh
# Prepare a reviewable merge of Vorssaint main; never install or release it.
set -euo pipefail
cd "${0:A:h:h:h}"
CHECK_ONLY=0
if [[ "${1:-}" == --check ]]; then CHECK_ONLY=1; elif [[ $# -ne 0 ]]; then exit 2; fi
[[ -z "$(git status --porcelain)" ]] || { print -u2 'Commit or stash work before syncing.'; exit 1; }
EMR_BASE=$(python3 -c 'import json; print(json.load(open("EMRPackage/package.json"))["developmentBranch"])')
EMR_OLD=$(python3 -c 'import json; print(json.load(open("EMRPackage/package.json"))["upstream"]["commit"])')
if ! git remote get-url upstream >/dev/null 2>&1; then
    git remote add upstream https://github.com/vorssaint/vorssaint-utils.git
fi
[[ "$(git remote get-url upstream)" == https://github.com/vorssaint/vorssaint-utils.git ]] || exit 1
if [[ "$(git rev-parse --is-shallow-repository)" == true ]]; then git fetch --unshallow upstream; fi
git fetch upstream main
EMR_NEW=$(git rev-parse upstream/main)
print "Reviewed upstream: $EMR_OLD"
print "Current main:      $EMR_NEW"
if [[ "$EMR_OLD" == "$EMR_NEW" ]]; then print 'Already following current main.'; exit 0; fi
if (( CHECK_ONLY )); then print 'Upstream changes need review.'; exit 0; fi
EMR_BRANCH="updates/upstream-${EMR_NEW[1,12]}"
if git ls-remote --exit-code --heads origin "$EMR_BRANCH" >/dev/null 2>&1; then
    print "Review branch already exists: $EMR_BRANCH"; exit 0
fi
git fetch origin "$EMR_BASE"
git switch --no-track -c "$EMR_BRANCH" "origin/$EMR_BASE"
if ! git merge --no-edit upstream/main; then
    git merge --abort
    print -u2 'Resolve upstream conflicts manually. No release or app was replaced.'
    exit 1
fi
python3 - "$EMR_OLD" "$EMR_NEW" "$EMR_BASE" <<'PY'
import json, subprocess, sys
from pathlib import Path
old,new,branch=sys.argv[1:]
p=Path('EMRPackage/package.json'); data=json.loads(p.read_text())
data['upstream']['commit']=new; data['status']='unreleased'
p.write_text(json.dumps(data,indent=2)+'\n')
p=Path('README.md'); s=p.read_text().replace(old,new)
s=s.replace('--branch emr-v'+data['version']+' ', '--branch '+branch+' ')
p.write_text(s)
Path('docs/UPSTREAM_README.md').write_bytes(subprocess.check_output(['git','show','upstream/main:README.md']))
p=Path('EMRPackage/CHANGELOG.md'); s=p.read_text(); line='\nPending upstream integration: `'+new+'`; review and assign a new release version before publishing.\n'
p.write_text(s.replace('\n',line,1))
PY
git add EMRPackage/package.json README.md docs/UPSTREAM_README.md EMRPackage/CHANGELOG.md
git commit -m "chore(emr): record reviewed upstream candidate ${EMR_NEW[1,12]}"
python3 EMRPackage/tools/check-release-docs.py
python3 -m unittest discover -s EMRPackage/tests -v
./Tools/test-dashboard.sh
./Tools/test-launcher.sh
./EMRPackage/install.command --build-only
./build-emr.sh --test-suite=notch --test-suite=settings --test-suite=repository
git push -u origin "$EMR_BRANCH"
print "Tested review branch: $EMR_BRANCH. Merge after review; publish separately with README/version updates."
