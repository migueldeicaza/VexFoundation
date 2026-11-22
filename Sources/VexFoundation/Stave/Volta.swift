// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author: Larry Kuhns 2011
//
// Port of `src/stavevolta.ts` (VexFlow 5.0.0).

import Foundation

/// Types of volta brackets.
public enum VoltaType: Int, Sendable {
    case none = 1
    case begin = 2
    case mid = 3
    case end = 4
    case beginEnd = 5

    /// Parse from VexFlow-compatible volta labels.
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "none":
            self = .none
        case "begin", "start":
            self = .begin
        case "mid", "middle":
            self = .mid
        case "end":
            self = .end
        case "beginend", "begin_end", "startend":
            self = .beginEnd
        default:
            return nil
        }
    }
}

/// Renders volta brackets (1st/2nd endings) above a stave.
public final class Volta: StaveModifier {

    override public class var category: String { "Volta" }

    // MARK: - Properties

    public var type: VoltaType

    // MARK: - Init

    public init(type: VoltaType, number label: String, x: Double, yShift: Double) {
        self.type = type
        super.init()

        self.x = x
        self.yShift = yShift
        text = label
    }

    // MARK: - Deprecated 4.x API

    @available(*, deprecated, renamed: "type")
    public var voltaType: VoltaType {
        get { type }
        set { type = newValue }
    }

    @available(*, deprecated, message: "Use text / getText().")
    public var number: String { getText() }

    @available(*, deprecated, renamed: "setYShift(_:)")
    @discardableResult
    public func setShiftY(_ y: Double) -> Self { setYShift(y) }

    // MARK: - Draw

    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let x = stave.getModifierXShift(getPosition().rawValue)
        let ctx = try stave.checkContext()
        setRendered()

        var width = stave.getWidth() - x // don't include x (offset) for width
        let topY = stave.getYForTopText(Double(stave.getNumLines())) + yShift
        let vertHeight = 1.5 * stave.getSpacingBetweenLines()
        switch type {
        case .begin:
            ctx.fillRect(self.x + x, topY, 1, vertHeight)
        case .end:
            width -= 5
            ctx.fillRect(self.x + x + width, topY, 1, vertHeight)
        case .beginEnd:
            width -= 3
            ctx.fillRect(self.x + x, topY, 1, vertHeight)
            ctx.fillRect(self.x + x + width, topY, 1, vertHeight)
        default:
            break
        }
        // If the beginning of a volta, draw measure number
        if type == .begin || type == .beginEnd {
            renderText(ctx, xPos: x + 5, yPos: topY - yShift + 15)
        }

        ctx.fillRect(self.x + x, topY, width, 1)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Volta", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 140) { ctx in
        ctx.clear()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 30, width: 240)
        _ = s1.addModifier(Volta(type: .begin, number: "1.", x: 0, yShift: -5))

        let s2 = f.Stave(x: 260, y: 30, width: 240)
        _ = s2.addModifier(Volta(type: .beginEnd, number: "2.", x: 0, yShift: -5))

        try? f.draw()
    }
    .padding()
}
#endif
