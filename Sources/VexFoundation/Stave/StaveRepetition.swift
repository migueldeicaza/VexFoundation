// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

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

    override public class var textFont: FontInfo {
        FontInfo(
            family: VexFont.SERIF,
            size: Tables.NOTATION_FONT_SCALE / 3,
            weight: VexFontWeight.bold.rawValue,
            style: VexFontStyle.normal.rawValue
        )
    }

    // MARK: - Properties

    public var symbolType: RepetitionType
    public var repXShift: Double = 0
    public var repYShift: Double

    // MARK: - Init

    public init(type: RepetitionType, x: Double, yShift: Double) {
        self.symbolType = type
        self.repYShift = yShift
        super.init()
        self.modifierX = x
        resetFont()
    }

    @discardableResult
    public func setShiftX(_ x: Double) -> Self {
        repXShift = x
        return self
    }

    @discardableResult
    public func setShiftY(_ y: Double) -> Self {
        repYShift = y
        return self
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        setRendered()

        switch symbolType {
        case .codaLeft:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "Coda", drawCoda: true, yShift: repYShift)
        case .codaRight:
            drawCodaFixed(ctx: ctx, stave: stave, x: stave.getWidth(), yShift: repYShift)
        case .segnoLeft:
            drawSegnoFixed(ctx: ctx, stave: stave, x: xShift, yShift: repYShift)
        case .segnoRight:
            drawSegnoFixed(ctx: ctx, stave: stave, x: stave.getWidth(), yShift: repYShift)
        case .dc:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "D.C.", drawCoda: false, yShift: repYShift)
        case .dcAlCoda:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "D.C. al", drawCoda: true, yShift: repYShift)
        case .dcAlFine:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "D.C. al Fine", drawCoda: false, yShift: repYShift)
        case .ds:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "D.S.", drawCoda: false, yShift: repYShift)
        case .dsAlCoda:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "D.S. al", drawCoda: true, yShift: repYShift)
        case .dsAlFine:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "D.S. al Fine", drawCoda: false, yShift: repYShift)
        case .fine:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "Fine", drawCoda: false, yShift: repYShift)
        case .toCoda:
            drawSymbolText(ctx: ctx, stave: stave, x: xShift, text: "To", drawCoda: true, yShift: repYShift)
        case .none:
            break
        }
    }

    // MARK: - Drawing Helpers

    private func drawCodaFixed(ctx: RenderContext, stave: Stave, x: Double, yShift: Double) {
        let y = stave.getYForTopText(2.5) + yShift
        Glyph.renderGlyph(ctx: ctx, xPos: modifierX + x + repXShift, yPos: y, point: Tables.NOTATION_FONT_SCALE,
                          code: "coda")
    }

    private func drawSegnoFixed(ctx: RenderContext, stave: Stave, x: Double, yShift: Double) {
        let y = stave.getYForTopText(2.5) + yShift
        Glyph.renderGlyph(ctx: ctx, xPos: modifierX + x + repXShift, yPos: y, point: Tables.NOTATION_FONT_SCALE,
                          code: "segno")
    }

    private func drawSymbolText(ctx: RenderContext, stave: Stave, x: Double,
                                text: String, drawCoda: Bool, yShift: Double) {
        let textX = modifierX + x + repXShift
        let y = stave.getYForTopText(2.5) + yShift

        ctx.save()
        ctx.setFont(fontInfo)
        ctx.fillText(text, textX, y + 5)

        if drawCoda {
            let textWidth = ctx.measureText(text).width
            Glyph.renderGlyph(ctx: ctx, xPos: textX + textWidth + 12, yPos: y, point: Tables.NOTATION_FONT_SCALE,
                              code: "coda")
        }
        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveRepetition", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
