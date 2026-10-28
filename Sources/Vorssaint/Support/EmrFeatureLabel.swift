// SPDX-License-Identifier: GPL-3.0-or-later
// emr package additions, 2026.
import AppKit
import SwiftUI

/// The small, monochrome package mark: e above m r, with no enclosing border.
/// Drawing at the requested resolution keeps the native template crisp on Retina.
enum EmrFeatureLabel {
    static let mark: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor.black
            ]
            for (letter, x, y): (String, CGFloat, CGFloat) in [("e", 9, 8), ("m", 4.5, 0), ("r", 13.5, 0)] {
                let glyph = letter as NSString
                let width = glyph.size(withAttributes: attributes).width
                glyph.draw(at: NSPoint(x: x - width / 2, y: y), withAttributes: attributes)
            }
            return true
        }
        image.isTemplate = true
        return image
    }()

    /// Only top-level feature titles get the mark. Keep searchable and spoken
    /// names plain; individual apps, controls and dialog titles are unbranded.
    @ViewBuilder static func topLevel(_ name: String, branded: Bool = true, markSize: CGFloat = 16) -> some View {
        if branded {
            HStack(spacing: 5) {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: markSize, height: markSize)
                    .accessibilityHidden(true)
                Text(name)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(name)
        } else {
            Text(name)
        }
    }
}

extension NotchModule {
    var isEmrFeature: Bool {
        #if ISLAND_MONITOR_LOCAL
        return self == .system
        #else
        return false
        #endif
    }

    func featureTitle(_ language: AppLanguage, markSize: CGFloat = 16) -> some View {
        EmrFeatureLabel.topLevel(title(language), branded: isEmrFeature, markSize: markSize)
    }
}
