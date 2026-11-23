// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2026-present VexFlow contributors. MIT License.
//
// Port of `src/chantstave.ts` (VexFlow 5.9.0).
// Movable clefs, written pitches, and phrase divisions on a four-line square-chant stave.

import Foundation

/// A C clef marks written middle C. An F clef marks the F below it.
public enum ChantClef: String, Sendable {
    case c = "C"
    case f = "F"
}

/// `true` for a written chant pitch such as `c/4`, `bb/3` or `fn/4` (upstream
/// `/^[a-g](?:bb|##|b|#|n)?\/-?\d+$/i` and a safe-integer octave).
func isWrittenChantPitch(_ pitch: String) -> Bool {
    let parts = pitch.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 2, let first = parts[0].lowercased().first, ("a"..."g").contains(first) else {
        return false
    }
    let accidental = String(parts[0].lowercased().dropFirst())
    guard ["", "bb", "##", "b", "#", "n"].contains(accidental) else { return false }
    return isWrittenNaturalPitch("\(first)/\(parts[1])")
}

/// Render square chant and resolve pitches against the same movable clef.
///
/// Chant counts its four lines upwards, starting with 1 at the bottom.
open class ChantStave: Stave {
    private let chantClef: Clef

    /// Default to C on line three or F on line two. Chant uses explicit phrase endings.
    ///
    /// Without `options`, the stave has no left or right barline (upstream defaults
    /// `leftBar: false, rightBar: false`). Explicit `options` are used as given, with four lines.
    /// Throws for a line outside 1...4.
    public init(
        x: Double, y: Double, width: Double, clef: ChantClef = .c, line: Int? = nil, options: StaveOptions? = nil
    ) throws {
        var staveOptions = options ?? StaveOptions(leftBar: false, rightBar: false)
        staveOptions.numLines = 4
        staveOptions.clef = nil
        chantClef = Clef(type: .chantC)
        super.init(x: x, y: y, width: width, options: staveOptions)
        addModifier(chantClef)
        try setChantClef(clef, line: line ?? (clef == .c ? 3 : 2))
    }

    /// Replace the clef in place. The next layout uses its new width and pitch anchor.
    @discardableResult
    public func setChantClef(_ clef: ChantClef, line: Int) throws -> Self {
        if line < 1 || line > 4 {
            throw VexError("BadArguments", "Expected a chant C or F clef on line 1 through 4.")
        }
        clefName = clef == .c ? .chantC : .chantF
        chantClef.setType(clefName)
        chantClef.line = Double(4 - line)
        // One SMuFL em spans four staff spaces, including on enlarged staves.
        chantClef.setFontSize("\(formatJSNumber(4 * getSpacingBetweenLines()))px")
        formatted = false
        return self
    }

    /// Return the drawing line from the top. Neighboring written pitches are half a space apart.
    public func getLineForPitch(_ pitch: String) throws -> Double {
        guard isWrittenChantPitch(pitch) else {
            throw VexError("BadArguments", "Expected a written chant pitch such as c/4.")
        }
        let anchor = chantClef.code == Glyphs.chantCclef ? "c/4" : "f/3"
        return chantClef.line + (try Tables.keyProperties(anchor).line) - (try Tables.keyProperties(pitch).line)
    }

    /// Return the written pitch's y coordinate in this stave.
    public func getYForPitch(_ pitch: String) throws -> Double {
        getYForLine(try getLineForPitch(pitch))
    }
}

/// The four phrase endings in order from the shortest pause to the end of a piece.
public enum ChantDivisionKind: String, Sendable, CaseIterable {
    case minima, maior, maxima, finalis

    var glyph: String {
        switch self {
        case .minima: return Glyphs.chantDivisioMinima
        case .maior: return Glyphs.chantDivisioMaior
        case .maxima: return Glyphs.chantDivisioMaxima
        case .finalis: return Glyphs.chantDivisioFinalis
        }
    }
}

/// Chant divisions reserve horizontal ink in a Voice without consuming musical time.
public final class ChantDivision: GlyphNote {

    /// All four SMuFL glyphs share the center of the four-line staff as their origin.
    public init(_ kind: ChantDivisionKind) {
        super.init(
            glyph: kind.glyph,
            noteStruct: NoteStruct(duration: .twoFiftySixth),
            options: GlyphNoteOptions(ignoreTicks: true, line: 1.5)
        )
    }

    /// Change the mark in place while preserving its position in the voice.
    @discardableResult
    public func setKind(_ kind: ChantDivisionKind) -> Self {
        setGlyph(kind.glyph)
    }

    /// Size the strokes to the actual staff spacing so maxima and finalis reach both outer lines.
    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        super.setStave(stave)
        setFontSize("\(formatJSNumber(4 * stave.getSpacingBetweenLines()))px")
        return self
    }
}
