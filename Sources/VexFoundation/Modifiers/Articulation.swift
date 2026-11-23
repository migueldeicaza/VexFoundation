// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Larry Kuhns.
//
// Port of `src/articulation.ts` (VexFlow 5.4.0).
// Articulation placement, measurement and rendering.

import Foundation

// `ArticulationStruct` is declared in `Core/Tables.swift` (the articulation table needs it).

// MARK: - Helper Functions

private func roundToNearestHalf(_ mathFn: (Double) -> Double, _ value: Double) -> Double {
    mathFn(value / 0.5) * 0.5
}

/// This includes both staff and ledger lines.
private func isWithinLines(_ line: Double, _ position: ModifierPosition) -> Bool {
    position == .above ? line <= 5 : line >= 1
}

private func getRoundingFunction(_ line: Double, _ position: ModifierPosition) -> (Double) -> Double {
    if isWithinLines(line, position) {
        if position == .above {
            return { Foundation.ceil($0) }
        } else {
            return { Foundation.floor($0) }
        }
    } else {
        // JavaScript Math.round semantics (ties toward +infinity).
        return { Foundation.floor($0 + 0.5) }
    }
}

private func snapLineToStaff(
    _ canSitBetweenLines: Bool,
    _ line: Double,
    _ position: ModifierPosition,
    _ offsetDirection: Double
) -> Double {
    // Initially, snap to nearest staff line or space
    let snappedLine = roundToNearestHalf(getRoundingFunction(line, position), line)
    let canSnapToStaffSpace = canSitBetweenLines && isWithinLines(snappedLine, position)
    let onStaffLine = snappedLine.truncatingRemainder(dividingBy: 1) == 0

    if canSnapToStaffSpace && onStaffLine {
        let halfStaffSpace = 0.5
        return snappedLine + halfStaffSpace * -offsetDirection
    } else {
        return snappedLine
    }
}

/// Helper function for checking if a Note object is either a StaveNote or a GraceNote.
private func isStaveOrGraceNote(_ note: Note) -> Bool {
    note is StaveNote || note is GraceNote
}

func getTopY(_ note: Note, _ textLine: Double) throws -> Double {
    let stemDirection = note.getStemDirection()
    let extents = note.getStemExtents()
    let stemTipY = extents.topY
    let stemBaseY = extents.baseY

    if isStaveOrGraceNote(note) {
        if note.hasStem() {
            if stemDirection == Stem.UP {
                return stemTipY
            } else {
                return stemBaseY
            }
        } else {
            return note.getYs().min() ?? 0
        }
    } else if note is TabNote {
        if note.hasStem() {
            if stemDirection == Stem.UP {
                return stemTipY
            } else {
                return try note.checkStaveThrowing().getYForTopText(textLine)
            }
        } else {
            return try note.checkStaveThrowing().getYForTopText(textLine)
        }
    } else {
        throw VexError("UnknownCategory", "Only can get the top and bottom ys of stavenotes and tabnotes")
    }
}

func getBottomY(_ note: Note, _ textLine: Double) throws -> Double {
    let stemDirection = note.getStemDirection()
    let extents = note.getStemExtents()
    let stemTipY = extents.topY
    let stemBaseY = extents.baseY

    if isStaveOrGraceNote(note) {
        if note.hasStem() {
            if stemDirection == Stem.UP {
                return stemBaseY
            } else {
                return stemTipY
            }
        } else {
            return note.getYs().max() ?? 0
        }
    } else if note is TabNote {
        if note.hasStem() {
            if stemDirection == Stem.UP {
                return try note.checkStaveThrowing().getYForBottomText(textLine)
            } else {
                return stemTipY
            }
        } else {
            return try note.checkStaveThrowing().getYForBottomText(textLine)
        }
    } else {
        throw VexError("UnknownCategory", "Only can get the top and bottom ys of stavenotes and tabnotes")
    }
}

/// Get the initial offset of the articulation from the y value of the starting position.
/// This is required because the top/bottom text positions already have spacing applied to
/// provide a "visually pleasant" default position. However the y values provided from
/// the stavenote's top/bottom do *not* have any pre-applied spacing. This function
/// normalizes this asymmetry.
func getInitialOffset(_ note: Note, _ position: ModifierPosition) -> Double {
    let isOnStemTip = (position == .above && note.getStemDirection() == Stem.UP)
        || (position == .below && note.getStemDirection() == Stem.DOWN)

    if isStaveOrGraceNote(note) {
        if note.hasStem() && isOnStemTip {
            return 0.5
        } else {
            // this amount is larger than the stem-tip offset because we start from
            // the center of the notehead
            return 1
        }
    } else {
        if note.hasStem() && isOnStemTip {
            return 1
        } else {
            return 0
        }
    }
}

// MARK: - Articulation

/// Articulations and Accents are modifiers that can be attached to notes.
/// The complete list of articulations is available in `Tables.articulationCodes`.
public final class Articulation: Modifier {

    override public class var category: String { "Articulation" }

    static let INITIAL_OFFSET: Double = -0.5

    /// VexFlowPatch: articulation code for a breath mark (OSMD). It is not in
    /// the upstream articulation table.
    static let breathMarkType = "abr"

    // MARK: - Properties

    /// Articulation code provided to the constructor.
    public let type: String
    public private(set) var articulation: ArticulationStruct
    /// VexFlowPatch: % distance to next note or end of stave for breath marks (0.8 = 80%)
    public var breathMarkDistance: Double = 0.8

    /// VexFlowPatch: x and y shifts set by the user. Upstream formatting
    /// overwrites `xShift` and `yShift` with `setOrigin()`, so the user shifts
    /// are kept here and applied in `draw()`.
    private var userXShift: Double = 0
    private var userYShift: Double = 0

    /// Look up `type` in the articulation table.
    private static func lookup(_ type: String) -> ArticulationStruct? {
        if let artic = Tables.articulationCodes(type) {
            return artic
        }
        // VexFlowPatch: breath mark.
        if type == breathMarkType {
            return ArticulationStruct(code: Glyphs.breathMarkComma, betweenLines: false)
        }
        return nil
    }

    // MARK: - Init

    /// Create a new articulation.
    ///
    /// - Parameter type: entry in `Tables.articulationCodes` or a glyph code
    ///   (a SMuFL code point, or a SMuFL glyph name).
    ///
    /// Notes default positions (see https://w3c.github.io/smufl/latest/tables/articulation.html):
    /// - Even codes will be positioned ABOVE
    /// - Odd codes will be positioned BELOW
    public init(_ type: String) {
        // Swift extension: accept a SMuFL glyph name and use its code point.
        let resolvedType: String
        if Self.lookup(type) == nil, let code = Glyphs.code(named: type) {
            resolvedType = code
        } else {
            resolvedType = type
        }
        self.type = resolvedType
        self.articulation = ArticulationStruct(betweenLines: false)
        super.init()

        position = .above
        if Self.lookup(resolvedType) == nil {
            if (resolvedType.unicodeScalars.first?.value ?? 0) % 2 == 0 {
                position = .above
            } else {
                position = .below
            }
        }

        reset()
    }

    // MARK: - Reset

    /// Explicit `setBetweenLines` value that survives `reset()`. (VexFlow 5.3.0)
    private var betweenLinesOverride: Bool?

    override public func reset() {
        // Use type as glyph code, if not defined as articulation code
        articulation = Self.lookup(type) ?? ArticulationStruct(code: type, betweenLines: false)
        if let betweenLinesOverride { articulation.betweenLines = betweenLinesOverride }
        let positional = position == .above ? articulation.aboveCode : articulation.belowCode
        let code = nonEmpty(positional) ?? nonEmpty(articulation.code) ?? Glyphs.null
        text = code
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }

    // MARK: - Between Lines

    /// Set if articulation should be rendered between lines.
    @discardableResult
    public func setBetweenLines(_ betweenLines: Bool = true) -> Self {
        betweenLinesOverride = betweenLines
        articulation.betweenLines = betweenLines
        return self
    }

    // MARK: - Shifts (VexFlowPatch)

    /// VexFlowPatch: respect the modifier `yShift`.
    @discardableResult
    override public func setYShift(_ y: Double) -> Self {
        userYShift = y
        return self
    }

    /// VexFlowPatch: respect the modifier `xShift` for breath marks.
    @discardableResult
    override public func setXShift(_ x: Double) -> Self {
        userXShift = position == .left ? -x : x
        return self
    }

    // MARK: - Static Format

    /// FIXME (upstream):
    /// Most of the complex formatting logic (ie: snapping to space) is
    /// actually done in .render(). But that logic belongs in this method.
    ///
    /// Unfortunately, this isn't possible because, by this point, stem lengths
    /// have not yet been finalized. Finalized stem lengths are required to determine the
    /// initial position of any stem-side articulation.
    @discardableResult
    public static func format(_ articulations: [Articulation], state: inout ModifierContextState) -> Bool {
        if articulations.isEmpty { return false }

        let margin: Double = 0.5
        var maxGlyphWidth: Double = 0

        func getIncrement(_ articulation: Articulation, _ line: Double, _ position: ModifierPosition) -> Double {
            roundToNearestHalf(getRoundingFunction(line, position), articulation.height / 10 + margin)
        }

        for articulation in articulations {
            let note = articulation.checkAttachedNote()
            maxGlyphWidth = max(note.getGlyphWidth(), maxGlyphWidth)
            var lines: Double = 5
            let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
            var stemHeight: Double = 0
            // Decide if we need to consider beam direction in placement.

            if let stemmable = note as? StemmableNote {
                if let stem = stemmable.getStem() {
                    stemHeight = abs(stem.getHeight()) / Tables.STAVE_LINE_DISTANCE
                }
            }
            if let stave = note.getStave() {
                lines = Double(stave.getNumLines())
            }
            if articulation.getPosition() == .above {
                var noteLine = note.getLineNumber(isTopNote: true)
                if stemDirection == Stem.UP {
                    noteLine += stemHeight
                }
                var increment = getIncrement(articulation, state.topTextLine, .above)
                let curTop = noteLine + state.topTextLine + 0.5
                // If articulation must be above stave, add lines between note and stave top
                if !articulation.articulation.betweenLines && curTop < lines {
                    increment += lines - curTop
                }
                _ = articulation.setTextLine(state.topTextLine)
                state.topTextLine += increment
                articulation.setOrigin(0.5, 1)
            } else if articulation.getPosition() == .below {
                var noteLine = max(lines - note.getLineNumber(), 0)
                if stemDirection == Stem.DOWN {
                    noteLine += stemHeight
                }
                var increment = getIncrement(articulation, state.textLine, .below)
                let curBottom = noteLine + state.textLine + 0.5
                // if articulation must be below stave, add lines from note to stave bottom
                if !articulation.articulation.betweenLines && curBottom < lines {
                    increment += lines - curBottom
                }
                _ = articulation.setTextLine(state.textLine)
                state.textLine += increment
                articulation.setOrigin(0.5, 0)
            }
        }

        let width = articulations
            .map { $0.getWidth() }
            .reduce(-Double.infinity) { maxWidth, articWidth in max(articWidth, maxWidth) }
        let overlap = min(
            max(width - maxGlyphWidth, 0),
            max(width - (state.leftShift + state.rightShift), 0)
        )

        state.leftShift += overlap / 2
        state.rightShift += overlap / 2
        return true
    }

    // MARK: - EasyScore Hook

    /// SMuFL values accepted by the native articulation constructor, cached for notation validation.
    private static let easyScoreGlyphs = Set(Glyphs.byName.values)

    /// Resolve EasyScore aliases, native codes, or named SMuFL glyphs without constructing a modifier.
    /// Throws for an unknown name. (VexFlow 5.2.0)
    public static func parseEasyScore(_ articulations: String) throws -> [(type: String, position: ModifierPosition?)] {
        let aliases: [String: String] = [
            "staccato": "a.",
            "tenuto": "a-",
            "accent": "a>",
            "fermata": "a@",
            "marcato": "a^",
            "staccatissimo": "av",
        ]
        let suffix = try NSRegularExpression(pattern: "^(.*)\\.(above|below|left|right)$", options: [.dotMatchesLineSeparators])
        func splitPosition(_ value: String) -> (name: String, position: String?) {
            let range = NSRange(value.startIndex..., in: value)
            guard let match = suffix.firstMatch(in: value, range: range),
                  let name = Range(match.range(at: 1), in: value),
                  let position = Range(match.range(at: 2), in: value)
            else { return (value, nil) }
            return (String(value[name]), String(value[position]))
        }
        let singleCode = splitPosition(articulations.trimmingCharacters(in: .whitespacesAndNewlines)).name
        let items = Tables.articulationCodes(singleCode) != nil
            ? [articulations]
            : articulations.components(separatedBy: ",")
        return try items.map { value in
            // A native code can itself contain a dot (a.). Only consume a named position suffix.
            let (name, position) = splitPosition(value.trimmingCharacters(in: .whitespacesAndNewlines))
            let type = aliases[name] ?? name
            let glyph = Glyphs.code(named: type) ?? type
            if Tables.articulationCodes(type) == nil && !easyScoreGlyphs.contains(glyph) {
                throw VexError("BadArguments", "Unknown EasyScore articulation: \(name)")
            }
            return (glyph, position.flatMap { Modifier.positionString[$0] })
        }
    }

    /// Attach validated EasyScore articulations once, after note construction.
    public static func easyScoreHook(
        options: [String: String],
        note: StemmableNote,
        builder: Builder
    ) throws {
        guard let articulations = options["articulations"], !articulations.isEmpty else { return }
        for params in try parseEasyScore(articulations) {
            let artic = builder.getFactory().Articulation(type: params.type, position: params.position)
            _ = note.addModifier(artic, index: 0)
        }
    }

    // MARK: - Draw

    private var layoutShiftY: Double = 0
    /// Derived clearance from neighboring attacks, recomputed at each phrase layout. (VexFlow 5.4.0)
    public func setLayoutShiftY(_ y: Double) {
        layoutShiftY = y
    }

    /// Resolve the glyph origin after its owner and modifier context have been formatted. (VexFlow 5.3.0)
    private func getPlacement() throws -> (x: Double, y: Double, centered: Bool) {
        let note = try checkAttachedNoteThrowing()
        var centered = false

        let index = try checkIndexThrowing()
        let position = self.position
        let textLine = self.textLine
        let canSitBetweenLines = articulation.betweenLines

        let stave = try note.checkStaveThrowing()
        let staffSpace = stave.getSpacingBetweenLines()
        let isTab = note is TabNote

        // Articulations are centered over/under the note head.
        var x = note.getModifierStartXY(position: position, index: index).x

        // VexFlowPatch: breath mark positioning
        if type == Self.breathMarkType, let noteTickContext = note.tickContext {
            var delayXShift: Double = 0
            let noteX = noteTickContext.getX()
            if let nextContext = TickContext.getNextContext(noteTickContext),
               nextContext.getX() > noteTickContext.getX() {
                delayXShift = (nextContext.getX() - noteX) * breathMarkDistance
            } else {
                delayXShift = (stave.getX() + stave.getWidth() - noteX + stave.getNoteStartX() - stave.getX())
                    * breathMarkDistance
            }
            x += delayXShift
            // Clamp to not exceed end of stave
            if x > stave.getNoteEndX() {
                let noteXAbsolute = stave.getNoteStartX() - stave.getX() + noteX + stave.getX()
                x = noteXAbsolute + (stave.getNoteEndX() - noteXAbsolute) * breathMarkDistance
            }
            if userXShift != 0 {
                x += userXShift
            }
        }

        let shouldSitOutsideStaff = !canSitBetweenLines || isTab

        let initialOffset = getInitialOffset(note, position)

        var y: Double
        if position == .above {
            let y0 = try getTopY(note, textLine) - (textLine + initialOffset) * staffSpace
            y = shouldSitOutsideStaff ? min(stave.getYForTopText(Articulation.INITIAL_OFFSET), y0) : y0
        } else if position == .below {
            let y0 = try getBottomY(note, textLine) + (textLine + initialOffset) * staffSpace
            y = shouldSitOutsideStaff ? max(stave.getYForBottomText(Articulation.INITIAL_OFFSET), y0) : y0
        } else {
            throw VexError("InvalidPosition", "Articulation position must be above or below.")
        }

        if !isTab {
            let offsetDirection: Double = position == .above ? -1 : 1
            let noteLine = note.getKeyProps()[index].line
            let distanceFromNote = (note.getYs()[index] - y) / staffSpace
            let articLine = distanceFromNote + noteLine
            let snappedLine = snapLineToStaff(canSitBetweenLines, articLine, position, offsetDirection)

            centered = isWithinLines(snappedLine, position)

            y += abs(snappedLine - articLine) * staffSpace * offsetDirection
        }

        // VexFlowPatch: respect modifier yShift
        if userYShift != 0 {
            y += userYShift
        }

        return (x, y + layoutShiftY, centered)
    }

    /// Get visible glyph ink without mutating its alignment or drawing coordinates. (VexFlow 5.3.0)
    public func getInkBounds() throws -> BoundingBox {
        let placement = try getPlacement()
        var box = getTextInk(placement.x, placement.y)
        if placement.centered {
            box.x += -width / 2 - xShift
            box.y = placement.y - height / 2
        }
        return box
    }

    /// Render articulation in position next to note.
    override public func draw() throws {
        let ctx = try checkContext()
        let placement = try getPlacement()
        if placement.centered { setOrigin(0.5, 0.5) }
        setRendered()
        self.x = placement.x
        self.y = placement.y
        renderText(ctx, xPos: 0, yPos: 0)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Articulation", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(f.Articulation(type: "a."), index: 0)  // staccato
        _ = notes[1].addModifier(f.Articulation(type: "a>"), index: 0)  // accent
        _ = notes[2].addModifier(f.Articulation(type: "a-"), index: 0)  // tenuto
        _ = notes[3].addModifier(f.Articulation(type: "a^"), index: 0)  // marcato

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
