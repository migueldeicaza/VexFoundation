// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/dot.ts` (VexFlow 5.2.0).
// This class implements dot modifiers for notes.

import Foundation

// MARK: - Dot

/// Augmentation dot modifier. The dot is the `augmentationDot` glyph,
/// placed to the right of the notehead.
public final class Dot: Modifier {

    override public class var category: String { "Dot" }

    // MARK: - Properties

    public var dotShiftY: Double

    // MARK: - Static Helpers

    /// The dots of a note.
    public static func getDots(_ note: Note) -> [Dot] {
        note.getModifiersByType(Dot.category).compactMap { $0 as? Dot }
    }

    /// Add a dot to the specified keys of the notes.
    public static func buildAndAttach(_ notes: [Note], index: Int? = nil, all: Bool = false) {
        for note in notes {
            if all {
                for i in 0..<note.keys.count {
                    let dot = Dot()
                    note.addModifier(dot, index: i)
                }
            } else if let index {
                let dot = Dot()
                note.addModifier(dot, index: index)
            } else {
                let dot = Dot()
                note.addModifier(dot, index: 0)
            }
        }
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
            var noteId: String
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
                line = staveNote.getKeyProps()[index].line
                // Consider a right displaced head with no previous modifier.
                shift = staveNote.getFirstDotPx()
            } else {
                // TabNote: shim key props for dot placement.
                // Upstream throws 'Internal' for other note types; they use the same shim here.
                line = 0.5
                shift = rightShift
            }

            let noteId = note.getAttribute("id") ?? "\(ObjectIdentifier(note))"
            dotList.append(DotEntry(line: line, note: note, noteId: noteId, dot: dot))
            maxShiftMap[noteId] = max(maxShiftMap[noteId] ?? shift, shift)
        }

        // Sort dots by line number.
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
            let noteId = entry.noteId
            let line = entry.line

            // Reset the position of the dot every line.
            if line != lastLine || note !== lastNote {
                dotShift = maxShiftMap[noteId] ?? rightShift
            }

            if !note.isRest() && line != lastLine {
                if abs(line.truncatingRemainder(dividingBy: 1)) == 0.5 {
                    // note is on a space, so no dot shift
                    halfShiftY = 0
                } else {
                    // note is on a line, so shift dot to space above the line
                    halfShiftY = 0.5
                    if let ln = lastNote, !ln.isRest(), let ll = lastLine, ll - line == 0.5 {
                        // previous note on a space, so shift dot to space below the line
                        halfShiftY = -0.5
                    } else if let pds = prevDottedSpace, line + halfShiftY == pds {
                        // previous space is dotted, so shift dot to space below the line
                        halfShiftY = -0.5
                    }
                }
            }

            // Convert halfShiftY to a multiplier for dots.draw().
            if note.isRest() {
                dot.dotShiftY += -halfShiftY
            } else {
                dot.dotShiftY = -halfShiftY
            }
            prevDottedSpace = line + halfShiftY

            dot.setXShift(dotShift)
            dotShift += dot.getWidth() + dotSpacing // spacing
            xWidth = dotShift > xWidth ? dotShift : xWidth
            lastLine = line
            lastNote = note
        }

        // Update state.
        state.rightShift += xWidth
        return true
    }

    // MARK: - Init

    public override init() {
        dotShiftY = 0
        super.init()

        position = .right

        setText(Glyphs.augmentationDot)
        dotShiftY = 0
    }

    // MARK: - Note

    @discardableResult
    override public func setNote(_ note: Note) -> Self {
        self.note = note
        fontInfo = note.fontInfo
        return self
    }

    @discardableResult
    public func setDotShiftY(_ y: Double) -> Self {
        dotShiftY = y
        return self
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        let stave = note.checkStave()
        let lineSpace = stave.getSpacingBetweenLines()

        var start = note.getModifierStartXY(position: position, index: checkIndex(), forceFlagRight: true)

        // Set the starting y coordinate to the base of the stem for TabNotes.
        if let tabNote = note as? TabNote {
            start.y = tabNote.getStemExtents().baseY
        }

        x = start.x
        y = start.y + dotShiftY * lineSpace

        renderText(ctx, xPos: 0, yPos: 0)
    }
}
