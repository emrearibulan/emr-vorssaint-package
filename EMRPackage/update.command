#!/bin/zsh
# Fetch a published emr release, build it locally and retain existing preferences.
set -euo pipefail
EMR_PACKAGE_ROOT="${0:A:h:h}"
EMR_REPOSITORY="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["repository"])' "$EMR_PACKAGE_ROOT/EMRPackage/package.json")"
if [[ "$EMR_REPOSITORY" != "emrearibulan/emr-vorssaint-package" ]]; then
    print -u2 -- "Unexpected update repository; review package.json before continuing."
    exit 1
fi
EMR_TAG="$(/usr/bin/curl --fail --silent --show-error --location "https://api.github.com/repos/$EMR_REPOSITORY/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
if [[ ! "$EMR_TAG" =~ '^emr-v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 -- "No supported emr source release is available."
    exit 1
fi
EMR_TEMP="$(mktemp -d -t emr-update)"
trap 'rm -rf "$EMR_TEMP"' EXIT
/usr/bin/git clone --depth 1 --branch "$EMR_TAG" "https://github.com/$EMR_REPOSITORY.git" "$EMR_TEMP/package"
"$EMR_TEMP/package/EMRPackage/install.command" "$@"
