// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Dot

/// Modifier that adds augmentation dots to notes.
/// Positioned to the right of the notehead.
public final class Dot: Modifier {

    override public class var category: String { "Dot" }

    // MARK: - Properties

    public var radius: Double = 2
    public var dotShiftY: Double = 0

    // MARK: - Init

    public override init() {
        super.init()
        position = .right
        _ = setWidth(5)
    }

    // MARK: - Static Helpers

    /// Returns all Dot modifiers attached to a note.
    public static func getDots(_ note: Note) -> [Dot] {
        note.getModifiersByType("Dot").compactMap { $0 as? Dot }
    }

    /// Create dots and attach them to notes.
    public static func buildAndAttach(_ notes: [Note], index: Int? = nil, all: Bool = false) {
        for note in notes {
            if all {
                for i in 0..<note.keys.count {
                    let dot = Dot()
                    dot.setDotShiftY(note.glyphProps.dotShiftY)
                    _ = note.addModifier(dot, index: i)
                }
            } else {
                let dot = Dot()
                dot.setDotShiftY(note.glyphProps.dotShiftY)
                _ = note.addModifier(dot, index: index ?? 0)
            }
        }
    }

    // MARK: - Set Note

    @discardableResult
    override public func setNote(_ note: Note) -> Self {
        self.note = note
        // Grace notes get smaller dots
        // if isGraceNote(note) { radius *= 0.5; setWidth(3) }
        return self
    }

    // MARK: - Dot Shift Y

    @discardableResult
    public func setDotShiftY(_ y: Double) -> Self {
        dotShiftY = y
        return self
    }

    // MARK: - Static Format

    /// Arrange dots inside a ModifierContext.
    @discardableResult
    public static func format(_ dots: [Dot], state: inout ModifierContextState) -> Bool {
        let rightShift = state.rightShift
        let dotSpacing: Double = 1

        if dots.isEmpty { return false }

        struct DotEntry {
            var line: Double
            var note: Note
            var noteID: String
            var dot: Dot
        }

        var dotList: [DotEntry] = []
        var maxShiftMap: [String: Double] = [:]

        for dot in dots {
            let note = dot.getNote()

            let line: Double
            let shift: Double

            if let staveNote = note as? StaveNote {
                let index = dot.checkIndex()
                let props = staveNote.getKeyProps()[index]
                line = props.line
                shift = staveNote.getFirstDotPx()
            } else {
                // Default fallback
                line = 0.5
                shift = rightShift
            }

            let noteID = note.getAttribute("id") ?? "\(ObjectIdentifier(note))"
            dotList.append(DotEntry(line: line, note: note, noteID: noteID, dot: dot))
            maxShiftMap[noteID] = max(maxShiftMap[noteID] ?? shift, shift)
        }

        // Sort dots by line number (descending)
        dotList.sort { $0.line > $1.line }

        var dotShift = rightShift
        var xWidth: Double = 0
        var lastLine: Double?
        var lastNote: Note?
        var prevDottedSpace: Double?
        var halfShiftY: Double = 0

        for entry in dotList {
            let dot = entry.dot
            let note = entry.note
            let noteID = entry.noteID
            let line = entry.line

            // Reset dot position every line
            if line != lastLine || note !== lastNote {
                dotShift = maxShiftMap[noteID] ?? rightShift
            }

            if !note.isRest() && line != lastLine {
                if abs(line.truncatingRemainder(dividingBy: 1)) == 0.5 {
                    // Note is on a space
                    halfShiftY = 0
                } else {
                    // Note is on a line, shift dot to space above
                    halfShiftY = 0.5
                    if let ln = lastNote, !ln.isRest(), let ll = lastLine, ll - line == 0.5 {
                        halfShiftY = -0.5
                    } else if let pds = prevDottedSpace, line + halfShiftY == pds {
                        halfShiftY = -0.5
                    }
                }
            }

            if note.isRest() {
                dot.dotShiftY += -halfShiftY
            } else {
                dot.dotShiftY = -halfShiftY
            }
            prevDottedSpace = line + halfShiftY

            _ = dot.setXShift(dotShift)
            dotShift += dot.getWidth() + dotSpacing
            xWidth = max(dotShift, xWidth)
            lastLine = line
            lastNote = note
        }

        state.rightShift += xWidth
        return true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        guard let staveNote = note as? StaveNote else { return }
        let stave = note.checkStave()
        let lineSpace = stave.getSpacingBetweenLines()

        let start = staveNote.getModifierStartXY(position: position, index: checkIndex(), forceFlagRight: true)

        let x = start.x + xShift + modifierWidth - radius
        let y = start.y + yShift + dotShiftY * lineSpace

        ctx.beginPath()
        ctx.arc(x, y, radius, 0, Double.pi * 2, false)
        ctx.fill()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Dot", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q., D5/h., E5/q, F5/8.")
        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
