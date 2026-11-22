// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author: Larry Kuhns 2011
//
// Port of `src/staverepetition.ts` (VexFlow 5.0.0). Upstream class name: `Repetition`.

import Foundation

/// Types of repetition markers.
public enum RepetitionType: Int, Sendable {
    case none = 1
    case codaLeft = 2
    case codaRight = 3
    case segnoLeft = 4
    case segnoRight = 5
    case dc = 6
    case dcAlCoda = 7
    case dcAlFine = 8
    case ds = 9
    case dsAlCoda = 10
    case dsAlFine = 11
    case fine = 12
    case toCoda = 13

    /// Parse from VexFlow-compatible repetition labels.
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "none":
            self = .none
        case "codaleft", "coda_left":
            self = .codaLeft
        case "codaright", "coda_right":
            self = .codaRight
        case "segnoleft", "segno_left":
            self = .segnoLeft
        case "segnoright", "segno_right":
            self = .segnoRight
        case "dc", "d.c.":
            self = .dc
        case "dcalcoda", "dc_al_coda", "d.c.alcoda":
            self = .dcAlCoda
        case "dcalfine", "dc_al_fine", "d.c.alfine":
            self = .dcAlFine
        case "ds", "d.s.":
            self = .ds
        case "dsalcoda", "ds_al_coda", "d.s.alcoda":
            self = .dsAlCoda
        case "dsalfine", "ds_al_fine", "d.s.alfine":
            self = .dsAlFine
        case "fine":
            self = .fine
        case "tocoda", "to_coda":
            self = .toCoda
        default:
            return nil
        }
    }
}

/// Renders repetition markers (Coda, Segno, D.C., D.S., Fine, etc.) on a stave.
public final class StaveRepetition: StaveModifier {

    override public class var category: String { "Repetition" }

    // MARK: - Properties

    public var symbolType: RepetitionType

    // MARK: - Init

    public init(type: RepetitionType, x: Double, yShift: Double) {
        self.symbolType = type
        super.init()

        self.x = x
        self.xShift = 0
        self.yShift = yShift
    }

    @discardableResult
    public func setShiftX(_ x: Double) -> Self {
        xShift = x
        return self
    }

    @discardableResult
    public func setShiftY(_ y: Double) -> Self {
        yShift = y
        return self
    }

    // MARK: - Draw

    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let x = stave.getModifierXShift(getPosition().rawValue)
        setRendered()

        switch symbolType {
        case .codaRight:
            try drawCodaFixed(stave, x + stave.getWidth())
        case .codaLeft:
            try drawSymbolText(stave, x, "Coda", true)
        case .segnoLeft:
            try drawSegnoFixed(stave, x)
        case .segnoRight:
            try drawSegnoFixed(stave, x + stave.getWidth())
        case .dc:
            try drawSymbolText(stave, x, "D.C.", false)
        case .dcAlCoda:
            try drawSymbolText(stave, x, "D.C. al", true)
        case .dcAlFine:
            try drawSymbolText(stave, x, "D.C. al Fine", false)
        case .ds:
            try drawSymbolText(stave, x, "D.S.", false)
        case .dsAlCoda:
            try drawSymbolText(stave, x, "D.S. al", true)
        case .dsAlFine:
            try drawSymbolText(stave, x, "D.S. al Fine", false)
        case .fine:
            try drawSymbolText(stave, x, "Fine", false)
        case .toCoda:
            try drawSymbolText(stave, x, "To", true)
        case .none:
            break
        }
    }

    // MARK: - Drawing Helpers

    @discardableResult
    public func drawCodaFixed(_ stave: Stave, _ x: Double) throws -> Self {
        let y = stave.getYForTopText(Double(stave.getNumLines()))
        text = Glyphs.coda
        renderText(try stave.checkContext(), xPos: x, yPos: y + Metrics.getDouble("Repetition.coda.offsetY"))
        return self
    }

    @discardableResult
    public func drawSegnoFixed(_ stave: Stave, _ x: Double) throws -> Self {
        let y = stave.getYForTopText(Double(stave.getNumLines()))
        text = Glyphs.segno
        renderText(try stave.checkContext(), xPos: x, yPos: y + Metrics.getDouble("Repetition.segno.offsetY"))
        return self
    }

    @discardableResult
    public func drawSymbolText(_ stave: Stave, _ x: Double, _ text: String, _ drawCoda: Bool) throws -> Self {
        let ctx = try stave.checkContext()
        var textX: Double = 0

        self.text = text
        if drawCoda {
            self.text += " \u{E048}" /*coda*/
        }
        setFont(Metrics.getFontInfo("Repetition.text"))
        switch symbolType {
        // To the left
        case .codaLeft:
            // Offset Coda text to right of stave beginning
            textX = stave.getVerticalBarWidth()
        // To the right
        default:
            textX = x - (stave.getNoteStartX() - self.x) + stave.getWidth() - width
                - Metrics.getDouble("Repetition.text.offsetX")
        }

        let y = stave.getYForTopText(Double(stave.getNumLines())) + Metrics.getDouble("Repetition.text.offsetY")

        renderText(ctx, xPos: textX, yPos: y)

        return self
    }
}

/// Upstream class name.
public typealias Repetition = StaveRepetition

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveRepetition", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 20, width: 240)
        _ = s1.addEndModifier(StaveRepetition(type: .codaRight, x: 0, yShift: 0))

        let s2 = f.Stave(x: 260, y: 20, width: 240)
        _ = s2.addModifier(StaveRepetition(type: .segnoLeft, x: 0, yShift: 0), position: .begin)

        try? f.draw()
    }
    .padding()
}
#endif
