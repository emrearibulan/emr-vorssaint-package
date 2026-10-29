import Foundation

@main
struct WebsiteIconTests {
    static func main() async throws {
        let base = "http://127.0.0.1:" + CommandLine.arguments[1]
        let icon = await WebsiteIconFetcher.icon(for: URL(string: base + "/private?token=should-not-be-requested")!)
        precondition(icon?.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) == true, "declared icon redirects decode and normalize to PNG after an invalid image")
        precondition(WebsiteIconFetcher.needsLightBackground(icon!), "a dark coloured icon gets light backing")
        let white = await WebsiteIconRequest.fetch(URL(string: base + "/white.png")!, limit: 1024)
        precondition(white.map { !WebsiteIconFetcher.needsLightBackground($0.data) } == true, "white icons get dark backing")
        let large = await WebsiteIconRequest.fetch(URL(string: base + "/large")!, limit: 1024)
        precondition(large == nil, "oversized Content-Length rejected")
        let streamed = await WebsiteIconRequest.fetch(URL(string: base + "/streamed")!, limit: 1024)
        precondition(streamed == nil, "streaming bytes bounded even without Content-Length")
        let missing = await WebsiteIconRequest.fetch(URL(string: base + "/missing")!, limit: 1024)
        precondition(missing == nil, "HTTP errors rejected")
        let loop = await WebsiteIconRequest.fetch(URL(string: base + "/loop")!, limit: 1024)
        precondition(loop == nil, "redirect loops bounded")
        precondition(WebsiteIconFetcher.rasterIcon(Data("<html>error</html>".utf8)) == nil, "HTML is not accepted as an icon")
        print("PASS: 8 website icon fetch/decode/contrast checks")
    }
}
