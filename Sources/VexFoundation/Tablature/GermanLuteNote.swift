// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/germanlutenote.ts` (VexFlow 5.9.0).
// Staffless German Renaissance lute signs for the five principal courses.

import Foundation

/// A fretted attack. Course 1 is the highest course.
public struct GermanLuteNoteStruct: Sendable {
    public var course: Int
    public var fret: Int
    public var duration: String

    public init(course: Int, fret: Int, duration: String) {
        self.course = course
        self.fret = fret
        self.duration = duration
    }
}

/// SMuFL's German lowercase alphabet, by fret, reading from course 5 down to course 1.
private let germanSignsByFret: [[String]] = [
    [
        Glyphs.luteGermanALower,
        Glyphs.luteGermanBLower,
        Glyphs.luteGermanCLower,
        Glyphs.luteGermanDLower,
        Glyphs.luteGermanELower,
    ],
    [
        Glyphs.luteGermanFLower,
        Glyphs.luteGermanGLower,
        Glyphs.luteGermanHLower,
        Glyphs.luteGermanILower,
        Glyphs.luteGermanKLower,
    ],
    [
        Glyphs.luteGermanLLower,
        Glyphs.luteGermanMLower,
        Glyphs.luteGermanNLower,
        Glyphs.luteGermanOLower,
        Glyphs.luteGermanPLower,
    ],
    [
        Glyphs.luteGermanQLower,
        Glyphs.luteGermanRLower,
        Glyphs.luteGermanSLower,
        Glyphs.luteGermanTLower,
        Glyphs.luteGermanVLower,
    ],
    [Glyphs.luteGermanXLower, Glyphs.luteGermanYLower, Glyphs.luteGermanZLower],
]

/// Measure the tallest letter once per font through the shared text metrics cache.
private let germanPrincipalAlphabet = germanSignsByFret.flatMap { $0 }.joined()

/// Independent flags above each attack use the written duration.
private let germanRhythmSigns: [String: String] = [
    "1/2": Glyphs.luteDurationDoubleWhole,
    "1": Glyphs.luteDurationWhole,
    "2": Glyphs.luteDurationHalf,
    "4": Glyphs.luteDurationQuarter,
    "8": Glyphs.luteDuration8th,
    "16": Glyphs.luteDuration16th,
    "32": Glyphs.luteDuration32nd,
]

/// The sign for a course and fret, or nil when the principal courses have none.
private func germanSign(course: Int, fret: Int) -> String? {
    guard fret >= 1, fret <= germanSignsByFret.count else { return nil }
    let row = germanSignsByFret[fret - 1]
    let index = 5 - course
    guard index >= 0, index < row.count else { return nil }
    return row[index]
}

/// A timed letter below a rhythm sign. Use a Stave with zero lines and both barlines disabled.
public final class GermanLuteNote: Note {

    override public class var category: String { "GermanLuteNote" }

    private let rhythm = VexElement()
    private let rhythmSign: String
    private var rhythmOffset: Double = 0
    private var course: Int = 0
    private var fret: Int = 0

    /// Create an attack. Throws for a dotted duration, a duration outside double whole through
    /// 32nd, or a position without a sign (upstream throws a RangeError from the constructor).
    public init(_ spec: GermanLuteNoteStruct) throws {
        let noteStruct = try NoteStruct(duration: spec.duration)
        let sign = germanRhythmSigns[noteStruct.duration.value.rawValue]
        rhythmSign = sign ?? ""
        super.init(noteStruct)
        if sign == nil || writtenDots != 0 || noteTypeValue != .note {
            throw VexError(
                "BadArguments", "German lute attacks require an undotted duration from double whole through 32nd."
            )
        }
        try setPosition(spec.course, spec.fret)
    }

    /// Read the numeric position independently of the selected music font.
    public func getPosition() -> (course: Int, fret: Int) {
        (course: course, fret: fret)
    }

    /// Change the stopped course or fret, preserving the duration and tick context.
    @discardableResult
    public func setPosition(_ course: Int, _ fret: Int) throws -> Self {
        guard let sign = germanSign(course: course, fret: fret) else {
            throw VexError("BadArguments", "No principal-course German lute sign for course \(course), fret \(fret).")
        }
        self.course = course
        self.fret = fret
        text = sign
        if preFormatted { preFormat() }
        return self
    }

    /// Reserve the widest letter at this fret so course edits retain the same attack columns.
    override public func preFormat() {
        modifierContext?.preFormat()
        rhythm.setFont(fontInfo)
        var letterWidth: Double = 0
        for sign in germanSignsByFret[fret - 1] {
            letterWidth = max(letterWidth, rhythm.setText(sign).getWidth())
        }
        let ascent = rhythm.setText(germanPrincipalAlphabet).getTextMetrics().actualBoundingBoxAscent
        rhythm.setText(rhythmSign)
        rhythmOffset = ascent + rhythm.getTextMetrics().actualBoundingBoxDescent + fontSizeInPixels / 5
        width = max(letterWidth, rhythm.getWidth())
        preFormatted = true
    }

    /// Leave room for the tallest principal-course ascenders below the rhythm signs.
    private func rhythmY() -> Double {
        getYs()[0] - rhythmOffset + yShift
    }

    /// Both signs share the attack's horizontal anchor. Measure each one separately for hit testing.
    public func getInkParts() -> [BoundingBox] {
        let x = getAbsoluteX()
        return [getTextInk(x, getYs()[0]), rhythm.getTextInk(x + xShift, rhythmY())]
    }

    override public func getBoundingBox() -> BoundingBox? {
        let parts = getInkParts()
        var letter = parts[0]
        return letter.mergeWith(parts[1])
    }

    /// Draw all course letters on the stave's common baseline.
    override public func draw() throws {
        let ctx = try checkContext()
        let x = getAbsoluteX()
        setRendered()
        _ = ctx.openGroup("german-lute-note", getAttribute("id"))
        renderText(ctx, xPos: x, yPos: getYs()[0])
        rhythm.renderText(ctx, xPos: x + xShift, yPos: rhythmY())
        for modifier in modifiers {
            modifier.setContext(ctx)
            try modifier.drawWithStyle()
        }
        drawPointerRect()
        ctx.closeGroup()
    }
}
