// SPDX-License-Identifier: GPL-3.0-or-later
// Local dashboard customizations, 2026.

import Foundation

enum DashboardUsageBand: Equatable {
    case unknown, low, moderate, high, critical

    init(consumedFraction: Double?) {
        guard let value = consumedFraction, value.isFinite, value >= 0 else {
            self = .unknown
            return
        }
        switch value {
        case ..<0.6: self = .low
        case ..<0.8: self = .moderate
        case ..<0.9: self = .high
        default: self = .critical
        }
    }

    static func ratio(consumed: Double?, capacity: Double?) -> Double? {
        guard let consumed, let capacity, consumed.isFinite, capacity.isFinite,
              consumed >= 0, capacity > 0 else { return nil }
        return min(1, consumed / capacity)
    }
}

/// Only reported Codex allowances, never an estimate of ChatGPT chat limits.
/// A past reset is unknown until a new report arrives; it is not assumed unused.
struct DashboardCodexLimits {
    let session: AgentLimitWindow?
    let weekly: AgentLimitWindow?

    init(limits: AgentLimits?, now: Date) {
        let valid = limits?.provider == .codex ? (limits?.windows ?? []).filter {
            $0.usedPercent.isFinite && (0...100).contains($0.usedPercent)
                && ($0.resetsAt.map { $0 > now } ?? true)
        } : []
        session = valid.filter { $0.kind == .session }.max { $0.usedPercent < $1.usedPercent }
        weekly = valid.filter { $0.kind == .weekly }.max { $0.usedPercent < $1.usedPercent }
    }

    var consumedFraction: Double? {
        [session, weekly].compactMap { $0?.usedFraction }.max()
    }
}
