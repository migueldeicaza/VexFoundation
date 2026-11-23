// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author: Larry Kuhns 2011
//
// Port of `src/stavesection.ts` (VexFlow 5.6.0).
// Draw rehearsal lettering and its optional frame from the same positioned text.

import Foundation

/// Renders section labels (e.g. "A", "B", "Coda") on a stave.
public final class StaveSection: StaveModifier {

    override public class var category: String { "StaveSection" }

    // MARK: - Properties

    public var drawRect: Bool

    // MARK: - Init

    public init(section: String, x: Double = 0, shiftY yShift: Double = 0, drawRect: Bool = true) {
        self.drawRect = drawRect
        super.init()

        setText(section)
        self.x = x
        self.yShift = yShift
        self.drawRect = drawRect
        padding = Metrics.getDouble("StaveSection.padding")
    }

    @discardableResult
    public func setDrawRect(_ drawRect: Bool) -> Self {
        self.drawRect = drawRect
        return self
    }

    // MARK: - Deprecated 4.x API

    @available(*, deprecated, message: "Use text / getText().")
    public var section: String { getText() }

    @available(*, deprecated, renamed: "setText(_:)")
    @discardableResult
    public func setStaveSection(_ section: String) -> Self { setText(section) }

    @available(*, deprecated, renamed: "setXShift(_:)")
    @discardableResult
    public func setShiftX(_ x: Double) -> Self { setXShift(x) }

    @available(*, deprecated, renamed: "setYShift(_:)")
    @discardableResult
    public func setShiftY(_ y: Double) -> Self { setYShift(y) }

    // MARK: - Draw

    /// Report the same ink and padding before drawing as after a stave has moved. (VexFlow 5.6.0)
    override public func getBoundingBox() -> BoundingBox? {
        if let stave {
            x = stave.getX() + stave.getModifierXShift(getPosition().rawValue) + padding
            y = stave.getYForTopText(1.5) - padding
        }
        let ink = getTextInk(x, y)
        if !drawRect { return ink }
        return BoundingBox(
            x: ink.x - padding,
            y: ink.y - padding,
            w: ink.w + 2 * padding,
            h: ink.h + 2 * padding
        )
    }

    override public func draw() throws {
        let ctx = try checkStaveThrowing().checkContext()
        let bounds = getBoundingBox() ?? BoundingBox(x: x, y: y, w: 0, h: 0)
        setRendered()
        if drawRect {
            ctx.beginPath()
            ctx.rect(bounds.x, bounds.y, bounds.w, bounds.h)
            ctx.stroke()
        }
        renderText(ctx, xPos: 0, yPos: 0)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveSection", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 140) { ctx in
        ctx.clear()

        let f = Factory()
        _ = f.setContext(ctx)

        let s = f.Stave(x: 10, y: 30, width: 490)
        _ = s.addClef(.treble)
        _ = s.addModifier(StaveSection(section: "A", x: 0, shiftY: 5))

        try? f.draw()
    }
    .padding()
}
#endif
