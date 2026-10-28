#!/bin/bash
# Full source-release validation; shared by PR CI and release candidate CI.
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 EMRPackage/tools/check-release-docs.py
python3 -m unittest discover -s EMRPackage/tests -v
./EMRPackage/install.command --dry-run
./Tools/test-dashboard.sh
./build-dashboard.sh
"build/stage.noindex/Island Monitor.app/Contents/MacOS/IslandMonitor" --selftest
codesign --verify --deep --strict "build/stage.noindex/Island Monitor.app"
./build-dashboard.sh --test-suite=notch --test-suite=settings
