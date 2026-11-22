// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author: Larry Kuhns 2011
//
// Port of `src/stavesection.ts` (VexFlow 5.0.0).

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

    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let ctx = try stave.checkContext()
        setRendered()

        x = stave.getX() + stave.getModifierXShift(getPosition().rawValue)
        let headroom = -1 * textMetrics.actualBoundingBoxDescent
        let width = self.width + 2 * padding // add left & right padding
        let height = self.height + 2 * padding // add top & bottom padding

        //  Seems to be a good default y
        let y = stave.getYForTopText(1.5) + yShift
        let x = self.x + xShift
        if drawRect {
            ctx.beginPath()
            ctx.rect(x, y - height + headroom, width, height)
            ctx.stroke()
        }
        renderText(ctx, xPos: xShift + padding, yPos: y - padding)
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
