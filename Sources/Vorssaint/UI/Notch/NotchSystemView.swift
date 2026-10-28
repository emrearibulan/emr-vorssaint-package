// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct NotchSystemView: View {
    let size: CGSize
    let select: (MetricDetailKind) -> Void
    let showAgents: () -> Void
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var usage = AgentUsageService.shared
    @ObservedObject private var fans = FanControlService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.networkSpeedUnit) private var networkSpeedUnit = NetworkSpeedUnit.bytes
    @AppStorage(DefaultsKey.notchSystemUnknownColor) private var unknownColor = "#FFFFFF"
    @Environment(\.notchSettingsPreview) private var preview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Card: Identifiable {
        var kind: MetricDetailKind? = nil
        let title: String
        let symbol: String
        let value: String?
        var detail: String? = nil
        var level: Double? = nil
        var consumedFraction: Double? = nil
        var hint: String = ""
        var id: String { kind?.rawValue ?? "codex" }
    }

    private func cards(now: Date) -> [Card] {
        let snapshot = monitor.snapshot
        var cards: [Card] = []
        if AppFeature.monitorCPU.isAvailable {
            cards.append(Card(kind: .cpu, title: l10n.s.cpuLabel, symbol: "cpu",
                              value: percent(snapshot.cpuUsage), level: snapshot.cpuUsage,
                              consumedFraction: snapshot.cpuUsage))
        }
        if AppFeature.monitorGPU.isAvailable {
            cards.append(Card(kind: .gpu, title: l10n.s.gpuLabel, symbol: "rectangle.connected.to.line.below",
                              value: percent(snapshot.gpuUsage), level: snapshot.gpuUsage,
                              consumedFraction: snapshot.gpuUsage))
        }
        if AppFeature.monitorMemory.isAvailable {
            let ratio = snapshot.memoryUsed.flatMap { used in
                snapshot.memoryTotal.flatMap { total in total > 0 ? Double(used) / Double(total) : nil }
            }
            cards.append(Card(kind: .memory, title: l10n.s.memorySection, symbol: "memorychip",
                              value: percent(ratio), level: ratio, consumedFraction: ratio))
        }
        if AppFeature.monitorPower.isAvailable, let power = snapshot.power, power.hasBattery {
            cards.append(Card(kind: .battery, title: l10n.s.batteryLabel,
                              symbol: power.externalConnected ? "battery.100percent.bolt" : "battery.100percent",
                              value: power.chargePercent.map { "\($0)%" },
                              level: power.chargePercent.map { Double($0) / 100 },
                              consumedFraction: power.chargePercent.map { 1 - Double($0) / 100 }))
        }
        if AppFeature.monitorNetwork.isAvailable {
            // The observed unit, so a switch redraws the card at once, not on the next sample.
            let inBits = networkSpeedUnit == .bits
            cards.append(Card(kind: .network, title: l10n.s.networkSection, symbol: "network",
                              value: snapshot.netDownBytesPerSec.map { "↓ " + MetricFormat.networkRate($0, inBits: inBits) },
                              detail: snapshot.netUpBytesPerSec.map { "↑ " + MetricFormat.networkRate($0, inBits: inBits) }))
        }
        if AppFeature.monitorDisk.isAvailable {
            let disk = snapshot.disk?.devices.first(where: { $0.mountPath == "/" })
                ?? snapshot.disk?.devices.first(where: \.isInternal)
            cards.append(Card(kind: .disk, title: l10n.s.diskAvailable.localizedCapitalized, symbol: "internaldrive",
                              value: disk.map { MetricFormat.diskBytes($0.freeBytes) },
                              level: disk.map { 1 - $0.usedFraction },
                              consumedFraction: disk.map { $0.usedFraction }))
        }
        // The panel's power and fan sections, as cards opening the same details.
        if AppFeature.monitorPower.isAvailable {
            let power = snapshot.power
            cards.append(Card(kind: .power, title: l10n.s.powerSection, symbol: "powerplug.fill",
                              value: power?.systemWatts.map(MetricFormat.wattsCompact),
                              detail: power?.externalConnected == true ? power?.adapterWatts.map(MetricFormat.watts) : nil,
                              consumedFraction: DashboardUsageBand.ratio(consumed: power?.systemWatts, capacity: power?.adapterMaxWatts)))
        }
        if AppFeature.fanControl.isAvailable, !snapshot.fanSpeeds.isEmpty {
            let strings = FeatureStrings.fanControl(l10n.language)
            cards.append(Card(kind: .fan, title: strings.title, symbol: "fanblades",
                              value: snapshot.fanSpeeds.first.map { String(format: strings.rpmFormat, Int($0.rounded())) },
                              consumedFraction: DashboardUsageBand.ratio(consumed: snapshot.fanSpeeds.first,
                                  capacity: fans.snapshot.fans.first(where: { $0.index == 0 })?.maximumRPM)))
        }
        if NotchAgentSupport.sectionShows() && NotchAgentSupport.providers().contains(.codex) {
            let snapshot = usage.snapshot
            let limits = DashboardCodexLimits(limits: snapshot.limits[.codex], now: now)
            let tokens = snapshot.usage(.today).byProvider[.codex]?.tokens.total
            let session = limits.session.map { "\(Int(($0.remainingFraction * 100).rounded()))% session left" }
            var details: [String] = []
            if let weekly = limits.weekly { details.append("Week \(Int((weekly.remainingFraction * 100).rounded()))% left") }
            if let tokens { details.append(AgentFormat.tokens(tokens) + " tokens today") }
            var hints = ["Codex usage on your ChatGPT plan; ChatGPT chat limits are not available here.",
                         "Token totals come from this Mac's Codex logs and include cached input."]
            if let report = snapshot.limits[.codex] {
                hints.append("Last reported: " + report.observedAt.formatted(date: .abbreviated, time: .shortened))
            }
            for window in [limits.session, limits.weekly].compactMap({ $0 }) {
                if let reset = window.resetsAt {
                    hints.append((window.kind == .session ? "Session" : "Week") + " resets "
                                 + reset.formatted(date: .abbreviated, time: .shortened))
                }
            }
            cards.append(Card(title: "ChatGPT · Codex", symbol: AgentProvider.codex.symbol,
                              value: session ?? (snapshot.loaded ? "Limits unavailable" : "Loading…"),
                              detail: details.isEmpty ? "Open AI Agents for details" : details.joined(separator: " · "),
                              consumedFraction: limits.consumedFraction, hint: hints.joined(separator: "\n")))
        }
        return cards
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            dashboard(cards: cards(now: context.date))
        }
        .onAppear {
            // A read-only probe supplies the fan's real maximum RPM. Never
            // register or replace a helper just to colour a dashboard value.
            if !preview, AppFeature.fanControl.isAvailable, fans.accessState == .notRegistered {
                fans.refresh()
            }
        }
    }

    @ViewBuilder
    private func dashboard(cards: [Card]) -> some View {
        if cards.isEmpty {
            NotchEmptyView(symbol: "gauge.with.dots.needle.50percent", message: l10n.s.monitorUnavailable)
        } else {
            let inset = NotchLayout.systemHoverInset(width: size.width)
            let rows = NotchLayout.systemRowRanges(count: cards.count, width: size.width - inset * 2)
            let height = NotchLayout.railHeight(rows: rows.count, rowHeight: NotchLayout.systemCardHeight,
                                               spacing: NotchLayout.rowSpacing) + inset * 2
            Group {
                if height > size.height {
                    ScrollView {
                        grid(cards: cards, rows: rows).padding(inset)
                            .contentShape(Rectangle())
                    }
                } else {
                    grid(cards: cards, rows: rows).padding(inset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func grid(cards: [Card], rows: [Range<Int>]) -> some View {
        VStack(spacing: NotchLayout.rowSpacing) {
            ForEach(rows, id: \.lowerBound) { row in
                HStack(spacing: NotchLayout.rowSpacing) {
                    ForEach(Array(cards[row])) { card in
                        cardButton(card)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func cardButton(_ card: Card) -> some View {
        Button { activate(card) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(card.title, systemImage: card.symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary).lineLimit(1)
                Text(card.value ?? "…")
                    .font(.system(size: card.detail == nil ? 22 : 15, weight: .medium, design: .rounded))
                    .foregroundStyle(tint(card))
                    .monospacedDigit().contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.75)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: card.value)
                if let detail = card.detail {
                    Text(detail).font(.system(size: 11)).monospacedDigit()
                        .foregroundStyle(card.consumedFraction == nil ? tint(card).opacity(0.75) : Color.secondary)
                        .lineLimit(1)
                } else if let level = card.level {
                    NotchMeter(value: level, tint: tint(card))
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: NotchLayout.systemCardHeight)
            .modifier(NotchControlSurface(cornerRadius: 18))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { activate(card) }
        .help(card.hint.isEmpty ? "Colour shows consumed capacity: green <60%, amber 60–79%, orange 80–89%, red ≥90%. Readings without capacity use the colour chosen in Settings → Dynamic Island → Content → Sys Performance." : card.hint)
        .accessibilityLabel(card.title)
        .accessibilityValue([card.value, card.detail].compactMap { $0 }.joined(separator: ", "))
    }

    private func activate(_ card: Card) {
        if let kind = card.kind { select(kind) } else { showAgents() }
    }

    private func tint(_ card: Card) -> Color {
        switch DashboardUsageBand(consumedFraction: card.consumedFraction) {
        case .unknown:
            let rgb = MenuBarUsageBarSupport.rgb(for: unknownColor, fallback: "#FFFFFF")
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    private func percent(_ value: Double?) -> String? {
        value.flatMap { $0.isFinite ? "\(Int((min(1, max(0, $0)) * 100).rounded()))%" : nil }
    }
}
