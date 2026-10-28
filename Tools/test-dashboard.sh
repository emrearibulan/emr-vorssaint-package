#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/dashboard-tests build/module-cache
TASK_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
TASK_FLAGS=(-Xfrontend -interface-compiler-version -Xfrontend 6.3.2)
if [[ ! -d "$TASK_SDK" ]]; then
    TASK_SDK="$(xcrun --show-sdk-path)"
    TASK_FLAGS=()
fi
swiftc -sdk "$TASK_SDK" "${TASK_FLAGS[@]}" -module-cache-path "$PWD/build/module-cache" \
    Sources/Vorssaint/Services/AgentUsage/AgentUsageModels.swift \
    Sources/Vorssaint/Services/Notch/DashboardUsageSupport.swift \
    Tools/DashboardTests/UsageTests.swift -o build/dashboard-tests/usage-tests
build/dashboard-tests/usage-tests
