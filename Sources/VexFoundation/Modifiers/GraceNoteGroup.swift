// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/gracenotegroup.ts` (VexFlow 5.6.0). `GraceNoteGroup` is used
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

    /// Right-side material at the same onset must not move a before-grace cluster to the left. (VexFlow 5.3.0)
    private var afterWidth: Double = 0
    private var afterOffset: Double = 0

    /// Opposing groups reserve their own side. Voices with simultaneous before-graces align at the host.
    @discardableResult
    public static func format(
        _ groups: [GraceNoteGroup],
        state: inout ModifierContextState
    ) -> Bool {
        if groups.isEmpty { return false }
        let entries = groups.map { group -> (group: GraceNoteGroup, note: Note, width: Double, after: Bool) in
            group.preFormat()
            let note = group.getNote()
            let width = group.getWidth() + (note is StaveNote ? 4 : 0)
            return (group, note, width, group.position == .right)
        }
        let afterWidth = entries.filter { $0.after }.map { $0.width }.reduce(0, max)
        let beforeWidth = entries.filter { !$0.after }
            .map { max($0.width, $0.note.getLeftDisplacedHeadPx()) }.reduce(0, max)
        for entry in entries {
            entry.group.afterWidth = afterWidth
            entry.group.afterOffset = entry.note.getGlyphWidth() + entry.note.getRightDisplacedHeadPx()
                + state.rightShift + StaveNote.minNoteheadPadding
            entry.group.setSpacingFromNextModifier(
                (entry.after ? 0 : beforeWidth - entry.width) + StaveNote.minNoteheadPadding
            )
        }
        state.leftShift += beforeWidth
        state.rightShift += afterWidth
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

    /// Position grace notes after the parent has been formatted and assigned a stave. (VexFlow 5.1.0)
    private func positionGraceNotes() throws {
        let note = try checkAttachedNoteThrowing()
        _ = try note.checkStaveThrowing()
        preFormat()
        alignSubNotesWithNote(getGraceNotes(), note, position: position)
        // VexFlow 5.6.0: tab fret numbers extend left of their tick. A before-grace must clear that edge as well.
        let fretOverhang = note is TabNote ? note.getLeftDisplacedHeadPx() : 0
        if afterWidth != 0 || fretOverhang != 0 {
            for grace in graceNotes {
                let tick = grace.getTickContext()
                tick.setXOffset(
                    position == .right
                        ? note.getTickContext().getX() + afterOffset
                        : tick.getXOffset() + afterWidth - fretOverhang
                )
            }
        }
        beams.forEach { $0.postFormat() }
    }

    /// Enclose the positioned grace notes (not the slur). Drawing is not required. (VexFlow 5.1.0)
    override public func getBoundingBox() -> BoundingBox? {
        if graceNotes.isEmpty { return super.getBoundingBox() }
        guard (try? positionGraceNotes()) != nil else { return super.getBoundingBox() }
        var boundingBox = graceNotes[0].getBoundingBox()
        for graceNote in graceNotes.dropFirst() {
            guard let bb = graceNote.getBoundingBox() else { continue }
            if boundingBox == nil { boundingBox = bb } else { boundingBox?.mergeWith(bb) }
        }
        return boundingBox
    }

    /// Positioned components, including the optional slur, shared with geometry consumers. (VexFlow 5.3.0)
    public func getLayoutElements() throws -> [VexElement] {
        let note = try checkAttachedNoteThrowing()
        try positionGraceNotes()
        if showSlur && !graceNotes.isEmpty {
            // Keep one slur for the current pair of endpoints. A native caller may reattach this group.
            let isStavenote = note is StaveNote
            let after = position == .right
            let end = after ? graceNotes[graceNotes.count - 1] : graceNotes[0]
            if slur?.getNotes().firstNote !== note || slur?.getNotes().lastNote !== end {
                let tieNotes = TieNotes(firstNote: note, lastNote: end, firstIndexes: [0], lastIndexes: [0])
                slur = isStavenote ? StaveTie(notes: tieNotes) : TabTie(notes: tieNotes)
            }
            if let slur {
                // A normal tie starts beyond all right modifiers, including this group.
                // Opposing slurs start at opposite edges of the same host head.
                if afterWidth != 0, let host = note as? StaveNote {
                    let hostEdge = host.getNoteHeadBeginX() + (after ? host.getGlyphWidth() : 0)
                    slur.renderOptions.firstXShift = hostEdge - host.getTieRightX()
                } else {
                    slur.renderOptions.firstXShift = 0
                }
                slur.renderOptions.cp2 = 12
                slur.renderOptions.yShift = (isStavenote ? 7 : 5) + renderOptions.slurYShift
            }
        }
        var elements: [VexElement] = graceNotes
        elements.append(contentsOf: beams as [VexElement])
        if let slur { elements.append(slur) }
        return elements
    }

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        for element in try getLayoutElements() {
            try element.setContext(ctx).drawWithStyle()
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
