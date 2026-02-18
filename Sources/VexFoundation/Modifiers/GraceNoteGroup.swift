// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - GraceNoteGroup

/// Formats and renders a group of grace notes attached to a main note.
public final class GraceNoteGroup: Modifier {

    override public class var category: String { "GraceNoteGroup" }

    // MARK: - Properties

    public let graceNotes: [StemmableNote]
    public let showSlur: Bool
    private let voice: Voice
    private var formatter: Formatter?
    public var beams: [Beam] = []
    private var slur: StaveTie?
    public var slurYShift: Double = 0
    private var groupPreFormatted: Bool = false

    // MARK: - Init

    public init(graceNotes: [StemmableNote], showSlur: Bool = false) {
        self.graceNotes = graceNotes
        self.showSlur = showSlur

        self.voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setStrict(false)

        super.init()

        position = .left
        _ = setWidth(0)

        voice.addTickables(graceNotes)
    }

    // MARK: - Static Format

    @discardableResult
    public static func format(
        _ groups: [GraceNoteGroup],
        state: inout ModifierContextState
    ) -> Bool {
        let groupSpacingStave: Double = 4
        let groupSpacingTab: Double = 0

        if groups.isEmpty { return false }

        var groupList: [(shift: Double, group: GraceNoteGroup, spacing: Double)] = []
        var prevNote: Note?
        var shiftL: Double = 0

        for group in groups {
            let note = group.getNote()
            let isStaveNote = note is StaveNote
            let spacing = isStaveNote ? groupSpacingStave : groupSpacingTab

            if isStaveNote && note !== prevNote {
                for _ in 0..<note.keys.count {
                    shiftL = max(note.getLeftDisplacedHeadPx(), shiftL)
                }
                prevNote = note
            }

            groupList.append((shift: shiftL, group: group, spacing: spacing))
        }

        var groupShift = groupList[0].shift
        for item in groupList {
            item.group.preFormat()
            let formatWidth = item.group.getWidth() + item.spacing
            groupShift = max(formatWidth, groupShift)
        }

        for item in groupList {
            let formatWidth = item.group.getWidth() + item.spacing
            item.group.setSpacingFromNextModifier(
                groupShift - min(formatWidth, groupShift) + StaveNote.minNoteheadPadding
            )
        }

        state.leftShift += groupShift
        return true
    }

    // MARK: - PreFormat

    public func preFormat() {
        if groupPreFormatted { return }

        if formatter == nil {
            formatter = Formatter()
        }
        _ = formatter!.joinVoices([voice]).format([voice], justifyWidth: 0)
        _ = setWidth(formatter!.getMinTotalWidth())
        groupPreFormatted = true
    }

    // MARK: - Width

    override public func getWidth() -> Double {
        modifierWidth + StaveNote.minNoteheadPadding
    }

    // MARK: - Grace Notes

    public func getGraceNotes() -> [Note] {
        graceNotes
    }

    // MARK: - Beam Notes

    @discardableResult
    public func beamNotes(_ notes: [StemmableNote]? = nil) -> Self {
        let notesToBeam = notes ?? graceNotes
        if notesToBeam.count > 1 {
            let beam = Beam(notesToBeam)
            beam.renderOptions.beamWidth = 3
            beam.renderOptions.partialBeamLength = 4
            beams.append(beam)
        }
        return self
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        alignSubNotesWithNote(getGraceNotes(), note)

        // Draw grace notes
        for graceNote in graceNotes {
            _ = graceNote.setContext(ctx)
            try graceNote.draw()
        }

        // Draw beams
        for beam in beams {
            _ = beam.setContext(ctx)
            try beam.draw()
        }

        // Draw slur if requested
        if showSlur {
            let tieNotes = TieNotes(
                firstNote: note as? StaveNote,
                lastNote: graceNotes.first as? StaveNote,
                firstIndices: [0],
                lastIndices: [0]
            )
            let tie = StaveTie(notes: tieNotes)
            tie.renderOptions.cp2 = 12
            tie.renderOptions.yShift = 7 + slurYShift
            _ = tie.setContext(ctx)
            try tie.draw()
            slur = tie
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("GraceNoteGroup", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("E5/q, F5, G5, A5")
        let gn1 = f.GraceNote(GraceNoteStruct(keys: ["C/5"], duration: "16", slash: false))
        let gn2 = f.GraceNote(GraceNoteStruct(keys: ["D/5"], duration: "16", slash: false))
        let group = f.GraceNoteGroup(notes: [gn1, gn2], slur: true)
        _ = notes[0].addModifier(group, index: 0)

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef("treble")
            .addTimeSignature("4/4")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
