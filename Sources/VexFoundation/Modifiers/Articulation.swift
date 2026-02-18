// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. Author: Larry Kuhns.
// MIT License

import Foundation

// MARK: - Helper Functions

private func roundToNearestHalf(_ mathFn: (Double) -> Double, _ value: Double) -> Double {
    mathFn(value / 0.5) * 0.5
}

private func isWithinLines(_ line: Double, _ position: ModifierPosition) -> Bool {
    position == .above ? line <= 5 : line >= 1
}

private func getRoundingFunction(_ line: Double, _ position: ModifierPosition) -> (Double) -> Double {
    if isWithinLines(line, position) {
        return position == .above ? { Foundation.ceil($0) } : { Foundation.floor($0) }
    }
    return { $0.rounded() }
}

private func snapLineToStaff(_ canSitBetweenLines: Bool, _ line: Double, _ position: ModifierPosition, _ offsetDirection: Double) -> Double {
    let snappedLine = roundToNearestHalf(getRoundingFunction(line, position), line)
    let canSnap = canSitBetweenLines && isWithinLines(snappedLine, position)
    let onStaffLine = snappedLine.truncatingRemainder(dividingBy: 1) == 0

    if canSnap && onStaffLine {
        return snappedLine + 0.5 * -offsetDirection
    }
    return snappedLine
}

private func getTopY(_ note: Note, _ textLine: Double) -> Double {
    let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
    let extents = note.getStemExtents()

    if note.hasStem() {
        return stemDirection == Stem.UP ? extents.topY : extents.baseY
    }
    return note.getYs().min() ?? 0
}

private func getBottomY(_ note: Note, _ textLine: Double) -> Double {
    let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
    let extents = note.getStemExtents()

    if note.hasStem() {
        return stemDirection == Stem.UP ? extents.baseY : extents.topY
    }
    return note.getYs().max() ?? 0
}

private func getInitialOffset(_ note: Note, _ position: ModifierPosition) -> Double {
    let isOnStemTip = (position == .above && note.getStemDirection() == Stem.UP) ||
                      (position == .below && note.getStemDirection() == Stem.DOWN)

    if note.hasStem() && isOnStemTip {
        return 0.5
    }
    return 1
}

// MARK: - Articulation

/// Modifier that adds articulations (staccato, accent, marcato, etc.) to notes.
/// Positioned above or below the note.
public final class Articulation: Modifier {

    override public class var category: String { "Articulation" }

    static let INITIAL_OFFSET: Double = -0.5

    // MARK: - Properties

    public let type: String
    public var fontScale: Double = Tables.NOTATION_FONT_SCALE
    public var articulationData: Tables.ArticulationStruct

    private var glyph: Glyph!

    // MARK: - Init

    public init(_ type: String) {
        self.type = type

        // Look up articulation or use type as direct glyph code
        if let artData = Tables.articulationCode(type) {
            self.articulationData = artData
        } else {
            self.articulationData = Tables.ArticulationStruct(code: type, betweenLines: false)
        }

        super.init()
        position = .above

        // Infer position from glyph code suffix
        if Tables.articulationCode(type) == nil {
            if type.hasSuffix("Above") { position = .above }
            if type.hasSuffix("Below") { position = .below }
        }

        reset()
    }

    // MARK: - Reset

    private func reset() {
        let code: String
        if position == .above {
            code = articulationData.aboveCode ?? articulationData.code ?? ""
        } else {
            code = articulationData.belowCode ?? articulationData.code ?? ""
        }

        glyph = Glyph(code: code, point: fontScale)
        _ = setWidth(glyph.getMetrics().width)
    }

    // MARK: - Between Lines

    @discardableResult
    public func setBetweenLines(_ betweenLines: Bool = true) -> Self {
        articulationData.betweenLines = betweenLines
        return self
    }

    // MARK: - Set Position Override

    @discardableResult
    override public func setPosition(_ pos: ModifierPosition) -> Self {
        position = pos
        reset()
        return self
    }

    // MARK: - Static Format

    @discardableResult
    public static func format(_ articulations: [Articulation], state: inout ModifierContextState) -> Bool {
        if articulations.isEmpty { return false }

        let margin: Double = 0.5
        var maxGlyphWidth: Double = 0

        for articulation in articulations {
            let note = articulation.checkAttachedNote()
            maxGlyphWidth = max(note.getGlyphWidth(), maxGlyphWidth)

            var lines: Double = 5
            let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP

            var stemHeight: Double = 0
            if let stemmable = note as? StemmableNote, let stem = stemmable.getStem() {
                stemHeight = abs(stem.getHeight()) / Tables.STAVE_LINE_DISTANCE
            }

            if let stave = note.getStave() {
                lines = Double(stave.getNumLines())
            }

            let pos = articulation.getPosition()

            if pos == .above {
                var noteLine = note.getLineNumber(isTopNote: true)
                if stemDirection == Stem.UP {
                    noteLine += stemHeight
                }
                var increment = roundToNearestHalf(
                    getRoundingFunction(state.topTextLine, .above),
                    articulation.glyph.getMetrics().height / 10 + margin
                )
                let curTop = noteLine + state.topTextLine + 0.5
                if !articulation.articulationData.betweenLines && curTop < lines {
                    increment += lines - curTop
                }
                _ = articulation.setTextLine(state.topTextLine)
                state.topTextLine += increment
            } else if pos == .below {
                var noteLine = max(lines - note.getLineNumber(), 0)
                if stemDirection == Stem.DOWN {
                    noteLine += stemHeight
                }
                var increment = roundToNearestHalf(
                    getRoundingFunction(state.textLine, .below),
                    articulation.glyph.getMetrics().height / 10 + margin
                )
                let curBottom = noteLine + state.textLine + 0.5
                if !articulation.articulationData.betweenLines && curBottom < lines {
                    increment += lines - curBottom
                }
                _ = articulation.setTextLine(state.textLine)
                state.textLine += increment
            }
        }

        let maxArticWidth = articulations.reduce(0.0) { max($0, $1.getWidth()) }
        let overlap = min(
            max(maxArticWidth - maxGlyphWidth, 0),
            max(maxArticWidth - (state.leftShift + state.rightShift), 0)
        )

        state.leftShift += overlap / 2
        state.rightShift += overlap / 2
        return true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        let index = checkIndex()
        let canSitBetweenLines = articulationData.betweenLines

        let stave = note.checkStave()
        let staffSpace = stave.getSpacingBetweenLines()

        guard let staveNote = note as? StaveNote else { return }
        let x = staveNote.getModifierStartXY(position: position, index: index).x

        let shouldSitOutsideStaff = !canSitBetweenLines
        let initialOffset = getInitialOffset(note, position)

        let padding = (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("articulation.\(glyph.getCode()).padding") as? Double) ?? 0

        var y: Double
        if position == .above {
            glyph.setOrigin(0.5, 1)
            y = getTopY(note, textLine) - (textLine + initialOffset) * staffSpace
            if shouldSitOutsideStaff {
                y = min(stave.getYForTopText(Articulation.INITIAL_OFFSET), y)
            }
        } else {
            glyph.setOrigin(0.5, 0)
            y = getBottomY(note, textLine) + (textLine + initialOffset) * staffSpace
            if shouldSitOutsideStaff {
                y = max(stave.getYForBottomText(Articulation.INITIAL_OFFSET), y)
            }
        }

        // Snap to staff lines
        let offsetDirection: Double = position == .above ? -1 : 1
        let props = note.getKeyProps()
        if index < props.count {
            let noteLine = props[index].line
            let ys = note.getYs()
            if index < ys.count {
                let distanceFromNote = (ys[index] - y) / staffSpace
                let articLine = distanceFromNote + noteLine
                let snappedLine = snapLineToStaff(canSitBetweenLines, articLine, position, offsetDirection)

                if isWithinLines(snappedLine, position) {
                    glyph.setOrigin(0.5, 0.5)
                }

                y += abs(snappedLine - articLine) * staffSpace * offsetDirection + padding * offsetDirection
            }
        }

        glyph.render(ctx: ctx, x: x, y: y)
    }

    // MARK: - EasyScore Hook

    /// Commit hook for EasyScore to auto-add articulations.
    public static func easyScoreHook(
        options: [String: String],
        note: StemmableNote,
        builder: Builder
    ) {
        guard let articulationStr = options["articulations"] else { return }

        let articNameToCode: [String: String] = [
            "staccato": "a.",
            "tenuto": "a-",
            "accent": "a>",
        ]

        for articString in articulationStr.split(separator: ",") {
            let parts = articString.trimmingCharacters(in: .whitespaces).split(separator: ".")
            let name = String(parts[0])
            guard let code = articNameToCode[name] else { continue }
            let artic = builder.getFactory().Articulation(type: code)
            if parts.count > 1 {
                if let pos = Modifier.positionString[String(parts[1])] {
                    _ = artic.setPosition(pos)
                }
            }
            _ = note.addModifier(artic, index: 0)
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Articulation", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
            .addTimeSignature("4/4")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
