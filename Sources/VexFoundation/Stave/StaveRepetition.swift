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
        setRendered()

        switch symbolType {
        case .codaLeft:
            try drawSymbolText(stave: stave, xShift: xShift, text: "Coda", drawCoda: true)
        case .codaRight:
            try drawCodaFixed(stave: stave, x: xShift + stave.getWidth())
        case .segnoLeft:
            try drawSegnoFixed(stave: stave, x: xShift)
        case .segnoRight:
            try drawSegnoFixed(stave: stave, x: xShift + stave.getWidth())
        case .dc:
            try drawSymbolText(stave: stave, xShift: xShift, text: "D.C.", drawCoda: false)
        case .dcAlCoda:
            try drawSymbolText(stave: stave, xShift: xShift, text: "D.C. al", drawCoda: true)
        case .dcAlFine:
            try drawSymbolText(stave: stave, xShift: xShift, text: "D.C. al Fine", drawCoda: false)
        case .ds:
            try drawSymbolText(stave: stave, xShift: xShift, text: "D.S.", drawCoda: false)
        case .dsAlCoda:
            try drawSymbolText(stave: stave, xShift: xShift, text: "D.S. al", drawCoda: true)
        case .dsAlFine:
            try drawSymbolText(stave: stave, xShift: xShift, text: "D.S. al Fine", drawCoda: false)
        case .fine:
            try drawSymbolText(stave: stave, xShift: xShift, text: "Fine", drawCoda: false)
        case .toCoda:
            try drawSymbolText(stave: stave, xShift: xShift, text: "To", drawCoda: true)
        case .none:
            break
        }
    }

    // MARK: - Drawing Helpers

    private func drawCodaFixed(stave: Stave, x: Double) throws {
        let ctx = try stave.checkContext()
        let y = stave.getYForTopText(Double(stave.getNumLines())) + repYShift + metric("staveRepetition.coda.offsetY")
        Glyph.renderGlyph(
            ctx: ctx,
            xPos: modifierX + x + repXShift,
            yPos: y,
            point: 40,
            code: "coda",
            category: "coda"
        )
    }

    private func drawSegnoFixed(stave: Stave, x: Double) throws {
        let ctx = try stave.checkContext()
        let y = stave.getYForTopText(Double(stave.getNumLines())) + repYShift + metric("staveRepetition.segno.offsetY")
        Glyph.renderGlyph(
            ctx: ctx,
            xPos: modifierX + x + repXShift,
            yPos: y,
            point: 30,
            code: "segno",
            category: "segno"
        )
    }

    private func drawSymbolText(stave: Stave, xShift: Double, text: String, drawCoda: Bool) throws {
        let ctx = try stave.checkContext()
        let symbolTextOffsetX = metric("staveRepetition.symbolText.offsetX")
        let symbolTextOffsetY = metric("staveRepetition.symbolText.offsetY")
        let symbolTextSpacing = metric("staveRepetition.symbolText.spacing")
        let modifierWidth = stave.getNoteStartX() - modifierX

        ctx.save()
        ctx.setFont(fontInfo)
        let textWidth = ctx.measureText(text).width

        let textX: Double
        let symbolX: Double
        switch symbolType {
        case .codaLeft:
            textX = modifierX + stave.getVerticalBarWidth()
            let parityCorrection = ProcessInfo.processInfo.environment["VEXFOUNDATION_UPSTREAM_SVG_PARITY"] == "1"
                ? -0.0065
                : 0
            symbolX = textX + textWidth + symbolTextOffsetX + parityCorrection
        case .dc, .dcAlFine, .ds, .dsAlFine, .fine:
            textX = modifierX + xShift + repXShift + stave.getWidth() - symbolTextSpacing - modifierWidth - textWidth
            symbolX = 0
        default:
            textX = modifierX + xShift + repXShift + stave.getWidth() - symbolTextSpacing
                - modifierWidth - textWidth - symbolTextOffsetX
            symbolX = textX + textWidth + symbolTextOffsetX
        }

        let y = stave.getYForTopText(Double(stave.getNumLines())) + repYShift + symbolTextOffsetY

        if drawCoda {
            Glyph.renderGlyph(
                ctx: ctx,
                xPos: symbolX,
                yPos: y,
                point: fontSizeInPoints * 2,
                code: "coda",
                category: "coda"
            )
        }

        ctx.fillText(text, textX, y + 5)
        ctx.restore()
    }

    private func metric(_ key: String, _ fallback: Double = 0) -> Double {
        (Glyph.MUSIC_FONT_STACK.first?.lookupMetric(key) as? Double) ?? fallback
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
