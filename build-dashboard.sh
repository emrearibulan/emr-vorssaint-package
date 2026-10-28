#!/bin/zsh
# Build an isolated, ad-hoc signed local companion without touching keychains.
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PY'
from pathlib import Path
import json, re
package = json.loads(Path("EMRPackage/package.json").read_text())
version = package["version"]
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
    raise SystemExit("Invalid emr package version")
s=Path('build.sh').read_text()
def replace_once(old, new):
    global s
    if s.count(old) != 1:
        raise SystemExit("Upstream build layout changed; review this adapter: " + old)
    s = s.replace(old, new, 1)
replace_once('APP_NAME="Vorssaint (Developer)"', 'APP_NAME="Island Monitor"')
replace_once('EXECUTABLE="VorssaintDeveloper"', 'EXECUTABLE="IslandMonitor"')
replace_once('APP_BUNDLE_ID="com.vorssaint.utils.dev"', 'APP_BUNDLE_ID="local.emre.islandmonitor.dev"')
replace_once('BUILD_VARIANT_FLAGS=(-D VORSSAINT_DEVELOPMENT)', 'BUILD_VARIANT_FLAGS=(-D VORSSAINT_DEVELOPMENT -D ISLAND_MONITOR_LOCAL)')
replace_once('cp Resources/Info.plist "$STAGE/Contents/Info.plist"',
             'cp Resources/Info.plist "$STAGE/Contents/Info.plist"\n'
             'cp EMRPackage/package.json "$STAGE/Contents/Resources/EMRPackage.json"\n'
             'cp EMRPackage/assets/emr-mark.png "$STAGE/Contents/Resources/EmrFeatureMark.png"\n'
             '/usr/libexec/PlistBuddy -c "Add :EMRPackageVersion string ' + version + '" "$STAGE/Contents/Info.plist"')
a=s.index('developer_id_identity() {'); b=s.index('# Any build that lands', a)
s=s[:a]+'''developer_id_identity() { return 0; }
legacy_identity_installed() { return 1; }

'''+s[b:]
a=s.index('if (( DEV || INSTALL ))'); b=s.index('\ncodesign_with_timestamp_retry()',a)
s=s[:a]+s[b:]
s=s.replace('$(sysctl -n hw.logicalcpu)', '2')
s=s.replace('swiftc ', 'swiftc -module-cache-path "$PWD/build/module-cache" ')
s=s.replace('swift Tools/MakeIcon.swift', 'swift -module-cache-path "$PWD/build/module-cache" Tools/MakeDashboardIcon.swift')
Path('.dashboard-build.sh').write_text(s)
PY
trap 'rm -f .dashboard-build.sh' EXIT
/bin/zsh .dashboard-build.sh --dev "$@"
