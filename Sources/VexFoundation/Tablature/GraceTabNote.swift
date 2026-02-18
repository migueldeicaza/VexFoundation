// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Balazs Forian-Szabo. MIT License.

import Foundation

// MARK: - GraceTabNote

/// A grace note rendered on a tab stave with reduced scale.
public final class GraceTabNote: TabNote {

    override public class var category: String { "GraceTabNote" }

    // MARK: - Init

    public override init(_ noteStruct: TabNoteStruct, drawStem: Bool = false) {
        super.init(noteStruct, drawStem: false)

        renderOptions.yShift = 0.3
        renderOptions.scale = 0.6
        renderOptions.font = "7.5pt \(VexFont.SANS_SERIF)"

        updateWidth()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("GraceTabNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)

        let ts = f.TabStave(x: 10, y: 10, width: 490)
        _ = ts.addTabGlyph()

        let graceNote = GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 5)], duration: "8"))
        let mainNote = f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 7)], duration: "q"))
        let restNotes: [Note] = [
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 3, fret: 5)], duration: "q")),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: 3)], duration: "q")),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 2)], duration: "q")),
        ]

        let graceGroup = f.GraceNoteGroup(notes: [graceNote])
        _ = mainNote.addModifier(graceGroup, index: 0)

        let voice = f.Voice(timeSpec: "4/4")
        _ = voice.addTickables([mainNote] + restNotes)

        let formatter = f.Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 400)

        try? f.draw()
    }
    .padding()
}
#endif
