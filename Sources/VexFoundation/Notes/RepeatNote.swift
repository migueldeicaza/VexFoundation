// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - RepeatNote

/// A note that renders bar repeat symbols.
public final class RepeatNote: GlyphNote {

    override public class var CATEGORY: String { "RepeatNote" }

    // MARK: - Repeat Codes

    private static let codes: [String: String] = [
        "1": "repeat1Bar",
        "2": "repeat2Bars",
        "4": "repeat4Bars",
        "slash": "repeatBarSlash",
    ]

    // MARK: - Init

    public init(type: String, noteStruct: NoteStruct? = nil, options: GlyphNoteOptions? = nil) {
        let code = RepeatNote.codes[type] ?? "repeat1Bar"
        let point = (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("repeatNote.point") as? Double) ?? 40
        let glyph = Glyph(code: code, point: point, options: GlyphOptions(category: "repeatNote"))

        let ns = noteStruct ?? NoteStruct(
            duration: "q",
            alignCenter: type != "slash"
        )

        super.init(glyph: glyph, noteStruct: ns, options: options ?? GlyphNoteOptions())
    }
}
