// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tabtie.ts` (VexFlow 5.6.0).

import Foundation

// MARK: - TabTie

/// Implements ties between contiguous tab notes including regular ties,
/// hammer ons, pull offs, and slides.
open class TabTie: StaveTie {

    override open class var category: String { "TabTie" }

    // MARK: - Factory Methods

    public static func createHammeron(notes: TieNotes) -> TabTie {
        TabTie(notes: notes, text: "H")
    }

    public static func createPulloff(notes: TieNotes) -> TabTie {
        TabTie(notes: notes, text: "P")
    }

    // MARK: - Init

    /// - Parameters:
    ///   - notes: `firstNote`, `lastNote`, `firstIndexes` and `lastIndexes`.
    ///   - text: The tie text, for example "H" or "P".
    public override init(notes: TieNotes, text: String? = nil) {
        super.init(notes: notes, text: text)
        // VexFlow 5.6.0: a one-letter tab technique has a distinct face from a written direction or a slide
        // abbreviation.
        if let text, text.count == 1, let c = text.unicodeScalars.first, c.isASCII,
           CharacterSet.letters.contains(c) {
            setFont(Metrics.getFontInfo("TabTie.techniqueLetter"))
        }
        renderOptions.cp1 = 9
        renderOptions.cp2 = 11
        renderOptions.yShift = 3
        direction = .down // Tab ties are always face up (-1).
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TabTie", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)

        let ts = f.TabStave(x: 10, y: 10, width: 490)
        _ = ts.addTabGlyph()

        let notes: [TabNote] = [
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 5)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 7)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 7)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 5)], duration: .quarter)),
        ]

        let voice = f.Voice(timeSignature: .meter(4, 4))
        _ = voice.addTickables(notes)

        let formatter = f.Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 400)

        let hammeron = TabTie(notes: TieNotes(firstNote: notes[0], lastNote: notes[1], firstIndexes: [0], lastIndexes: [0]), text: "H")
        _ = hammeron.setContext(ctx)

        let pulloff = TabTie(notes: TieNotes(firstNote: notes[2], lastNote: notes[3], firstIndexes: [0], lastIndexes: [0]), text: "P")
        _ = pulloff.setContext(ctx)

        try? f.draw()
        try? hammeron.draw()
        try? pulloff.draw()
    }
    .padding()
}
#endif
