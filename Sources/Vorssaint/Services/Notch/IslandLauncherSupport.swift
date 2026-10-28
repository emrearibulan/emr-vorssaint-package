// SPDX-License-Identifier: GPL-3.0-or-later
// emr package additions, 2026.
import Foundation

struct IslandLauncherEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var path: String
    var bookmark: Data

    init(id: UUID = UUID(), name: String, path: String, bookmark: Data = Data()) {
        self.id = id
        self.name = name
        self.path = path
        self.bookmark = bookmark
    }
}

enum IslandLauncherSupport {
    static let maximumItems = 100

    static func sanitized(_ entries: [IslandLauncherEntry]) -> [IslandLauncherEntry] {
        var ids = Set<UUID>()
        var paths = Set<String>()
        return entries.prefix(500).compactMap { item in
            let url = URL(fileURLWithPath: item.path).standardizedFileURL
            guard item.path.hasPrefix("/"), url.pathExtension.lowercased() == "app",
                  item.bookmark.count <= 65_536, ids.insert(item.id).inserted,
                  paths.insert(url.path).inserted, paths.count <= maximumItems else { return nil }
            var item = item
            item.path = url.path
            item.name = String(item.name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
                .map(String.init).joined().trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
            if item.name.isEmpty { item.name = url.deletingPathExtension().lastPathComponent }
            return item
        }
    }

    static func decode(_ data: Data) -> [IslandLauncherEntry] {
        guard data.count <= 1_048_576,
              let entries = try? JSONDecoder().decode([IslandLauncherEntry].self, from: data) else { return [] }
        return sanitized(entries)
    }
}
