// SPDX-License-Identifier: GPL-3.0-or-later
// Local dashboard customizations, 2026.

#if ISLAND_MONITOR_LOCAL
import AppKit

/// An isolated monitor-only companion; the official app keeps its own tools,
/// settings, signing identity and macOS permissions.
enum DashboardLocalProfile {
    static func prepare() {
        guard Bundle.main.bundleIdentifier == "local.emre.islandmonitor.dev",
              !CommandLine.arguments.contains("--selftest") else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "dashboardProfileInitialized") else { return }
        let enabled: Set<AppFeature> = [.notch, .notchAgents, .monitorCPU, .monitorGPU,
                                       .monitorMemory, .monitorNetwork, .monitorDisk,
                                       .monitorPower, .fanControl]
        FeaturePreset.prepareCompanionAvailability(enabled, in: defaults, isSupported: { $0.isHardwareSupported })
        defaults.set(true, forKey: DefaultsKey.hasOnboarded)
        defaults.set(OnboardingInfo.currentFeatureSet, forKey: DefaultsKey.featuresOnboardingVersion)
        defaults.set(AppInfo.version, forKey: DefaultsKey.lastUpdateIntroVersion)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.notchAgentsEnabled)
        defaults.set(true, forKey: DefaultsKey.notchAgentsCodex)
        defaults.set(false, forKey: DefaultsKey.notchAgentsClaude)
        defaults.set(false, forKey: DefaultsKey.notchAgentsOpenCode)
        defaults.set(false, forKey: DefaultsKey.notchAgentsCopilot)
        defaults.set(false, forKey: DefaultsKey.notchAgentsPriceUpdates)
        defaults.set(true, forKey: DefaultsKey.notchReturnHome)
        defaults.set("system", forKey: DefaultsKey.notchHomeModule)
        defaults.set(false, forKey: DefaultsKey.notchOpensActivity)
        defaults.set("system,agents,controls", forKey: DefaultsKey.notchModuleOrder)
        defaults.set("music,mixer,calendar,notifications,downloads,watch", forKey: DefaultsKey.notchHiddenModules)
        defaults.set("all", forKey: DefaultsKey.notchDisplay)
        defaults.set("spacious", forKey: DefaultsKey.notchSize)
        defaults.set(true, forKey: DefaultsKey.notchLiquidGlassEnabled)
        defaults.set(true, forKey: DefaultsKey.notchOpenOnHover)
        defaults.set(true, forKey: DefaultsKey.notchHoverExpands)
        defaults.set(true, forKey: "dashboardProfileInitialized")
    }
}
#endif
