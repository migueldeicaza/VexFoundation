// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/frenchlutenote.ts` (VexFlow 5.9.0).
// French Renaissance lute letters and diapasons, derived from sounding course and fret.

import Foundation

/// The Renaissance alphabet omits j. SMuFL defines twelve fretted letters after open a.
private let frenchFretLetters = [
    Glyphs.luteFrenchFretA,
    Glyphs.luteFrenchFretB,
    Glyphs.luteFrenchFretC,
    Glyphs.luteFrenchFretD,
    Glyphs.luteFrenchFretE,
    Glyphs.luteFrenchFretF,
    Glyphs.luteFrenchFretG,
    Glyphs.luteFrenchFretH,
    Glyphs.luteFrenchFretI,
    Glyphs.luteFrenchFretK,
    Glyphs.luteFrenchFretL,
    Glyphs.luteFrenchFretM,
    Glyphs.luteFrenchFretN,
]

/// Open basses below the six ruled courses use a, /a, //a and ///a.
private let frenchOpenBassSigns = [
    Glyphs.luteFrench7thCourse,
    Glyphs.luteFrench8thCourse,
    Glyphs.luteFrench9thCourse,
    Glyphs.luteFrench10thCourse,
]

/// French lute tablature on a six-line TabStave. Signs sit directly above their course.
///
/// Course 1 is the top course. A numeric fret of zero sounds the open course. Courses 7 to 10
/// are open diapasons.
public final class FrenchLuteNote: TabNote {

    override public class var category: String { "FrenchLuteNote" }

    /// Create a note. Throws for a course outside 1...10, a fret outside 0...12, a non-numeric fret,
    /// or a stopped diapason (upstream throws from the constructor).
    public init(validating noteStruct: TabNoteStruct, drawStem: Bool = false) throws {
        for position in noteStruct.positions {
            try FrenchLuteNote.validate(position)
        }
        super.init(noteStruct, drawStem: drawStem)
        // A French letter rests on a continuous course line at the music font's baseline.
        clearFretLines = false
    }

    private static func validate(_ position: TabNotePosition) throws {
        let str = position.str
        if str < 1 || str > 6 + frenchOpenBassSigns.count {
            throw VexError("BadArguments", "French lute courses must be integers from 1 to 10.")
        }
        guard let fret = Int(position.fret), String(fret) == position.fret, fret >= 0,
              fret < frenchFretLetters.count else {
            throw VexError("BadArguments", "French lute frets must be integers from 0 to 12.")
        }
        if str > 6 && fret != 0 {
            throw VexError("BadArguments", "French lute diapasons must be open.")
        }
    }

    /// Keep the original sounding position and measure its music glyph for the formatter.
    override public func createFretElement(_ position: TabNotePosition) -> VexElement {
        let fret = Int(position.fret) ?? 0
        let sign = position.str <= 6
            ? frenchFretLetters[min(max(fret, 0), frenchFretLetters.count - 1)]
            : frenchOpenBassSigns[min(max(position.str - 7, 0), frenchOpenBassSigns.count - 1)]
        let text = ghost ? Glyphs.accidentalParensLeft + sign + Glyphs.accidentalParensRight : sign
        return VexElement(category: FrenchLuteNote.category).setFont(fontInfo).setText(text)
    }

    /// A single bass uses a common row. Stack simultaneous diapasons in course order.
    override public func getFretLine(_ position: TabNotePosition) -> Double {
        if position.str <= 6 { return Double(position.str - 1) }
        let bassesAbove = positions.filter { $0.str > 6 && $0.str < position.str }.count
        return 6.5 + 1.5 * Double(bassesAbove)
    }
}
