// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - RepeatNote

/// A note that renders bar repeat symbols.
public final class RepeatNote: GlyphNote {

    override public class var category: String { "RepeatNote" }

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
            duration: .quarter,
            alignCenter: type != "slash"
        )

        super.init(glyph: glyph, noteStruct: ns, options: options ?? GlyphNoteOptions())
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("RepeatNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(score.notes("C5/q, D5, E5, F5"))]
        )).addClef(.treble)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
