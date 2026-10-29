// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

/// The host owns the island; emr supplies this page's content.
struct NotchSystemView: View {
    let size: CGSize
    let select: (MetricDetailKind) -> Void
    let showAgents: () -> Void

    var body: some View {
        EmrSystemView(size: size, select: select, showAgents: showAgents)
    }
}
