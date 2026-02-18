// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Ornament

/// Modifier that renders ornaments (trills, mordents, turns, etc.) on notes.
public final class Ornament: Modifier {

    override public class var category: String { "Ornament" }

    // MARK: - Ornament Type Lists

    /// Ornaments that are rendered between note transitions (delayed).
    public static let noteTransitionTypes = ["flip", "jazzTurn", "smear"]

    /// Ornaments that are attack-type (placed before the note).
    public static let attackTypes = ["scoop"]

    /// Ornaments that align with the note head.
    public static let alignWithNoteHeadTypes = [
        "doit", "fall", "fallLong", "doitLong", "bend",
        "plungerClosed", "plungerOpen", "scoop"
    ]

    /// Ornaments that are release-type (placed after the note).
    public static let releaseTypes = [
        "doit", "fall", "fallLong", "doitLong",
        "jazzTurn", "smear", "flip"
    ]

    /// Ornaments that behave like articulations.
    public static let articulationTypes = ["bend", "plungerClosed", "plungerOpen"]

    // MARK: - Properties

    public let type: String
    public var delayed: Bool = false
    public var adjustForStemDirection: Bool = false
    public var reportedWidth: Double = 0

    private var ornamentGlyph: Glyph
    private var accidentalUpper: Glyph?
    private var accidentalLower: Glyph?

    public var renderOpts = (
        accidentalUpperPadding: 6.0,
        accidentalLowerPadding: 3.0,
        fontScale: Tables.NOTATION_FONT_SCALE
    )

    // MARK: - Init

    public init(_ type: String) {
        self.type = type

        let code = Tables.ornamentCode(type) ?? type
        self.ornamentGlyph = Glyph(code: code, point: Tables.NOTATION_FONT_SCALE)

        // Check if this ornament adjusts for stem direction
        self.adjustForStemDirection = !Ornament.alignWithNoteHeadTypes.contains(type)

        // Delayed ornaments are note transitions
        self.delayed = Ornament.noteTransitionTypes.contains(type)

        super.init()

        // Report width from glyph metrics
        self.reportedWidth = ornamentGlyph.getMetrics().width
        _ = setWidth(reportedWidth)
    }

    // MARK: - Delayed

    @discardableResult
    public func setDelayed(_ delayed: Bool) -> Self {
        self.delayed = delayed
        return self
    }

    // MARK: - Accidentals

    @discardableResult
    public func setUpperAccidental(_ accid: String) -> Self {
        let code = Tables.accidentalCodes[accid]?.code ?? accid
        accidentalUpper = Glyph(code: code, point: renderOpts.fontScale)
        return self
    }

    @discardableResult
    public func setLowerAccidental(_ accid: String) -> Self {
        let code = Tables.accidentalCodes[accid]?.code ?? accid
        accidentalLower = Glyph(code: code, point: renderOpts.fontScale)
        return self
    }

    // MARK: - Static Format

    @discardableResult
    public static func format(_ ornaments: [Ornament], state: inout ModifierContextState) -> Bool {
        if ornaments.isEmpty { return false }

        var leftShift = state.leftShift
        var rightShift = state.rightShift
        var maxWidth: Double = 0

        for ornament in ornaments {
            _ = ornament.checkAttachedNote()
            let isAttack = Ornament.attackTypes.contains(ornament.type)
            let isRelease = Ornament.releaseTypes.contains(ornament.type)

            let width = ornament.getWidth()
            maxWidth = max(width, maxWidth)

            if isAttack {
                leftShift = max(width, leftShift)
            }
            if isRelease {
                rightShift = max(width, rightShift)
            }

            _ = ornament.setXShift(0)
            _ = ornament.setTextLine(state.topTextLine)
            state.topTextLine += 1
        }

        state.leftShift = leftShift
        state.rightShift = rightShift
        return true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
        let stave = note.checkStave()

        // Get starting position
        guard let staveNote = note as? StaveNote else { return }
        let index = checkIndex()
        let start = staveNote.getModifierStartXY(position: position, index: index)

        var glyphX = start.x
        var glyphY = stave.getYForTopText(textLine) - 3

        // Adjust for stem direction
        if adjustForStemDirection {
            if stemDirection == Stem.UP {
                glyphY = min(
                    stave.getYForTopText(textLine) - 3,
                    note.getYs().min() ?? 0
                )
                if note.hasStem() {
                    glyphY = min(glyphY, note.getStemExtents().topY - 8)
                }
            } else {
                glyphY = max(
                    stave.getYForBottomText(textLine),
                    note.getYs().max() ?? 0
                )
                if note.hasStem() {
                    glyphY = max(glyphY, note.getStemExtents().baseY + 8)
                }
            }
        }

        // Delayed ornaments render after the note
        if delayed {
            glyphX += getWidth() + 2
        }

        // Render the ornament glyph
        ornamentGlyph.render(ctx: ctx, x: glyphX, y: glyphY)

        // Render upper accidental
        if let upper = accidentalUpper {
            let upperY = glyphY - ornamentGlyph.getMetrics().height / 2
                - renderOpts.accidentalUpperPadding
            upper.render(ctx: ctx, x: glyphX, y: upperY)
        }

        // Render lower accidental
        if let lower = accidentalLower {
            let lowerY = glyphY + ornamentGlyph.getMetrics().height / 2
                + renderOpts.accidentalLowerPadding
            lower.render(ctx: ctx, x: glyphX, y: lowerY)
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ornament", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(f.Ornament("tr"), index: 0)
        _ = notes[1].addModifier(f.Ornament("mordent"), index: 0)
        _ = notes[2].addModifier(f.Ornament("turn"), index: 0)

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)
            .addTimeSignature("4/4")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
