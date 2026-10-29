#!/bin/zsh
# Only install a published integrated source release, never a legacy companion.
set -euo pipefail
EMR_ROOT="${0:A:h:h}"
EMR_REPO=emrearibulan/emr-vorssaint-package
EMR_TAG="$(curl --connect-timeout 15 --max-time 60 --fail --silent --show-error --location "https://api.github.com/repos/$EMR_REPO/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
[[ "$EMR_TAG" =~ '^emr-v[0-9]+\.[0-9]+\.[0-9]+$' ]] || exit 1
EMR_TEMP="$(mktemp -d -t emr-integrated-update)"
trap 'rm -rf "$EMR_TEMP"' EXIT
git -c advice.detachedHead=false clone --depth 1 --branch "$EMR_TAG" "https://github.com/$EMR_REPO.git" "$EMR_TEMP/package"
python3 - "$EMR_TEMP/package/EMRPackage/package.json" <<'CHECK'
import json,sys
metadata=json.load(open(sys.argv[1]))
if metadata.get('architecture') != 'integrated-source-addon' or metadata.get('app',{}).get('bundleIdentifier') != 'com.vorssaint.utils':
    sys.exit('No integrated emr release is published yet. Keeping this Vorssaint installation unchanged. Do not install the older Island Monitor release over it.')
CHECK
"$EMR_TEMP/package/EMRPackage/install.command" "$@"
