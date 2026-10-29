// SPDX-License-Identifier: GPL-3.0-or-later
// emr package additions, 2026.
import AppKit
import SwiftUI

struct NotchLauncherSettings: View {
    @ObservedObject private var launcher = IslandLauncherService.shared
    @ObservedObject private var websiteIcons = WebsiteShortcutIconService.shared
    @AppStorage(DefaultsKey.notchQuickAccessLayout) private var layoutData = Data()
    @State private var addingWebsite = false

    var body: some View {
        SettingsCard(title: "App shortcuts", emrFeature: true) {
            Text("Add apps, games and websites individually. Each gets its own side icon. Websites open in your default browser.")
                .font(.callout).foregroundStyle(.secondary)
            if launcher.entries.isEmpty { Text("No shortcuts added yet.").foregroundStyle(.secondary) }
            ForEach(Array(launcher.entries.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    if let url = launcher.resolvedURL(entry) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24)
                    } else if entry.website != nil {
                        Group {
                            if let image = websiteIcons.icons[entry.id] {
                                WebsiteShortcutIcon(image: image, lightBackground: websiteIcons.darkIcons.contains(entry.id), size: 24)
                            } else { Image(systemName: "globe").resizable().scaledToFit().padding(3) }
                        }.frame(width: 24, height: 24).onAppear { websiteIcons.load(entry) }
                    } else { Image(systemName: "exclamationmark.triangle").frame(width: 24) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name).lineLimit(1)
                        if let website = entry.website {
                            Text(websiteIcons.loading.contains(entry.id) ? "Fetching website icon…" : website)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1).help(website)
                            if websiteIcons.failed.contains(entry.id) {
                                Text(websiteIcons.icons[entry.id] == nil ? "Icon unavailable; shortcut still works." : "Couldn’t refresh; using saved icon.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    if entry.website != nil {
                        Button { websiteIcons.load(entry, refresh: true) } label: { Image(systemName: "arrow.clockwise") }
                            .disabled(websiteIcons.loading.contains(entry.id))
                            .accessibilityLabel("Refresh icon for \(entry.name)")
                            .help("Fetch this website’s icon again")
                    }
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
                Button("Add Website…") { addingWebsite = true }
                Menu("Add from CrossOver") {
                    ForEach(launcher.crossOverApps()) { app in
                        Button(app.title) { launcher.add(app.url) }.disabled(launcher.contains(app.url))
                    }
                }.disabled(launcher.crossOverApps().isEmpty)
            }
            Text("Each side has three button slots, including hidden section buttons. Move or remove buttons in the layout editor above to make room. Removing a shortcut does not uninstall an app or change a website.")
                .font(.caption).foregroundStyle(.secondary)
        }.sheet(isPresented: $addingWebsite) { WebsiteShortcutEditor() }
    }
}

private struct WebsiteShortcutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var name = ""
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Website").font(.title3.weight(.semibold))
            TextField("Website URL", text: $address, prompt: Text("https://example.com"))
                .textFieldStyle(.roundedBorder).focused($addressFocused)
                .accessibilityIdentifier("emr.website.address")
            TextField("Name (optional)", text: $name)
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("emr.website.name")
            if !address.isEmpty && IslandLauncherSupport.websiteURL(address) == nil {
                Text("Enter an http or https address without a username or password.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Opens in your default browser. The website is contacted to fetch its icon.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add") {
                    if IslandLauncherService.shared.addWebsite(address, name: name) { dismiss() }
                }.keyboardShortcut(.defaultAction).disabled(IslandLauncherSupport.websiteURL(address) == nil)
            }
        }.padding(20).frame(width: 400).onAppear { addressFocused = true }
    }
}
