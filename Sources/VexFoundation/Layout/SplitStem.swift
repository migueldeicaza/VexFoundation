// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/splitstem.ts` (VexFlow 5.7.0).
// Internal ownership for a beamed chord whose heads belong to two piano staves.

import Foundation

/// Each attack keeps both native notes. Only the member of the native beam prints the stem.
struct SplitStem {
    let upper: StaveNote
    let lower: StaveNote
    let owner: StaveNote
    /// Head nearest the beam, regardless of which voice owns it.
    let tipNote: StaveNote
}

/// Swift deviation: upstream keeps a module `WeakMap`. Each note holds this link; the
/// references are weak so the two notes do not retain each other.
final class SplitStemLink {
    weak var upper: StaveNote?
    weak var lower: StaveNote?
    weak var owner: StaveNote?
    weak var tipNote: StaveNote?

    init(upper: StaveNote, lower: StaveNote, owner: StaveNote, tipNote: StaveNote) {
        self.upper = upper
        self.lower = lower
        self.owner = owner
        self.tipNote = tipNote
    }

    var resolved: SplitStem? {
        guard let upper, let lower, let owner, let tipNote else { return nil }
        return SplitStem(upper: upper, lower: lower, owner: owner, tipNote: tipNote)
    }
}

/// Install a validated pair after the complete score has passed validation.
func linkSplitStem(_ upper: StaveNote, _ lower: StaveNote) {
    let owner = upper.getBeam() != nil ? upper : lower
    let tipNote = owner.getStemDirection() == Stem.UP ? upper : lower
    let link = SplitStemLink(upper: upper, lower: lower, owner: owner, tipNote: tipNote)
    upper.splitStemLink = link
    lower.splitStemLink = link
}

/// Look up both original heads without transferring either event between voices.
func splitStemFor(_ note: Note) -> SplitStem? {
    (note as? StaveNote)?.splitStemLink?.resolved
}

/// A strip participates in spacing on the staff nearest its tip, even when the other voice owns the beam.
func beamStave(_ note: Note) -> Stave? {
    (splitStemFor(note)?.tipNote ?? note).getStave()
}
