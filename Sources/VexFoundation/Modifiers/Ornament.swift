// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Cyril Silverman
//
// Port of `src/ornament.ts` (VexFlow 5.8.0). The 4.x delayed-draw fixes
// (b184399c, 7856e88a, 7ca08666) are part of 5.0.0.
// Places ornaments, editorial parentheses, accidentals and written trill partners on their principal notes.

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
    /// Separate glyphs preserve the identity and alignment of the enclosed ornament. (VexFlow 5.8.0)
    private var parentheses: (left: VexElement, right: VexElement)?
    /// A written, untimed trill partner. Its column follows earlier right-hand modifiers. (VexFlow 5.8.0)
    private var auxiliary: (pitch: String, glyph: VexElement, headOffset: Double, headWidth: Double)?
    private var auxiliaryOffset: Double = 0
    /// Side spacing is recomputed per format and is independent of authored shifts. (VexFlow 5.3.0)
    private var sideOffset: Double = 0

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

            ornament.sideOffset = 0
            if let auxiliary = ornament.auxiliary {
                ornament.auxiliaryOffset = rightShift
                rightShift += auxiliary.glyph.getWidth() + Ornament.minPadding + 2
            }
            let markWidth = ornament.getWidth()
            let sidePadding = (markWidth - ornament.width) / 2
            if ornament.position == .right {
                ornament.sideOffset = rightShift + sidePadding + 2
                rightShift += markWidth + Ornament.minPadding
            } else if ornament.position == .left {
                ornament.sideOffset = -(leftShift + markWidth - sidePadding + 2)
                leftShift += markWidth + Ornament.minPadding
            } else if ornament.position == .above {
                width = max(markWidth, width)
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
                width = max(markWidth, width)
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

    // MARK: - Editorial Parentheses (VexFlow 5.8.0)

    /// Enclose an editorial ornament in round parentheses. Pass false to remove them.
    @discardableResult
    public func setParenthesized(_ parenthesized: Bool = true) -> Self {
        if parenthesized {
            if parentheses == nil {
                parentheses = (
                    left: VexElement().setText(Glyphs.noteheadParenthesisLeft),
                    right: VexElement().setText(Glyphs.noteheadParenthesisRight)
                )
            }
        } else {
            parentheses = nil
        }
        return self
    }

    /// True when the ornament has editorial parentheses.
    public var isParenthesized: Bool { parentheses != nil }

    /// Leave ink clearance on each side, scaled to the active music font.
    private var parenthesisGap: Double {
        fontSizeInPixels / 24
    }

    /// Reserve symmetric space so that the ornament itself stays centered on its note.
    override public func getWidth() -> Double {
        guard let parentheses else { return width }
        let left = parentheses.left.setFont(fontInfo).getTextInk(0, 0).w
        let right = parentheses.right.setFont(fontInfo).getTextInk(0, 0).w
        let ink = getTextInk(-xShift, -yShift)
        let margin = max(left - ink.x, ink.x + ink.w - width + right) + parenthesisGap
        return width + 2 * max(0, margin)
    }

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

    // MARK: - Pitched Trill (VexFlow 5.8.0)

    /// The written pitch of the trill partner, for example `bb/4`, or nil.
    public var auxiliaryPitch: String? { auxiliary?.pitch }

    /// Show a parenthesized cue beside the trill's written principal, e.g. bb/4, an/4 or a/4.
    /// Pass nil to remove the cue. Throw `BadArguments` when the ornament is not a trill or
    /// the pitch is not valid.
    @discardableResult
    public func setAuxiliaryPitch(_ pitch: String?) throws -> Self {
        guard let pitch else {
            auxiliary = nil
            return self
        }
        guard type == "tr", let spelling = Ornament.parseAuxiliaryPitch(pitch) else {
            throw VexError("BadArguments", "A pitched trill needs a written pitch such as bb/4.")
        }
        let accidental = spelling.isEmpty ? "" : Tables.accidentalCodes(spelling.lowercased())
        let glyph = VexElement().setFont(fontInfo).setFontSize(fontSizeInPoints * 0.65)
        let prefix = Glyphs.accidentalParensLeft + accidental
        let headOffset = glyph.setText(prefix).getWidth()
        let headWidth = glyph.setText(Glyphs.noteheadBlack).getWidth()
        glyph.setText(prefix + Glyphs.noteheadBlack + Glyphs.accidentalParensRight)
        auxiliary = (pitch: pitch.lowercased(), glyph: glyph, headOffset: headOffset, headWidth: headWidth)
        return self
    }

    /// Match `/^([a-g])(bb|##|b|#|n)?\/(-?\d)$/i`. Return the accidental part, or nil for no match.
    private static func parseAuxiliaryPitch(_ pitch: String) -> String? {
        let chars = Array(pitch)
        guard chars.count >= 3, "abcdefg".contains(chars[0].lowercased()) else { return nil }
        guard let slash = chars.firstIndex(of: "/") else { return nil }
        let accidental = String(chars[1..<slash])
        guard ["", "bb", "##", "b", "#", "n"].contains(accidental.lowercased()) else { return nil }
        var octave = chars[(slash + 1)...]
        if octave.first == "-" { octave = octave.dropFirst() }
        guard octave.count == 1, let digit = octave.first, digit.isASCII, digit.isNumber else { return nil }
        return accidental
    }

    // MARK: - Draw

    private var layoutShiftY: Double = 0
    /// Move the whole ornament and its auxiliary signs together. (VexFlow 5.4.0)
    public func setLayoutShiftY(_ y: Double) {
        layoutShiftY = y
    }

    /// Recompute delayed and auxiliary positions against the current tick contexts. (VexFlow 5.3.0)
    private func positionElements() throws -> [(element: VexElement, x: Double, y: Double)] {
        let note = try checkAttachedNoteThrowing()
        let stave = try note.checkStaveThrowing()
        var parts: [(element: VexElement, x: Double, y: Double)] = []

        // Get initial coordinates for the modifier position
        let start = note.getModifierStartXY(position: position, index: index ?? 0)
        var glyphX = start.x + sideOffset

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

        glyphY += layoutShiftY
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
            }
            glyphX += delayXShift
        }

        if let accidentalLower {
            parts.append((
                element: accidentalLower,
                x: glyphX + xShift - accidentalLower.getWidth() / 2,
                y: glyphY + yShift - accidentalLower.getTextMetrics().actualBoundingBoxDescent
            ))
            glyphY -= accidentalLower.getHeight() + renderOptions.accidentalLowerPadding
        }

        let offset = Ornament.ornamentYShift.contains(type) ? getHeight() : 0
        x = glyphX - (position == .above || position == .below ? width / 2 : 0)
        y = glyphY + offset
        parts.append((element: self, x: 0, y: 0))
        if let parentheses {
            let ink = getTextInk(x, y)
            // Center the signs on the ornament's ink, even when their glyph baselines differ.
            for (side, element) in [parentheses.left, parentheses.right].enumerated() {
                let sign = element.setFont(fontInfo).getTextInk(0, 0)
                let edge = side == 0 ? ink.x - parenthesisGap - sign.w : ink.x + ink.w + parenthesisGap
                parts.append((element: element, x: edge - sign.x, y: ink.y + (ink.h - sign.h) / 2 - sign.y))
            }
        }
        if let accidentalUpper {
            parts.append((
                element: accidentalUpper,
                x: glyphX + xShift - accidentalUpper.getWidth() / 2,
                y: y + yShift - getHeight() - renderOptions.accidentalUpperPadding
                    - accidentalUpper.getTextMetrics().actualBoundingBoxDescent
            ))
        }
        if let auxiliary {
            guard let staveNote = note as? StaveNote, !note.isRest() else {
                throw VexError("BadArguments", "A trill partner needs a pitched staff note.")
            }
            // Measure the diatonic interval from the written key. The principal's actual line
            // also accounts for octave clefs and authored staff placement.
            let index = try checkIndexThrowing()
            let principal = try Tables.keyProperties(staveNote.getKeys()[index], clef: .treble)
            let partner = try Tables.keyProperties(auxiliary.pitch, clef: .treble)
            let y = staveNote.getYs()[index] - (partner.line - principal.line) * staffSpace
            let right = staveNote.getModifierStartXY(position: .right, index: index, forceFlagRight: true)
            let headEdge = staveNote.getHeadInk().map { $0.x + $0.w }.max() ?? -Double.infinity
            parts.append((element: auxiliary.glyph, x: max(right.x, headEdge + 2) + auxiliaryOffset, y: y))
        }
        return parts
    }

    /// Outside the staff, ledger lines belong to the cue head alone. (VexFlow 5.8.0)
    private func cueLedgers(_ element: VexElement, _ x: Double, _ y: Double) -> [BoundingBox] {
        guard let auxiliary, element === auxiliary.glyph,
              let stave = (try? checkAttachedNoteThrowing())?.getStave() else { return [] }
        let top = stave.getYForLine(0)
        let bottom = stave.getYForLine(Double(stave.getNumLines() - 1))
        let step = stave.getSpacingBetweenLines()
        if !(step > 0) || !y.isFinite { return [] }
        var lines: [BoundingBox] = []
        let left = x + auxiliary.headOffset - 1
        let width = auxiliary.headWidth + 2
        var line = top - step
        while line >= y {
            lines.append(BoundingBox(left, line, width, 1))
            line -= step
        }
        line = bottom + step
        while line <= y {
            lines.append(BoundingBox(left, line, width, 1))
            line += step
        }
        return lines
    }

    /// Measure the ornament and all of its visible signs together. (VexFlow 5.8.0)
    override public func getBoundingBox() -> BoundingBox? {
        guard let parts = try? positionElements() else { return nil }
        var result: BoundingBox?
        for part in parts {
            let boxes = [part.element.getTextInk(part.x + part.element.getX(), part.y + part.element.getY())]
                + cueLedgers(part.element, part.x, part.y)
            for box in boxes {
                if result == nil { result = box } else { _ = result?.mergeWith(box) }
            }
        }
        return result
    }

    /// Render ornament in position next to note.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        _ = ctx.openGroup(groupClass("ornament"), getAttribute("id"))
        for part in try positionElements() {
            for line in cueLedgers(part.element, part.x, part.y) {
                ctx.fillRect(line.x, line.y, line.w, line.h)
            }
            part.element.renderText(ctx, xPos: part.x, yPos: part.y)
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
