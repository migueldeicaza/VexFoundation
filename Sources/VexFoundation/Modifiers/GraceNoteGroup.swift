// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/gracenotegroup.ts` (VexFlow 5.0.0). `GraceNoteGroup` is used
// to format and render grace notes.

import Foundation

/// Render options for `GraceNoteGroup`.
public struct GraceNoteGroupRenderOptions {
    public var slurYShift: Double

    public init(slurYShift: Double = 0) {
        self.slurYShift = slurYShift
    }
}

// MARK: - GraceNoteGroup

/// GraceNoteGroup is used to format and render grace notes.
public final class GraceNoteGroup: Modifier {

    override public class var category: String { "GraceNoteGroup" }

    // MARK: - Properties

    public let graceNotes: [StemmableNote]
    public let showSlur: Bool
    private let voice: Voice
    private var preFormatted: Bool = false
    private var formatter: Formatter?
    public var renderOptions: GraceNoteGroupRenderOptions
    public private(set) var slur: StaveTie?
    public var beams: [Beam]

    @available(*, deprecated, message: "Use renderOptions.slurYShift.")
    public var slurYShift: Double {
        get { renderOptions.slurYShift }
        set { renderOptions.slurYShift = newValue }
    }

    // MARK: - Static Format

    /// Arranges groups inside a `ModifierContext`.
    @discardableResult
    public static func format(
        _ gracenoteGroups: [GraceNoteGroup],
        state: inout ModifierContextState
    ) -> Bool {
        let groupSpacingStave: Double = 4
        let groupSpacingTab: Double = 0

        if gracenoteGroups.isEmpty { return false }

        var groupList: [(shift: Double, gracenoteGroup: GraceNoteGroup, spacing: Double)] = []
        var prevNote: Note?
        var shift: Double = 0

        for gracenoteGroup in gracenoteGroups {
            let note = gracenoteGroup.getNote()
            let isStavenote = note is StaveNote
            let spacing = isStavenote ? groupSpacingStave : groupSpacingTab

            if isStavenote && note !== prevNote {
                // Iterate through all notes to get the displaced pixels
                for _ in 0..<note.keys.count {
                    shift = max(note.getLeftDisplacedHeadPx(), shift)
                }
                prevNote = note
            }

            groupList.append((shift: shift, gracenoteGroup: gracenoteGroup, spacing: spacing))
        }

        // If first note left shift in case it is displaced
        var groupShift = groupList[0].shift
        var formatWidth: Double
        var right = false
        var left = false
        for item in groupList {
            let gracenoteGroup = item.gracenoteGroup
            if gracenoteGroup.position == .right {
                right = true
            } else {
                left = true
            }
            gracenoteGroup.preFormat()
            formatWidth = gracenoteGroup.getWidth() + item.spacing
            groupShift = max(formatWidth, groupShift)
        }

        for item in groupList {
            let gracenoteGroup = item.gracenoteGroup
            formatWidth = gracenoteGroup.getWidth() + item.spacing
            gracenoteGroup.setSpacingFromNextModifier(
                groupShift - min(formatWidth, groupShift) + StaveNote.minNoteheadPadding
            )
        }

        if right { state.rightShift += groupShift }
        if left { state.leftShift += groupShift }
        return true
    }

    // MARK: - Init

    /// `GraceNoteGroup` inherits from `Modifier` and is placed inside a `ModifierContext`.
    public init(graceNotes: [StemmableNote], showSlur: Bool = false) {
        self.graceNotes = graceNotes
        self.showSlur = showSlur
        slur = nil

        voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4, resolution: Tables.RESOLUTION))
        _ = voice.setStrict(false)

        renderOptions = GraceNoteGroupRenderOptions(slurYShift: 0)

        beams = []

        super.init()

        position = .left
        width = 0

        voice.addTickables(graceNotes)
    }

    // MARK: - PreFormat

    public func preFormat() {
        if preFormatted { return }

        if formatter == nil {
            formatter = Formatter()
        }
        guard let formatter else { return }
        _ = formatter.joinVoices([voice]).format([voice], justifyWidth: 0)
        _ = setWidth(formatter.getMinTotalWidth())
        preFormatted = true
    }

    // MARK: - Beam Notes

    @discardableResult
    public func beamNotes(_ graceNotes: [StemmableNote]? = nil) -> Self {
        let graceNotes = graceNotes ?? self.graceNotes
        if graceNotes.count > 1, let beam = try? Beam(graceNotes) {
            beam.renderOptions.beamWidth = 3
            beam.renderOptions.partialBeamLength = 4

            beams.append(beam)
        }

        return self
    }

    // MARK: - Width

    @discardableResult
    override public func setWidth(_ width: Double) -> Self {
        self.width = width
        return self
    }

    override public func getWidth() -> Double {
        width + StaveNote.minNoteheadPadding
    }

    // MARK: - Grace Notes

    public func getGraceNotes() -> [Note] {
        graceNotes
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()

        alignSubNotesWithNote(getGraceNotes(), note, position: position) // Modifier function

        // Draw grace notes.
        for graceNote in graceNotes {
            try graceNote.setContext(ctx).drawWithStyle()
        }
        // Draw beams.
        for beam in beams {
            try beam.setContext(ctx).drawWithStyle()
        }

        if showSlur {
            // Create and draw slur.
            let isStavenote = note is StaveNote
            let tieNotes = TieNotes(
                firstNote: note,
                lastNote: graceNotes.first,
                firstIndexes: [0],
                lastIndexes: [0]
            )
            let slur: StaveTie = isStavenote ? StaveTie(notes: tieNotes) : TabTie(notes: tieNotes)
            self.slur = slur

            slur.renderOptions.cp2 = 12
            slur.renderOptions.yShift = (isStavenote ? 7 : 5) + renderOptions.slurYShift
            try slur.setContext(ctx).drawWithStyle()
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

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("E5/q, F5, G5, A5")
        let gn1 = f.GraceNote(GraceNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 5)),
            duration: .sixteenth,
            slash: false
        ))
        let gn2 = f.GraceNote(GraceNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 5)),
            duration: .sixteenth,
            slash: false
        ))
        let group = f.GraceNoteGroup(notes: [gn1, gn2], slur: true)
        _ = notes[0].addModifier(group, index: 0)

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
