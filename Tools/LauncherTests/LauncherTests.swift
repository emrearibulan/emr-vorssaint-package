import Foundation

@main
struct LauncherTests {
    static func main() throws {
        var checks = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message)
            checks += 1
        }
        let entry = IslandLauncherEntry(name: "Steam", path: "/Users/test/Applications/CrossOver/Steam/Steam.app", bookmark: Data([1, 2]))
        check(IslandLauncherSupport.decode(try JSONEncoder().encode([entry])) == [entry], "saved identities and bookmark data round-trip")
        let samePath = IslandLauncherEntry(name: "Duplicate", path: "/Users/test/Applications/CrossOver/Steam/../Steam/Steam.app")
        check(IslandLauncherSupport.sanitized([entry, samePath]).count == 1, "normalised duplicate paths do not create extra launchers")
        let sameID = IslandLauncherEntry(id: entry.id, name: "Other", path: "/Applications/Other.app")
        check(IslandLauncherSupport.sanitized([entry, sameID]).count == 1, "duplicate row IDs are rejected")
        check(IslandLauncherSupport.sanitized([IslandLauncherEntry(name: "bad", path: "relative.app")]).isEmpty, "relative paths rejected")
        check(IslandLauncherSupport.sanitized([IslandLauncherEntry(name: "bad", path: "/tmp/run.sh")]).isEmpty, "arbitrary executable scripts are not app entries")
        check(IslandLauncherSupport.decode(Data("broken".utf8)).isEmpty, "malformed preferences are safe")
        check(IslandLauncherSupport.decode(Data(repeating: 0, count: 1_048_577)).isEmpty, "oversized preferences are bounded")
        check(IslandLauncherSupport.sanitized([IslandLauncherEntry(name: "bad", path: "/Applications/Test.app", bookmark: Data(repeating: 0, count: 65_537))]).isEmpty, "oversized bookmarks rejected")
        let many = (0..<130).map { IslandLauncherEntry(name: "App \($0)", path: "/Applications/App\($0).app") }
        check(IslandLauncherSupport.sanitized(many).count == 100, "list capacity bounded")
        let clean = IslandLauncherSupport.sanitized([IslandLauncherEntry(name: "\nGame\tName\r", path: "/Applications/Game.app")])[0]
        check(clean.name == "GameName", "control characters removed from menu names")
        let empty = IslandLauncherSupport.sanitized([IslandLauncherEntry(name: "  ", path: "/Applications/Some Game.app")])[0]
        check(empty.name == "Some Game", "empty names fall back to app name")
        let spaces = IslandLauncherEntry(name: "Everything is Crab 🦀", path: "/Users/test/Applications/CrossOver/Steam/Everything is Crab.app")
        check(IslandLauncherSupport.decode(try JSONEncoder().encode([spaces])) == [spaces], "spaces and Unicode preserved without shell escaping")
        print("PASS: \(checks) launcher persistence and validation checks")
    }
}
