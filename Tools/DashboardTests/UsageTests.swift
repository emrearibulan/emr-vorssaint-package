import Foundation

@main
struct UsageTests {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        for (value, expected): (Double?, DashboardUsageBand) in [
            (nil, .unknown), (.nan, .unknown), (.infinity, .unknown), (-0.1, .unknown),
            (0, .low), (0.5999, .low), (0.6, .moderate), (0.7999, .moderate),
            (0.8, .high), (0.8999, .high), (0.9, .critical), (1, .critical), (1.2, .critical)
        ] { check(DashboardUsageBand(consumedFraction: value) == expected, "colour boundary \(String(describing: value))") }
        check(DashboardUsageBand.ratio(consumed: 90, capacity: 100) == 0.9, "consumption/capacity")
        check(DashboardUsageBand.ratio(consumed: 100, capacity: 0) == nil, "zero capacity is unknown")
        check(DashboardUsageBand.ratio(consumed: -1, capacity: 100) == nil, "negative consumption is unknown")
        check(DashboardUsageBand.ratio(consumed: 1, capacity: .nan) == nil, "invalid capacity is unknown")
        check(DashboardUsageBand.ratio(consumed: 200, capacity: 100) == 1, "over-capacity clamps")
        // Available disk and battery values must be coloured by the consumed part.
        check(DashboardUsageBand(consumedFraction: 1 - 0.05) == .critical, "5% free means critical consumption")
        check(DashboardUsageBand(consumedFraction: 1 - 0.9) == .low, "90% free means low consumption")
        let now = Date(timeIntervalSince1970: 1_000_000)
        func window(_ id: String, _ kind: AgentLimitWindow.Kind, _ used: Double, reset: Date? = nil) -> AgentLimitWindow {
            AgentLimitWindow(id: id, kind: kind, minutes: nil, scope: nil, usedPercent: used, resetsAt: reset)
        }
        let future = now.addingTimeInterval(3600)
        let current = DashboardCodexLimits(limits: AgentLimits(provider: .codex, windows: [
            window("session", .session, 25, reset: future), window("week", .weekly, 85, reset: future)
        ], observedAt: now, source: .sessionLog), now: now)
        check(current.session?.remainingFraction == 0.75, "session remaining")
        check(abs((current.weekly?.remainingFraction ?? 0) - 0.15) < 0.0001, "week remaining")
        check(current.consumedFraction == 0.85, "most consumed allowance determines colour")
        let expired = DashboardCodexLimits(limits: AgentLimits(provider: .codex, windows: [
            window("session", .session, 95, reset: now), window("invalid", .weekly, .nan)
        ], observedAt: now, source: .sessionLog), now: now)
        check(expired.session == nil && expired.weekly == nil && expired.consumedFraction == nil,
              "expired and invalid readings never invent fresh allowance")
        let other = DashboardCodexLimits(limits: AgentLimits(provider: .claude, windows: [window("other", .session, 10)],
                                                             observedAt: now, source: .account), now: now)
        check(other.session == nil, "never mix providers")
        check(DashboardCodexLimits(limits: nil, now: now).consumedFraction == nil, "missing limits stay unknown")
        print("PASS: \(checks) dashboard usage checks")
    }
}
