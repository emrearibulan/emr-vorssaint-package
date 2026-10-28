// SPDX-License-Identifier: GPL-3.0-or-later
// emr package additions, 2026.

/// Use only for the top-level feature entries added by emr.
/// Child controls, app names and dialog titles keep their own labels.
enum EmrFeatureLabel {
    static func topLevel(_ name: String) -> String { name + " -emr" }
}
