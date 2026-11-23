// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/easyscore/policies.ts` (VexFlow 5.3.0).
// Opt-in accidental generation preserves written pitches and explicit native decorations.

import Foundation

/// Inline signature changes use exact tick onsets shared by all voices on a stave.
struct EasyScoreKeyChange {
    var at: Fraction
    var key: String
}

/// Grace attacks in different voices align at the host end of a before-group
/// and at the beginning of an after-group. They never advance the voice clock. (VexFlow 5.3.0)
private func orderedAttacks(_ hosts: [StaveNote], _ includeGrace: Bool) -> [[StaveNote]] {
    var attacks: [Int: [StaveNote]] = [0: hosts.filter { !$0.isRest() }]
    if includeGrace {
        for host in hosts {
            for case let group as GraceNoteGroup in host.getModifiers() {
                let notes = group.getGraceNotes()
                for (i, note) in notes.enumerated() {
                    guard let note = note as? StaveNote, !note.isRest() else { continue }
                    let offset = group.getPosition() == .right ? i + 1 : i - notes.count
                    attacks[offset, default: []].append(note)
                }
            }
        }
    }
    return attacks.keys.sorted().compactMap { attacks[$0] }
}

/// Each onset is evaluated against one prior state, so voice ordering cannot change accidental output.
func applyCompositionAccidentals(
    _ score: EasyScore,
    _ voices: [Voice],
    _ key: String,
    _ changes: [EasyScoreKeyChange],
    _ generated: Set<ObjectIdentifier>,
    _ stave: Stave,
    _ includeGrace: Bool = false
) throws {
    let music = Music()
    var scale = try music.createScaleMap(key)
    var state: [String: String] = [:]
    var positionOrder: [String] = []
    var positions: [String: (at: Fraction, notes: [StaveNote])] = [:]
    for voice in voices {
        let at = Fraction(0, 1)
        for note in voice.getTickables() {
            if note.shouldIgnoreTicks() { continue }
            let id = at.clone().simplify().description
            var group = positions[id] ?? (at.clone(), [])
            if positions[id] == nil { positionOrder.append(id) }
            if let staveNote = note as? StaveNote, staveNote.getStave() === stave {
                group.notes.append(staveNote)
            }
            positions[id] = group
            at.add(note.getTicks())
        }
    }
    /// Resolve each pitch against the same prior state before committing the whole attack.
    func applyAttack(_ notes: [StaveNote]) throws {
        func parts(_ written: String) throws -> (root: String, accidental: String, id: String) {
            let pieces = written.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            let noteParts = try music.getNoteParts(pieces.first ?? "")
            let octave = pieces.count > 1 ? pieces[1] : ""
            return (noteParts.root, noteParts.accidental ?? "n", "\(noteParts.root)/\(octave)")
        }
        var simultaneous: [String: Set<String>] = [:]
        for note in notes {
            for written in note.getKeys() {
                let p = try parts(written)
                simultaneous[p.id, default: []].insert(p.accidental)
            }
        }
        var updateOrder: [String] = []
        var updates: [String: Set<String>] = [:]
        for note in notes {
            for (index, written) in note.getKeys().enumerated() {
                let p = try parts(written)
                let pitch = p.root + p.accidental
                let previous = state[p.id] ?? scale[p.root]
                // Only ordinary parser-generated marks can be suppressed. Native/cautionary/microtonal marks stay.
                let marks = note.getModifiers().compactMap { $0 as? Accidental }.filter { $0.getIndex() == index }
                let explicit = marks.filter { mark in
                    !generated.contains(ObjectIdentifier(mark)) || mark.isCautionary()
                        || !Music.accidentals.contains(mark.type)
                }
                for mark in marks where !explicit.contains(where: { $0 === mark }) {
                    note.modifiers.removeAll { $0 === mark }
                }
                if explicit.isEmpty && (previous != pitch || (simultaneous[p.id]?.count ?? 0) > 1) {
                    try score.attach(note, try score.make.accidental(type: p.accidental), index: index)
                }
                // Microtonal spellings have no native key-string representation. Force a fresh sign next time.
                let value = explicit.contains { !Music.accidentals.contains($0.type) } ? "microtonal" : pitch
                if updates[p.id] == nil { updateOrder.append(p.id) }
                updates[p.id, default: []].insert(value)
            }
        }
        // Conflicting simultaneous spellings require an explicit sign on the next occurrence.
        for id in updateOrder {
            guard let values = updates[id] else { continue }
            state[id] = values.count == 1 ? values.first : "ambiguous"
        }
    }

    var changeIndex = 0
    let sorted = positionOrder.compactMap { positions[$0] }.sorted { $0.at.lessThan($1.at) }
    for group in sorted {
        while changeIndex < changes.count && !changes[changeIndex].at.greaterThan(group.at) {
            scale = try music.createScaleMap(changes[changeIndex].key)
            changeIndex += 1
            state.removeAll()
        }
        for notes in orderedAttacks(group.notes, includeGrace) { try applyAttack(notes) }
    }
}
