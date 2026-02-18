// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - TabTie

/// Implements ties between contiguous tab notes including regular ties,
/// hammer ons, pull offs, and slides.
open class TabTie: StaveTie {

    override open class var CATEGORY: String { "TabTie" }

    // MARK: - Factory Methods

    public static func createHammeron(notes: TieNotes) -> TabTie {
        TabTie(notes: notes, text: "H")
    }

    public static func createPulloff(notes: TieNotes) -> TabTie {
        TabTie(notes: notes, text: "P")
    }

    // MARK: - Init

    public override init(notes: TieNotes, text: String? = nil) {
        super.init(notes: notes, text: text)
        renderOptions.cp1 = 9
        renderOptions.cp2 = 11
        renderOptions.yShift = 3
        direction = -1  // Tab ties are always face up
    }
}
