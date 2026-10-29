#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/launcher-tests build/module-cache
TASK_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
TASK_FLAGS=(-Xfrontend -interface-compiler-version -Xfrontend 6.3.2)
if [[ ! -d "$TASK_SDK" ]]; then
    TASK_SDK="$(xcrun --show-sdk-path)"
    TASK_FLAGS=()
fi
swiftc -sdk "$TASK_SDK" "${TASK_FLAGS[@]}" -module-cache-path "$PWD/build/module-cache" \
    Sources/Vorssaint/Extensions/emr/AppShortcuts/IslandLauncherSupport.swift \
    Sources/Vorssaint/Extensions/emr/AppShortcuts/WebsiteShortcutSupport.swift \
    Tools/LauncherTests/LauncherTests.swift -o build/launcher-tests/launcher-tests
build/launcher-tests/launcher-tests
swiftc -sdk "$TASK_SDK" "${TASK_FLAGS[@]}" -module-cache-path "$PWD/build/module-cache" \
    Sources/Vorssaint/Extensions/emr/AppShortcuts/IslandLauncherSupport.swift \
    Sources/Vorssaint/Extensions/emr/AppShortcuts/WebsiteShortcutSupport.swift \
    Sources/Vorssaint/Extensions/emr/AppShortcuts/WebsiteShortcutIconService.swift \
    Tools/LauncherTests/WebsiteIconTests.swift -o build/launcher-tests/website-icon-tests
python3 Tools/LauncherTests/network-fixture.py build/launcher-tests/website-icon-tests
