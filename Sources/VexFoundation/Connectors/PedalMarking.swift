// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Pedal Marking Type

public enum PedalMarkingType: Int {
    case text = 1
    case bracket = 2
    case mixed = 3
}

// MARK: - Pedal Marking Render Options

public struct PedalMarkingRenderOptions {
    public var color: String = "black"
    public var bracketHeight: Double = 10
    public var textMarginRight: Double = 6
    public var bracketLineWidth: Double = 1

    public init(
        color: String = "black",
        bracketHeight: Double = 10,
        textMarginRight: Double = 6,
        bracketLineWidth: Double = 1
    ) {
        self.color = color
        self.bracketHeight = bracketHeight
        self.textMarginRight = textMarginRight
        self.bracketLineWidth = bracketLineWidth
    }
}

// MARK: - PedalMarking

/// Renders pedal markings (sustain, sostenuto, una corda) below notes.
public final class PedalMarking: VexElement {

    override public class var CATEGORY: String { "PedalMarking" }

    // MARK: - Glyph Data

    public static let GLYPHS: [String: String] = [
        "pedal_depress": "keyboardPedalPed",
        "pedal_release": "keyboardPedalUp",
    ]

    // MARK: - Properties

    public var notes: [StaveNote]
    public var pedalType: PedalMarkingType = .text
    public var pedalLine: Double = 0
    public var customDepressText: String = ""
    public var customReleaseText: String = ""
    public var pedalRenderOptions = PedalMarkingRenderOptions()

    // MARK: - Init

    public init(notes: [StaveNote]) {
        self.notes = notes
        super.init()
    }

    // MARK: - Factory Methods

    public static func createSustain(notes: [StaveNote]) -> PedalMarking {
        PedalMarking(notes: notes)
    }

    public static func createSostenuto(notes: [StaveNote]) -> PedalMarking {
        let pedal = PedalMarking(notes: notes)
        _ = pedal.setType(.mixed)
        _ = pedal.setCustomText("Sost. Ped.")
        return pedal
    }

    public static func createUnaCorda(notes: [StaveNote]) -> PedalMarking {
        let pedal = PedalMarking(notes: notes)
        _ = pedal.setType(.text)
        _ = pedal.setCustomText("una corda", release: "tre corda")
        return pedal
    }

    // MARK: - Setters

    @discardableResult
    public func setType(_ type: PedalMarkingType) -> Self {
        pedalType = type
        return self
    }

    @discardableResult
    public func setCustomText(_ depress: String, release: String = "") -> Self {
        customDepressText = depress
        customReleaseText = release
        return self
    }

    @discardableResult
    public func setLine(_ line: Double) -> Self {
        pedalLine = line
        return self
    }

    // MARK: - Draw Pedal Glyph

    private func drawPedalGlyph(
        name: String,
        ctx: any RenderContext,
        x: Double,
        y: Double,
        point: Double
    ) {
        guard let code = PedalMarking.GLYPHS[name] else { return }
        let glyph = Glyph(code: code, point: point)
        let glyphWidth = glyph.getMetrics().width
        glyph.render(ctx: ctx, x: x - (glyphWidth - Tables.STAVE_LINE_DISTANCE) / 2, y: y)
    }

    // MARK: - Draw Bracketed

    private func drawBracketed() throws {
        let ctx = try checkContext()
        var isPedalDepressed = false
        var prevX: Double = 0
        var prevY: Double = 0

        for (index, note) in notes.enumerated() {
            isPedalDepressed = !isPedalDepressed

            let x = note.getAbsoluteX()
            let y = note.checkStave().getYForBottomText(pedalLine + 3)

            let nextIsSame = index + 1 < notes.count && notes[index + 1] === note
            let prevIsSame = index > 0 && notes[index - 1] === note

            let point = Tables.NOTATION_FONT_SCALE

            var xShift: Double = 0

            if isPedalDepressed {
                xShift = prevIsSame ? 5 : 0

                if pedalType == .mixed && !prevIsSame {
                    if !customDepressText.isEmpty {
                        let textWidth = ctx.measureText(customDepressText).width
                        _ = ctx.fillText(customDepressText, x - textWidth / 2, y)
                        xShift = textWidth / 2 + pedalRenderOptions.textMarginRight
                    } else {
                        drawPedalGlyph(name: "pedal_depress", ctx: ctx, x: x, y: y, point: point)
                        xShift = 20 + pedalRenderOptions.textMarginRight
                    }
                } else {
                    ctx.beginPath()
                    ctx.moveTo(x, y - pedalRenderOptions.bracketHeight)
                    ctx.lineTo(x + xShift, y)
                    ctx.stroke()
                    ctx.closePath()
                }
            } else {
                xShift = nextIsSame ? -5 : 0

                ctx.beginPath()
                ctx.moveTo(prevX, prevY)
                ctx.lineTo(x + xShift, y)
                ctx.lineTo(x, y - pedalRenderOptions.bracketHeight)
                ctx.stroke()
                ctx.closePath()
            }

            prevX = x + xShift
            prevY = y
        }
    }

    // MARK: - Draw Text

    private func drawText() throws {
        let ctx = try checkContext()
        var isPedalDepressed = false

        for note in notes {
            isPedalDepressed = !isPedalDepressed

            let x = note.getAbsoluteX()
            let stave = note.checkStave()
            let y = stave.getYForBottomText(pedalLine + 3)

            let point = Tables.NOTATION_FONT_SCALE

            if isPedalDepressed {
                if !customDepressText.isEmpty {
                    let textWidth = ctx.measureText(customDepressText).width
                    _ = ctx.fillText(customDepressText, x - textWidth / 2, y)
                } else {
                    drawPedalGlyph(name: "pedal_depress", ctx: ctx, x: x, y: y, point: point)
                }
            } else {
                if !customReleaseText.isEmpty {
                    let textWidth = ctx.measureText(customReleaseText).width
                    _ = ctx.fillText(customReleaseText, x - textWidth / 2, y)
                } else {
                    drawPedalGlyph(name: "pedal_release", ctx: ctx, x: x, y: y, point: point)
                }
            }
        }
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        ctx.save()
        _ = ctx.setStrokeStyle(pedalRenderOptions.color)
        _ = ctx.setFillStyle(pedalRenderOptions.color)
        ctx.setFont(getFont())

        if pedalType == .bracket || pedalType == .mixed {
            _ = ctx.setLineWidth(pedalRenderOptions.bracketLineWidth)
            try drawBracketed()
        } else {
            try drawText()
        }

        ctx.restore()
    }
}
