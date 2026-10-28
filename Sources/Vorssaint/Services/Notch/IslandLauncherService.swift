// SPDX-License-Identifier: GPL-3.0-or-later
// emr package additions, 2026.
import AppKit
import Combine
import UniformTypeIdentifiers

final class IslandLauncherService: ObservableObject {
    static let shared = IslandLauncherService()
    @Published private(set) var entries: [IslandLauncherEntry]
    @Published private(set) var isChoosing = false
    private var chooser: NSOpenPanel?

    struct Candidate: Identifiable {
        let url: URL
        let name: String
        let bottle: String
        var id: String { url.path }
        var title: String { bottle.isEmpty ? name : "\(name) — \(bottle)" }
    }

    private init() {
        entries = IslandLauncherSupport.decode(UserDefaults.standard.data(forKey: DefaultsKey.notchLauncherEntries) ?? Data())
    }

    func resolvedURL(_ entry: IslandLauncherEntry) -> URL? {
        var stale = false
        let bookmarked = try? URL(resolvingBookmarkData: entry.bookmark, options: [.withoutUI, .withoutMounting],
                                  relativeTo: nil, bookmarkDataIsStale: &stale)
        let url = (bookmarked ?? URL(fileURLWithPath: entry.path)).standardizedFileURL
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              (try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication) == true else { return nil }
        return url
    }

    func contains(_ url: URL) -> Bool {
        entries.contains { ($0.path == url.standardizedFileURL.path) || resolvedURL($0)?.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() }
    }

    func crossOverApps() -> [Candidate] {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/CrossOver", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isApplicationKey],
                                                        options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var results: [Candidate] = []
        while let url = files.nextObject() as? URL {
            if url.pathExtension.lowercased() == "app" {
                files.skipDescendants()
                guard let bundle = Bundle(url: url), let bottle = bundle.object(forInfoDictionaryKey: "CXHelperAppBottleName") as? String else { continue }
                results.append(Candidate(url: url, name: url.deletingPathExtension().lastPathComponent, bottle: bottle))
                if results.count == 200 { break }
            }
        }
        return results.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func add(_ url: URL) {
        guard entries.count < IslandLauncherSupport.maximumItems else { showError("The launcher can hold up to 100 apps. Remove an item before adding another."); return }
        let url = url.standardizedFileURL
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              (try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication) == true else { showError("Choose an installed Mac application (.app), including a CrossOver app launcher."); return }
        guard !contains(url) else { return }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            entries.append(IslandLauncherEntry(name: url.deletingPathExtension().lastPathComponent, path: url.path, bookmark: bookmark))
            save()
            let layout = NotchQuickAccessConfiguration.stored()
            if let side = [NotchQuickAccessSide.right, .left, .bottom].first(where: { layout.hasRoom(on: $0) }), let entry = entries.last {
                place(entry.id, on: side)
            } else {
                showError("App saved. All side-button slots are occupied. Remove a button in the layout editor, then choose a side for this app below.")
            }
        } catch { showError("Could not save this app: " + error.localizedDescription) }
    }

    func remove(_ id: UUID) {
        place(id, on: nil)
        entries.removeAll { $0.id == id }
        save()
    }

    func side(for id: UUID) -> NotchQuickAccessSide? {
        NotchQuickAccessConfiguration.stored().buttons.first { $0.action == .application(id) }?.side
    }

    func place(_ id: UUID, on side: NotchQuickAccessSide?) {
        var layout = NotchQuickAccessConfiguration.stored()
        layout.buttons.removeAll { $0.action == .application(id) }
        if let side {
            guard layout.hasRoom(on: side) else { showError("This side has three buttons already. Move or remove one in the layout editor first."); return }
            layout.buttons.append(NotchQuickButton(action: .application(id), side: side))
        }
        UserDefaults.standard.set(layout.encoded, forKey: DefaultsKey.notchQuickAccessLayout)
        NotchService.shared.syncWithPreferences()
        objectWillChange.send()
    }

    func move(_ id: UUID, by offset: Int) {
        guard let from = entries.firstIndex(where: { $0.id == id }), entries.indices.contains(from + offset) else { return }
        entries.swapAt(from, from + offset)
        save()
        var layout = NotchQuickAccessConfiguration.stored()
        let positions = layout.buttons.indices.filter { if case .application = layout.buttons[$0].action { return true }; return false }
        let order = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($0.element.id, $0.offset) })
        let buttons = positions.map { layout.buttons[$0] }.sorted { a, b in
            guard case .application(let first) = a.action, case .application(let second) = b.action else { return false }
            return (order[first] ?? Int.max) < (order[second] ?? Int.max)
        }
        for (position, button) in zip(positions, buttons) { layout.buttons[position] = button }
        UserDefaults.standard.set(layout.encoded, forKey: DefaultsKey.notchQuickAccessLayout)
        NotchService.shared.syncWithPreferences()
    }

    func chooseApp() {
        guard chooser == nil else { return }
        let panel = NSOpenPanel()
        panel.title = "Add App or Game"
        panel.message = "Choose one Mac app or CrossOver launcher. CrossOver launchers are usually in your user Applications/CrossOver folder."
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        panel.prompt = "Add"
        chooser = panel
        isChoosing = true
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self, weak panel] response in
            guard let self, let panel else { return }
            self.chooser = nil
            self.isChoosing = false
            if response == .OK, let url = panel.url { self.add(url) }
        }
    }

    func launch(_ entry: IslandLauncherEntry) {
        guard let url = resolvedURL(entry) else { showError("This app has moved or was removed. Remove its launcher entry, then add it again."); return }
        // Open the exact .app wrapper; CrossOver itself owns its bottle and command.
        // Never interpolate a game name/path into a shell command.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            if let error { DispatchQueue.main.async { self?.showError("Could not open \(entry.name): " + error.localizedDescription) } }
        }
    }

    private func save() {
        entries = IslandLauncherSupport.sanitized(entries)
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.notchLauncherEntries)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "App shortcuts"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
