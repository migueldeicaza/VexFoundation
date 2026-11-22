// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/repeatnote.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - RepeatNote

/// A note that renders bar repeat symbols.
public final class RepeatNote: GlyphNote {

    override public class var category: String { "RepeatNote" }

    /// Map `type` to the SMuFL glyph code.
    private static let CODES: [String: String] = [
        "1": Glyphs.repeat1Bar,
        "2": Glyphs.repeat2Bars,
        "4": Glyphs.repeat4Bars,
        "slash": Glyphs.repeatBarSlash,
    ]

    // MARK: - Init

    public init(type: String, noteStruct: NoteStruct? = nil, options: GlyphNoteOptions? = nil) {
        let glyphCode = RepeatNote.CODES[type] ?? "\u{E500}" /* repeat1Bar */

        // { duration: 'q', alignCenter: type !== 'slash', ...noteStruct }
        var ns = noteStruct ?? NoteStruct(duration: .quarter)
        if ns.alignCenter == nil {
            ns.alignCenter = type != "slash"
        }

        super.init(glyph: glyphCode, noteStruct: ns, options: options ?? GlyphNoteOptions())
    }
}
