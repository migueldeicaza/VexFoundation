// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - TabStave

/// A tablature stave with default 6 lines and wider line spacing.
public final class TabStave: Stave {

    override public class var category: String { "TabStave" }

    // MARK: - Init

    public override init(x: Double, y: Double, width: Double, options: StaveOptions? = nil) {
        var tabOptions = options ?? StaveOptions()
        if let options {
            // JS options objects can omit spacing while overriding other fields.
            // Track explicit Swift mutations so an intentional 10px override is honored.
            tabOptions.spacingBetweenLinesPx = !options.spacingBetweenLinesPxWasSpecified
                ? 13
                : options.spacingBetweenLinesPx
        } else {
            tabOptions.spacingBetweenLinesPx = 13
        }
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
        _ = addClef(.tab)
        return self
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TabStave", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let ts = f.TabStave(x: 10, y: 20, width: 490)
        _ = ts.addTabGlyph()

        try? f.draw()
    }
    .padding()
}
#endif
