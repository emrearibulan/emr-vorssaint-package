// SPDX-License-Identifier: GPL-3.0-or-later
// emr package additions, 2026.
import AppKit
import SwiftUI

/// User-supplied emr wordmark across an outlined triangle. The source PNG has
/// real alpha; a template makes the original silhouette visible in either theme.
enum EmrFeatureLabel {
    static let mark: NSImage = {
        guard let url = Bundle.main.url(forResource: "EmrFeatureMark", withExtension: "png"),
              let source = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "triangle", accessibilityDescription: nil)!
        }
        // Display the alpha bounds of the 1254px source, omitting outer padding.
        // AppKit uses a bottom-left origin. The original asset stays untouched.
        let crop = NSRect(x: 97, y: 201, width: 1058, height: 899)
        let image = NSImage(size: NSSize(width: 20, height: 20 * crop.height / crop.width), flipped: false) { rect in
            source.draw(in: rect, from: crop, operation: .sourceOver, fraction: 1,
                        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            return true
        }
        image.isTemplate = true
        return image
    }()

    /// Only top-level feature titles get the mark. Keep searchable and spoken
    /// names plain; individual apps, controls and dialog titles are unbranded.
    @ViewBuilder static func topLevel(_ name: String, branded: Bool = true, markSize: CGFloat = 20) -> some View {
        if branded {
            HStack(spacing: 5) {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
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
        return self == .system
    }

    func featureTitle(_ language: AppLanguage, markSize: CGFloat = 20) -> some View {
        EmrFeatureLabel.topLevel(title(language), branded: isEmrFeature, markSize: markSize)
    }
}
