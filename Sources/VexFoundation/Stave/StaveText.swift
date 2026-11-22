// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author: Taehoon Moon 2014
//
// Port of `src/stavetext.ts` (VexFlow 5.0.0).

import Foundation

/// Text justification for StaveText. Same values as `TextJustification` (TextNote).
public enum StaveTextJustification: Int, Sendable {
    case left = 1
    case center = 2
    case right = 3

    /// Parse from textual labels used by compatibility inputs.
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "left":
            self = .left
        case "center", "centre", "middle":
            self = .center
        case "right":
            self = .right
        default:
            return nil
        }
    }
}

/// Renders text above, below, left, or right of a stave.
public final class StaveText: StaveModifier {

    override public class var category: String { "StaveText" }

    // MARK: - Properties

    public var justification: StaveTextJustification

    // MARK: - Init

    public init(text: String, position: StaveModifierPosition,
                shiftX: Double = 0, shiftY: Double = 0,
                justification: StaveTextJustification = .center) {
        self.justification = justification
        super.init()

        setText(text)
        setXShift(shiftX)
        setYShift(shiftY)
        self.position = position
        self.justification = justification
    }

    // MARK: - Deprecated 4.x API

    @available(*, deprecated, renamed: "setText(_:)")
    @discardableResult
    public func setStaveText(_ text: String) -> Self { setText(text) }

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

        var x: Double
        var y: Double
        switch position {
        case .left, .right:
            y = (stave.getYForLine(0) + stave.getBottomLineY()) / 2
            if position == .left {
                x = stave.getX() - width - 24
            } else {
                x = stave.getX() + stave.getWidth() + 24
            }
        case .above, .below:
            x = stave.getX()
            if justification == .center {
                x += stave.getWidth() / 2 - width / 2
            } else if justification == .right {
                x += stave.getWidth() - width
            }

            if position == .above {
                y = stave.getYForTopText(2)
            } else {
                y = stave.getYForBottomText(2)
            }
        default:
            throw VexError("InvalidPosition", "Value Must be in Modifier.Position.")
        }

        renderText(ctx, xPos: x, yPos: y + 4)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveText", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 140) { ctx in
        ctx.clear()

        let f = Factory()
        _ = f.setContext(ctx)

        let s = f.Stave(x: 10, y: 30, width: 490)
        _ = s.addClef(.treble)
        _ = s.addModifier(StaveText(text: "Allegro", position: .above))

        try? f.draw()
    }
    .padding()
}
#endif
