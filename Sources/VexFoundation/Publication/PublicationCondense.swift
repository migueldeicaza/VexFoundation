// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/publicationcondense.ts` (VexFlow 5.8.0).
// Derive a conductor staff from two monophonic parts while preserving the original rhythmic voices.

import Foundation

/// Players are ordered by desk number. Optional passage boundaries are inclusive source measure numbers.
/// (VexFlow 5.8.0)
///
/// Swift: upstream types `players` as a pair and `measures` as `[first, last]`. Here both are arrays, so that
/// the validation stays the same: `players` needs two distinct staff IDs, and `measures` needs two measure
/// numbers with `first <= last`.
public struct PublicationCondense: Sendable, Equatable {
    public var players: [String]
    public var measures: [Int]?
    public var name: String?

    public init(players: [String], measures: [Int]? = nil, name: String? = nil) {
        self.players = players
        self.measures = measures
        self.name = name
    }
}

/// Project both voices onto player one's staff without changing either authored part. (VexFlow 5.8.0)
func condenseStaves(_ staves: [EasyScoreStaveSpec], _ request: PublicationCondense) throws -> [EasyScoreStaveSpec] {
    let found = request.players.map { id in staves.firstIndex { $0.id == id } }
    guard request.players.count == 2, let i1 = found[0], let i2 = found[1], i1 != i2 else {
        throw invalidPage("Condensing requires two distinct selected source players.")
    }
    let one = staves[i1], two = staves[i2]
    if one.kind == .tab || two.kind == .tab || one.measures.count != two.measures.count {
        throw invalidPage("Condensing requires two aligned pitched parts.")
    }
    let name = request.name ?? [one.name ?? one.id, two.name ?? two.id].joined(separator: " / ")
    var key1 = one.key ?? "C", key2 = two.key ?? "C"
    let common = TimeSignatureSpec.meter(4, 4)
    var time1 = one.time ?? common, time2 = two.time ?? common
    let measures = try one.measures.enumerated().map { index, a -> EasyScoreMeasureSpec in
        let b = two.measures[index]
        key1 = a.key ?? key1
        key2 = b.key ?? key2
        time1 = a.time ?? time1
        time2 = b.time ?? time2
        if a.voices.count != 1 || b.voices.count != 1 || key1 != key2 || time1 != time2 {
            throw invalidPage("Condensing requires one voice per player in the same written key and meter.")
        }
        var measure = a
        measure.voices = [a.voices[0], b.voices[0]]
        measure.chords = a.chords + b.chords
        measure.verses = a.verses + b.verses
        return measure
    }
    var shared = one
    shared.name = name
    shared.shortName = name
    shared.measures = measures
    return staves.enumerated().compactMap { i, s in i == i2 ? nil : i == i1 ? shared : s }
}

private enum Texture: String {
    case one = "1."
    case two = "2."
    case a2
    case divided
    case rest
}

/// Ignore non-rhythmic signatures. A condensed player supplies a single pitch at each sounding attack.
private func line(_ voice: [Tickable]) throws -> [StaveNote] {
    try voice.filter { !$0.shouldIgnoreTicks() }.map { note in
        guard let note = note as? StaveNote, note.isRest() || note.getKeys().count == 1 else {
            throw invalidPage("Condense monophonic pitched parts.")
        }
        return note
    }
}

/// Pick one visible voice at rests or unisons, and give each player a stem when pitches divide.
private func condenseAttack(_ one: StaveNote, _ two: StaveNote) -> Texture {
    if one.isRest() && two.isRest() {
        two.renderOptions.draw = false
        return .rest
    }
    if one.isRest() || two.isRest() {
        (one.isRest() ? one : two).renderOptions.draw = false
        return one.isRest() ? .two : .one
    }
    if one.getKeys()[0].lowercased() == two.getKeys()[0].lowercased() {
        two.renderOptions.draw = false
        return .a2
    }
    _ = one.setStemDirection(.up)
    _ = two.setStemDirection(.down)
    return .divided
}

/// Annotate changes once, before the first formatting pass, so reflow retains their source attacks.
/// (VexFlow 5.8.0)
func markCondensedPlayers(_ score: EasyScoreComposition, _ staffIndex: Int, _ request: PublicationCondense) throws {
    var previous = Texture.rest
    func entrance(_ texture: Texture, _ note: StaveNote) {
        if texture != previous && texture != .rest && texture != .divided {
            _ = note.addModifier(Annotation(texture.rawValue).setVerticalJustification(.top), index: 0)
        }
        previous = texture
    }
    let range = request.measures ?? [1, score.notes.count]
    let first = range[0], last = range[range.count - 1]
    for parts in score.notes[(first - 1)..<min(last, score.notes.count)] {
        guard parts.indices.contains(staffIndex) else {
            throw invalidPage("Condensing requires two distinct selected source players.")
        }
        let lines = try parts[staffIndex].map(line)
        guard lines.count >= 2 else { throw invalidPage("Condensing requires two aligned pitched parts.") }
        let one = lines[0], two = lines[1]
        let solo: Int? = one.allSatisfy { $0.isRest() } ? 1 : two.allSatisfy { $0.isRest() } ? 0 : nil
        if let solo {
            let voices = [one, two]
            for rest in voices[1 - solo] { rest.renderOptions.draw = false }
            for note in voices[solo] { entrance(note.isRest() ? .rest : solo == 0 ? .one : .two, note) }
        } else if one.count == two.count && zip(one, two).allSatisfy({ $0.getTicks().equals($1.getTicks()) }) {
            for (i, a) in one.enumerated() {
                let texture = condenseAttack(a, two[i])
                entrance(texture, texture == .two ? two[i] : a)
            }
        } else {
            // Independent rhythms need both full voices, including their rests.
            for n in one { _ = n.setStemDirection(.up) }
            for n in two { _ = n.setStemDirection(.down) }
            previous = .divided
        }
    }
}
