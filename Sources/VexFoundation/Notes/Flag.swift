// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/flag.ts` (VexFlow 5.1.0).

import Foundation

/// A note flag. Flags are typically not manipulated directly, but used
/// internally in `StemmableNote` (`StaveNote`, `TabNote`).
///
/// The flag glyph is the element `text`. `x` and `y` give the position.
public final class Flag: VexElement {

    override public class var category: String { "Flag" }

    /// Draw the flag.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        _ = ctx.openGroup(groupClass("flag"), getAttribute("id"))
        renderText(ctx, xPos: 0, yPos: 0)
        drawPointerRect()
        ctx.closeGroup()
    }
}
