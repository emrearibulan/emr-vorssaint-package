// SPDX-License-Identifier: GPL-3.0-or-later
// emr package additions, 2026.
import AppKit
import SwiftUI

struct NotchLauncherSettings: View {
    @ObservedObject private var launcher = IslandLauncherService.shared
    @AppStorage(DefaultsKey.notchQuickAccessLayout) private var layoutData = Data()

    var body: some View {
        SettingsCard(title: "Apps & Games") {
            Text("Add apps individually. Each gets its own side icon; CrossOver launchers open their own bottle and game.")
                .font(.callout).foregroundStyle(.secondary)
            if launcher.entries.isEmpty { Text("No apps added yet.").foregroundStyle(.secondary) }
            ForEach(Array(launcher.entries.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    if let url = launcher.resolvedURL(entry) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24)
                    } else { Image(systemName: "exclamationmark.triangle").frame(width: 24) }
                    Text(entry.name).lineLimit(1)
                    Spacer()
                    Picker("Side for \(entry.name)", selection: Binding<String>(
                        get: { _ = layoutData; return launcher.side(for: entry.id)?.rawValue ?? "hidden" },
                        set: { launcher.place(entry.id, on: NotchQuickAccessSide(rawValue: $0)) })) {
                        Text("Not placed").tag("hidden")
                        Text("Left").tag("left")
                        Text("Right").tag("right")
                        Text("Bottom").tag("bottom")
                    }.labelsHidden().frame(width: 110).accessibilityLabel("Side for \(entry.name)")
                    Button { launcher.move(entry.id, by: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0).accessibilityLabel("Move \(entry.name) up")
                    Button { launcher.move(entry.id, by: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == launcher.entries.count - 1).accessibilityLabel("Move \(entry.name) down")
                    Button { launcher.remove(entry.id) } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel("Remove \(entry.name)")
                }
            }
            HStack {
                Button("Add App or Game…") { launcher.chooseApp() }
                Menu("Add from CrossOver") {
                    ForEach(launcher.crossOverApps()) { app in
                        Button(app.title) { launcher.add(app.url) }.disabled(launcher.contains(app.url))
                    }
                }.disabled(launcher.crossOverApps().isEmpty)
            }
            Text("Each side has three button slots, including hidden section buttons. Move or remove buttons in the layout editor above to make room. Removing an app entry does not uninstall it.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
