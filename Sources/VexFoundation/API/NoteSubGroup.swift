// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Taehoon Moon 2016. MIT License.

import Foundation

// MARK: - NoteSubGroup

/// Formats and renders notes as a Modifier (e.g., ClefNote, TimeSigNote, BarNote).
public final class NoteSubGroup: Modifier {

    override public class var category: String { "NoteSubGroup" }

    // MARK: - Properties

    public let subNotes: [Note]
    private let voice: Voice
    private var formatter: Formatter
    private var groupPreFormatted: Bool = false

    // MARK: - Init

    public init(subNotes: [Note]) {
        self.subNotes = subNotes
        self.formatter = Formatter()
        self.voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setStrict(false)

        super.init()

        position = .left
        _ = setWidth(0)

        for subNote in subNotes {
            _ = subNote.setIgnoreTicks(false)
        }

        voice.addTickables(subNotes)
    }

    // MARK: - Static Format

    @discardableResult
    public static func format(
        _ groups: [NoteSubGroup],
        state: inout ModifierContextState
    ) -> Bool {
        if groups.isEmpty { return false }

        var width: Double = 0
        for group in groups {
            group.preFormat()
            width += group.getWidth()
        }

        state.leftShift += width
        return true
    }

    // MARK: - PreFormat

    public func preFormat() {
        if groupPreFormatted { return }
        _ = formatter.joinVoices([voice]).format([voice], justifyWidth: 0)
        _ = setWidth(formatter.getMinTotalWidth())
        groupPreFormatted = true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()
        alignSubNotesWithNote(subNotes, note)
        for subNote in subNotes {
            _ = subNote.setContext(ctx)
            try subNote.drawWithStyle()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("NoteSubGroup", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let clefNote = f.ClefNote(type: "bass", size: "small")
        let subGroup = f.NoteSubGroup(notes: [clefNote])

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(subGroup, index: 0)

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef("treble").addTimeSignature("4/4")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
