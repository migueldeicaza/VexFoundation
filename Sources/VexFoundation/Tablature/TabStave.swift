// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - TabStave

/// A tablature stave with default 6 lines and wider line spacing.
public final class TabStave: Stave {

    override public class var CATEGORY: String { "TabStave" }

    // MARK: - Init

    public override init(x: Double, y: Double, width: Double, options: StaveOptions? = nil) {
        var tabOptions = options ?? StaveOptions()
        tabOptions.spacingBetweenLinesPx = options?.spacingBetweenLinesPx ?? 13
        tabOptions.numLines = options?.numLines ?? 6
        tabOptions.topTextPosition = options?.topTextPosition ?? 1
        super.init(x: x, y: y, width: width, options: tabOptions)
    }

    // MARK: - Glyph Position

    override public func getYForGlyphs() -> Double {
        getYForLine(2.5)
    }

    // MARK: - Deprecated

    @discardableResult
    public func addTabGlyph() -> Self {
        _ = addClef("tab")
        return self
    }
}
