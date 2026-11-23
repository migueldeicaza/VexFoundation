// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/continuousbeam.ts` (VexFlow 5.7.0).
// Keep a native beam's complete membership while fitting independent beam strips at system breaks.

import Foundation

/// One attack of a continuous beam and its source measure (from zero).
struct ContinuousBeamMember {
    let note: StaveNote
    let measure: Int
}

private func badScore(_ message: String) -> VexError {
    VexError("BadContinuousScore", message)
}

/// Resolve an inclusive interval of the same voice on the same staff, in score order.
func beamMembers(
    _ notes: [[[[Tickable]]]], _ staves: [[Stave]], _ from: SpanAnchor, _ to: SpanAnchor
) throws -> [ContinuousBeamMember] {
    let voice = notes[from.measure][from.staff].firstIndex { group in group.contains { $0 === from.note } }
    guard let voice, from.staff == to.staff,
          voice < notes[to.measure][to.staff].count,
          notes[to.measure][to.staff][voice].contains(where: { $0 === to.note })
    else { throw badScore("Beam anchors must belong to the same staff and voice.") }
    var members: [ContinuousBeamMember] = []
    for i in from.measure...to.measure {
        let parts = notes[i][from.staff]
        guard voice < parts.count, !parts[voice].isEmpty else {
            throw badScore("The beam voice is missing a measure.")
        }
        let measureNotes = parts[voice]
        let start = i == from.measure ? measureNotes.firstIndex { $0 === from.note } ?? 0 : 0
        let end = i == to.measure ? (measureNotes.firstIndex { $0 === to.note } ?? -1) + 1 : measureNotes.count
        for tickable in measureNotes[start..<max(start, end)] {
            if tickable.shouldIgnoreTicks() { continue }
            guard let note = tickable as? StaveNote, !note.isRest(), note.getBeamCount() != 0,
                  note.getStave() === staves[i][from.staff]
            else { throw badScore("Expected consecutive beamable pitched notes on one staff.") }
            members.append(ContinuousBeamMember(note: note, measure: i))
        }
    }
    if members.count < 2 { throw badScore("A beam needs at least two attacks.") }
    var directions: [StemDirection] = []
    for member in members where !member.note.isAutoStem() {
        let direction = member.note.getStemDirection()
        if !directions.contains(direction) { directions.append(direction) }
    }
    if directions.count > 1 { throw badScore("Beam stems must agree in direction.") }
    return members
}

/// The source beam owns each note for the lifetime of the composition. Only the row pieces draw.
public final class ContinuousBeam: Beam {
    private let members: [ContinuousBeamMember]
    // Reuse pieces for a given pair of cut points so a retained resize preserves IDs and registry entries.
    private var cache: [String: Beam] = [:]
    private var placed: [Beam] = []
    private var complete = false

    init(_ members: [ContinuousBeamMember]) throws {
        self.members = members
        let notes: [StemmableNote] = members.map { $0.note }
        let fixed = notes.first { !$0.isAutoStem() }
        if let fixed {
            for n in notes where n.isAutoStem() { n.setStemDirection(fixed.getStemDirection(), autoStem: true) }
        }
        try super.init(notes, autoStem: fixed == nil)
    }

    /// An individual measure has incomplete coordinates. The row layout initiates each native fit.
    override public func postFormat() {}

    /// Release the previous row fits before the next pass through the score.
    func clearRows() {
        placed.forEach { $0.resetLayout() }
        placed = []
        complete = false
    }

    /// Expose the completed geometry after every measure has its final position.
    func finishRows() {
        complete = true
    }

    /// Return final draw geometry to callers after all participating measures have settled.
    override public func getStripBounds() -> [BoundingBox] {
        complete ? placed.flatMap { $0.getStripBounds() } : []
    }

    override public func getBoundingBox() -> BoundingBox? {
        let empty = BoundingBox(0, 0, 0, 0)
        if !complete || placed.isEmpty { return empty }
        var box: BoundingBox?
        for piece in placed {
            guard let b = piece.getBoundingBox() else { continue }
            if box == nil { box = b } else { box?.mergeWith(b) }
        }
        return box ?? empty
    }

    /// A possible break can leave one note on a row. Its actual neighbor determines the continuing levels.
    private func fitPiece(_ first: Int, _ last: Int) throws -> Beam {
        guard let start = members.firstIndex(where: { $0.measure >= first }) else {
            throw badScore("A beam piece needs a member on its row.")
        }
        let pieceMembers = members[start...].filter { $0.measure <= last }
        let end = start + pieceMembers.count
        let key = "\(start)-\(end)"
        guard let left = pieceMembers.first?.note, let right = pieceMembers.last?.note else {
            throw badScore("A beam piece needs a member on its row.")
        }
        let piece: Beam
        if let cached = cache[key] {
            piece = cached
        } else {
            let before = start > 0 ? members[start - 1].note : nil
            let after = end < members.count ? members[end].note : nil
            // Both ends of a system cut share one position in the logical fan, halfway between the two attacks.
            func progressAtCut(_ index: Int) -> Double { (Double(index) - 0.5) / Double(members.count - 1) }
            let edges = BeamContinuation(
                left: before.map { .init(x: 0, levels: $0.getBeamCount(), progress: progressAtCut(start)) },
                right: after.map { .init(x: 0, levels: $0.getBeamCount(), progress: progressAtCut(end)) }
            )
            let notes: [StemmableNote] = pieceMembers.map { $0.note }
            piece = try Beam(notes, autoStem: false, continuation: edges)
            // The local renderer uses the same stems, while getBeam() continues to expose the full source group.
            notes.forEach { $0.setBeam(self) }
            cache[key] = piece
        }
        if piece.continuation?.left != nil {
            piece.continuation?.left?.x = left.getStemX() - left.checkStave().space(1.25)
        }
        if piece.continuation?.right != nil {
            piece.continuation?.right?.x = right.checkStave().getNoteEndX() - 2
        }
        piece.renderOptions = renderOptions
        piece.postFormat()
        return piece
    }

    /// Fit the stems before the row measures its vertical ink. The caller releases this provisional fit.
    func measureRow(_ first: Int, _ last: Int) throws -> Beam {
        try fitPiece(first, last)
    }

    /// Fit the final positions and report the same outer edge that will be drawn for this fragment.
    func placeRow(_ first: Int, _ last: Int, _ row: Int, _ id: String) throws -> SpanFragment {
        let beam = try fitPiece(first, last)
        placed.append(beam)
        let notes = beam.getNotes()
        let firstStem = notes[0].getStemX()
        let edges = beam.continuation
        let x1 = edges?.left?.x ?? firstStem
        let x2 = edges?.right?.x ?? notes[notes.count - 1].getStemX()
        func y(_ x: Double) -> Double { beam.getSlopeY(x, firstStem, beam.getBeamYToDraw(), beam.slope) }
        let part: SpanFragmentPart = edges?.left != nil
            ? (edges?.right != nil ? .middle : .last)
            : (edges?.right != nil ? .first : .single)
        return SpanFragment(
            id: id,
            kind: .beam,
            row: row,
            part: part,
            x1: x1,
            x2: x2,
            y1: y(x1),
            y2: y(x2),
            progress: (0, 1),
            above: beam.getStemDirection().signDouble > 0,
            space: notes[0].checkStave().space(1)
        )
    }

    override public func draw() throws {
        let ctx = try checkContext()
        for piece in placed { try piece.setContext(ctx).drawWithStyle() }
        setRendered()
    }
}
