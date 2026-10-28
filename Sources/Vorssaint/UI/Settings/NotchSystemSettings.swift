// SPDX-License-Identifier: GPL-3.0-or-later
// Local dashboard customizations, 2026.

import SwiftUI

struct NotchSystemSettings: View {
    @AppStorage(DefaultsKey.notchSystemUnknownColor) private var storedColor = "#FFFFFF"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ColorPicker("Colour for readings without capacity", selection: color, supportsOpacity: false)
                .accessibilityIdentifier("dashboard.unknownCapacityColor")
            Text("Used for values such as network speed or power when capacity is unavailable. Changes appear immediately in the dashboard and preview.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reset to white") { storedColor = "#FFFFFF" }
                .disabled(storedColor.uppercased() == "#FFFFFF")
        }
    }

    private var color: Binding<Color> {
        Binding {
            let rgb = MenuBarUsageBarSupport.rgb(for: storedColor, fallback: "#FFFFFF")
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } set: { value in
            guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
            storedColor = MenuBarUsageBarSupport.hex(red: Double(rgb.redComponent),
                                                    green: Double(rgb.greenComponent),
                                                    blue: Double(rgb.blueComponent))
        }
    }
}
