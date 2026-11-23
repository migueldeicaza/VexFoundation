// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Cyril Silverman
//
// Port of `src/ornament.ts` (VexFlow 5.1.0). The 4.x delayed-draw fixes
// (b184399c, 7856e88a, 7ca08666) are part of 5.0.0.

import Foundation

/// Render options for `Ornament`.
public struct OrnamentRenderOptions {
    public var accidentalUpperPadding: Double
    public var accidentalLowerPadding: Double

    public init(accidentalUpperPadding: Double = 3, accidentalLowerPadding: Double = 3) {
        self.accidentalUpperPadding = accidentalUpperPadding
        self.accidentalLowerPadding = accidentalLowerPadding
    }
}

// MARK: - Ornament

/// Ornament implements ornaments as modifiers that can be attached to notes.
/// The complete list of ornaments is available in `Tables.ornamentCodes`.
public final class Ornament: Modifier {

    override public class var category: String { "Ornament" }

    public static var minPadding: Double {
        Metrics.getDouble("NoteHead.minPadding")
    }

    // MARK: - Ornament Type Lists

    /// ornamentNoteTransition means the jazz ornament represents an effect from one note to another,
    /// these are generally on the top of the staff.
    public static let ornamentNoteTransition = ["flip", "jazzTurn", "smear"]

    /// ornamentAttack indicates something that happens in the attach, placed before the note and
    /// any accidentals.
    public static let ornamentAttack = ["scoop"]

    /// The ornament is aligned based on the note head, but without regard to whether the
    /// stem goes up or down.
    public static let ornamentAlignWithNoteHead = ["doit", "fall", "fallLong", "doitLong", "scoop"]

    /// An ornament that happens on the release of the note, generally placed after the
    /// note and overlapping the next beat/measure.
    public static let ornamentRelease = ["doit", "fall", "fallLong", "doitLong", "jazzTurn", "smear", "flip"]

    public static let ornamentLeft = ["scoop"]

    public static let ornamentRight = ["doit", "fall", "fallLong", "doitLong"]

    public static let ornamentYShift = ["fallLong"]

    /// ornamentArticulation goes above/below the note based on space availability.
    public static let ornamentArticulation = ["bend", "plungerClosed", "plungerOpen"]

    @available(*, deprecated, renamed: "ornamentNoteTransition")
    public static var noteTransitionTypes: [String] { ornamentNoteTransition }
    @available(*, deprecated, renamed: "ornamentAttack")
    public static var attackTypes: [String] { ornamentAttack }
    @available(*, deprecated, renamed: "ornamentAlignWithNoteHead")
    public static var alignWithNoteHeadTypes: [String] { ornamentAlignWithNoteHead }
    @available(*, deprecated, renamed: "ornamentRelease")
    public static var releaseTypes: [String] { ornamentRelease }
    @available(*, deprecated, renamed: "ornamentArticulation")
    public static var articulationTypes: [String] { ornamentArticulation }

    // MARK: - Properties

    public let type: String
    public var delayed: Bool
    /// Some jazz ornaments are above or below depending on stem direction.
    public var adjustForStemDirection: Bool
    public var renderOptions: OrnamentRenderOptions
    private var ornamentAlignWithNoteHead: Bool
    private var accidentalUpper: VexElement?
    private var accidentalLower: VexElement?
    private var delayXShift: Double?

    // MARK: - Static Format

    /// Arrange ornaments inside `ModifierContext`.
    @discardableResult
    public static func format(_ ornaments: [Ornament], state: inout ModifierContextState) -> Bool {
        if ornaments.isEmpty { return false }

        var width: Double = 0 // width is used by ornaments, which are always centered on the note head
        var rightShift = state.rightShift // jazz ornaments calculate r/l shift separately
        var leftShift = state.leftShift

        for ornament in ornaments {
            let increment: Double = 2

            if ornament.position == .right {
                ornament.xShift += rightShift + 2
                rightShift += ornament.width + Ornament.minPadding
            } else if ornament.position == .left {
                ornament.xShift -= leftShift + ornament.width + 2
                leftShift += ornament.width + Ornament.minPadding
            } else if ornament.position == .above {
                width = max(ornament.getWidth(), width)
                let note = ornament.getNote()
                var curTop = note.getLineNumber(isTopNote: true) + state.topTextLine
                if let stem = (note as? StemmableNote)?.getStem(), note.getStemDirection() == Stem.UP {
                    curTop += abs(stem.getHeight()) / Tables.STAVE_LINE_DISTANCE
                }
                let numLines = Double(note.getStave()?.getNumLines() ?? 0)
                // make sure that the ornaments stay above the staff
                if curTop < numLines { state.topTextLine += numLines - curTop }
                _ = ornament.setTextLine(state.topTextLine)
                state.topTextLine += increment
            } else {
                width = max(ornament.getWidth(), width)
                _ = ornament.setTextLine(state.textLine)
                state.textLine += increment
            }
        }

        // Note: 'legit' ornaments don't consider other modifiers when calculating their
        // X position, but jazz ornaments sometimes need to.
        state.leftShift = leftShift + width / 2
        state.rightShift = rightShift + width / 2
        return true
    }

    // MARK: - Init

    /// Create a new ornament of type `type`, which is an entry in
    /// `Tables.ornamentCodes`.
    public init(_ type: String) {
        self.type = type
        delayed = false
        renderOptions = OrnamentRenderOptions(accidentalUpperPadding: 3, accidentalLowerPadding: 3)
        // some jazz ornaments are above or below depending on stem direction.
        adjustForStemDirection = false
        ornamentAlignWithNoteHead = Ornament.ornamentAlignWithNoteHead.contains(type)
        super.init()

        // Default position ABOVE
        position = .above
        if Ornament.ornamentRight.contains(type) {
            position = .right
        }
        if Ornament.ornamentLeft.contains(type) {
            position = .left
        }

        // Is this a jazz ornament that goes between this note and the next note.
        if Ornament.ornamentNoteTransition.contains(type) {
            delayed = true
        }

        text = Tables.ornamentCodes(type)
    }

    // MARK: - Note

    /// Set note attached to ornament.
    @discardableResult
    override public func setNote(_ note: Note) -> Self {
        super.setNote(note)
        // articulations above/below the line can be stacked.
        if Ornament.ornamentArticulation.contains(type) {
            // Unfortunately we don't know the stem direction.  So we base it
            // on the line number, but also allow it to be overridden.
            if note.getLineNumber() >= 3 {
                position = .above
            } else {
                position = .below
            }
        }
        return self
    }

    // MARK: - Delayed

    /// Set whether the ornament is to be delayed.
    @discardableResult
    public func setDelayed(_ delayed: Bool) -> Self {
        self.delayed = delayed
        return self
    }

    // MARK: - Accidentals

    /// Set the upper accidental for the ornament.
    @discardableResult
    public func setUpperAccidental(_ accid: String) -> Self {
        let element = VexElement()
        element.setText(Tables.accidentalCodes(accid))
        accidentalUpper = element
        return self
    }

    /// Set the lower accidental for the ornament.
    @discardableResult
    public func setLowerAccidental(_ accid: String) -> Self {
        let element = VexElement()
        element.setText(Tables.accidentalCodes(accid))
        accidentalLower = element
        return self
    }

    // MARK: - Draw

    /// Render ornament in position next to note.
    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()

        let stave = try note.checkStaveThrowing()

        _ = ctx.openGroup(groupClass("ornament"), getAttribute("id"))

        // Get initial coordinates for the modifier position
        let start = note.getModifierStartXY(position: position, index: index ?? 0)
        var glyphX = start.x

        let staffSpace = stave.getSpacingBetweenLines()
        let initialOffset = getInitialOffset(note, position)

        // If the ornament is aligned with the note head, don't consider the stave y
        // but use the 'natural' modifier y
        var glyphY = ornamentAlignWithNoteHead ? start.y : 0
        if position == .above {
            glyphY = try getTopY(note, textLine) - (textLine + initialOffset) * staffSpace
        }
        if position == .below {
            glyphY = try getBottomY(note, textLine) + (textLine + initialOffset + 1.5) * staffSpace
        }

        // Adjust x position if ornament is delayed
        if delayed {
            var delayXShift: Double = 0
            let startX = note.getTickContext().getX()
            if let cached = self.delayXShift {
                delayXShift = cached
            } else {
                let tickables = note.getVoice().getTickables()
                let nextContext: TickContext?
                if let index = tickables.firstIndex(where: { $0 === note }), index + 1 < tickables.count {
                    nextContext = tickables[index + 1].checkTickContext()
                } else {
                    nextContext = nil
                }
                if let nextContext {
                    delayXShift += (nextContext.getX() - startX) * 0.5
                } else {
                    delayXShift += (stave.getX() + stave.getWidth() - glyphX) * 0.5
                }
                self.delayXShift = delayXShift
            }
            glyphX += delayXShift
        }

        if let accidentalLower {
            accidentalLower.renderText(
                ctx,
                xPos: glyphX + xShift - accidentalLower.getWidth() * 0.5,
                yPos: glyphY + yShift - accidentalLower.getTextMetrics().actualBoundingBoxDescent
            )
            glyphY -= accidentalLower.getHeight() + renderOptions.accidentalLowerPadding
        }

        // ornament requires yShift
        if Ornament.ornamentYShift.contains(type) {
            yShift += getHeight()
        }

        x = glyphX - (position == .above || position == .below ? width * 0.5 : 0)
        y = glyphY

        renderText(ctx, xPos: 0, yPos: 0)

        if let accidentalUpper {
            glyphY -= getHeight() + renderOptions.accidentalUpperPadding
            accidentalUpper.renderText(
                ctx,
                xPos: glyphX + xShift - accidentalUpper.getWidth() * 0.5,
                yPos: glyphY + yShift - accidentalUpper.getTextMetrics().actualBoundingBoxDescent
            )
        }
        drawPointerRect()
        ctx.closeGroup()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ornament", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

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
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
