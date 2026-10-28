// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func render(_ pixels: Int, template: Bool, height: Int? = nil) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: height ?? pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let p = CGFloat(pixels)
    if !template {
        NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.15, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: p * 0.04, y: p * 0.04, width: p * 0.92, height: p * 0.92),
                     xRadius: p * 0.22, yRadius: p * 0.22).fill()
    }
    (template ? NSColor.black : NSColor.systemMint).setStroke()
    let path = NSBezierPath()
    path.lineWidth = p * 0.075
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    path.move(to: NSPoint(x: p * 0.17, y: p * 0.4))
    for (x,y): (CGFloat, CGFloat) in [(0.3,0.4),(0.4,0.7),(0.55,0.24),(0.68,0.57),(0.76,0.4),(0.84,0.4)] {
        path.line(to: NSPoint(x: p * x, y: p * y))
    }
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for size in [16,32,128,256,512] {
    try render(size, template: false).write(to: directory.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2, template: false).write(to: directory.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let base = directory.deletingLastPathComponent()
try render(26, template: true, height: 20).write(to: base.appendingPathComponent("MenuBarIcon.png"))
try render(52, template: true, height: 40).write(to: base.appendingPathComponent("MenuBarIcon@2x.png"))
try render(128, template: true).write(to: base.appendingPathComponent("BrandMark.png"))
// Write the standard PNG-backed ICNS chunks directly, as the upstream builder
// does; iconutil rejects otherwise valid iconsets on this macOS installation.
func uint32(_ value: Int) -> Data {
    var be = UInt32(value).bigEndian
    return withUnsafeBytes(of: &be) { Data($0) }
}
var entries = Data()
for (type, pixels) in [("ic11",32),("ic12",64),("ic07",128),("ic13",256),("ic14",512),("ic10",1024)] {
    let png = render(pixels, template: false)
    entries.append(Data(type.utf8))
    entries.append(uint32(8 + png.count))
    entries.append(png)
}
var icon = Data("icns".utf8)
icon.append(uint32(8 + entries.count))
icon.append(entries)
try icon.write(to: base.appendingPathComponent("AppIcon.icns"))
