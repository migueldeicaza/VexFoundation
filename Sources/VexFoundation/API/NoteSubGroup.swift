// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Taehoon Moon 2016. MIT License.

import Foundation

// MARK: - NoteSubGroup

/// Formats and renders notes as a Modifier (e.g., ClefNote, TimeSigNote, BarNote).
public final class NoteSubGroup: Modifier {

    override public class var CATEGORY: String { "NoteSubGroup" }

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
