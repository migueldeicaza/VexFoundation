// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/kievannote.ts` (VexFlow 5.9.0).
// Timed Synodal Kievan half notes with native line and space forms.

import Foundation

/// The tse-fa-ut clef places C4 on the middle line of a five-line stave.
public struct KievanNoteStruct: Sendable {
    /// A natural written pitch such as `c/4`.
    public var pitch: String
    /// The duration string. Only an undotted half note is accepted.
    public var duration: String

    public init(pitch: String, duration: String) {
        self.pitch = pitch
        self.duration = duration
    }
}

/// Each historical glyph contains the full note, including its stem.
public final class KievanNote: GlyphNote {

    override public class var category: String { "KievanNote" }

    private let alternate = VexElement()

    /// Create a Kievan half note. Throws for a duration other than an undotted half note or for
    /// an invalid pitch (upstream throws a RangeError from the constructor).
    public init(_ spec: KievanNoteStruct) throws {
        let noteStruct = try NoteStruct(duration: spec.duration)
        super.init(glyph: Glyphs.kievanNoteHalfStaffLine, noteStruct: noteStruct)
        if Tables.sanitizeDuration(duration) != "2" || writtenDots != 0 || noteTypeValue != .note {
            throw VexError("BadArguments", "A Kievan half note requires an undotted half-note duration.")
        }
        try setPitch(spec.pitch)
    }

    /// Edit the written pitch without replacing the event or its tick context.
    @discardableResult
    public func setPitch(_ pitch: String) throws -> Self {
        guard isWrittenNaturalPitch(pitch) else {
            throw VexError("BadArguments", "Expected a natural written pitch such as c/4.")
        }
        let props = try Tables.keyProperties(pitch, clef: .kievan)
        keys = [pitch]
        keyProps = [props]
        // Note positions count up from the bottom. GlyphNote positions count down from the top.
        options.line = 5 - props.line
        let onLine = props.line.rounded() == props.line
        setGlyph(onLine ? Glyphs.kievanNoteHalfStaffLine : Glyphs.kievanNoteHalfStaffSpace)
        alternate.setText(onLine ? Glyphs.kievanNoteHalfStaffSpace : Glyphs.kievanNoteHalfStaffLine)
        if let stave { setYs([stave.getYForLine(options.line)]) }
        if preFormatted { preFormat() }
        return self
    }

    /// Keep native note anchors at the pitched glyph when a voice moves to a new stave.
    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        super.setStave(stave)
        return setYs([stave.getYForLine(options.line)])
    }

    /// Both choices occupy an equal attack slot, including after an edit and reformat.
    override public func preFormat() {
        super.preFormat()
        width = max(textMetrics.width, alternate.setFont(fontInfo).width)
    }
}
