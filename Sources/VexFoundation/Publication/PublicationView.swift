// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/publicationview.ts` (VexFlow 5.8.0).
// Project declarative EasyScore music into an independent printed score or part.

import Foundation

/// A small written-pitch reference staff over source measures. Cues do not change the player's rest.
/// (VexFlow 5.4.0)
public struct PublicationRegion: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case cue
        case ossia
    }

    public var kind: Kind
    public var staff: String
    public var measure: Int
    /// Last source measure of an ossia, inclusive. Defaults to the starting measure. (VexFlow 5.8.0)
    public var endMeasure: Int?
    public var label: String
    /// Scale in (0, 1]. Default 0.7.
    public var scale: Double?
    /// Written interval applied to the quoted pitches and their key signature. Only for a cue. (VexFlow 5.8.0)
    public var transpose: CueTransposition?

    public init(
        kind: Kind, staff: String, measure: Int, label: String, scale: Double? = nil, endMeasure: Int? = nil,
        transpose: CueTransposition? = nil
    ) {
        self.kind = kind
        self.staff = staff
        self.measure = measure
        self.endMeasure = endMeasure
        self.label = label
        self.scale = scale
        self.transpose = transpose
    }
}

/// The staves, breaks, turns and insets of one printed edition. All measure references are one-based.
/// A page turn follows its named measure. (VexFlow 5.4.0)
public struct PublicationView: Sendable, Equatable {
    public var staves: [String]?
    /// Engrave two source players on one conductor staff. (VexFlow 5.8.0)
    public var condense: PublicationCondense?
    public var systemBreaks: [Int]
    public var pageBreaks: [Int]
    public var preferredTurns: [Int]
    public var forbiddenTurns: [Int]
    public var regions: [PublicationRegion]

    public init(
        staves: [String]? = nil, systemBreaks: [Int] = [], pageBreaks: [Int] = [], preferredTurns: [Int] = [],
        forbiddenTurns: [Int] = [], regions: [PublicationRegion] = [], condense: PublicationCondense? = nil
    ) {
        self.staves = staves
        self.condense = condense
        self.systemBreaks = systemBreaks
        self.pageBreaks = pageBreaks
        self.preferredTurns = preferredTurns
        self.forbiddenTurns = forbiddenTurns
        self.regions = regions
    }
}

func invalidPage(_ message: String) -> VexError {
    VexError("BadPublication", message)
}

/// Validate view references before a new rendering replaces an existing one. (VexFlow 5.4.0)
func checkView(_ source: EasyScoreCompositionSpec, _ view: PublicationView) throws {
    let staffIds = Set(source.staves.map { $0.id })
    let count = source.staves.first?.measures.count ?? 0
    if count == 0 { throw invalidPage("Expected at least one measure.") }
    let validMeasure = { (n: Int) in n >= 1 && n <= count }
    if let passage = view.condense?.measures {
        if passage.count != 2 || !validMeasure(passage[0]) || !validMeasure(passage[1]) || passage[1] < passage[0] {
            throw invalidPage("Invalid condensed passage.")
        }
    }
    for values in [view.systemBreaks, view.pageBreaks, view.preferredTurns, view.forbiddenTurns]
    where values.contains(where: { !validMeasure($0) }) {
        throw invalidPage("Break or turn outside the score.")
    }
    if let staves = view.staves,
       staves.isEmpty || Set(staves).count != staves.count || staves.contains(where: { !staffIds.contains($0) }) {
        throw invalidPage("Expected distinct source staff IDs.")
    }
    for region in view.regions {
        // Swift: the interval fields are integers, so only the region kind needs a check.
        if region.transpose != nil && region.kind != .cue {
            throw invalidPage("A transposed cue needs integer semitones and diatonic steps.")
        }
        let scale = region.scale ?? 0.7
        let badEnd = region.endMeasure.map { end in region.kind != .ossia || !validMeasure(end) || end < region.measure }
            ?? false
        if !validMeasure(region.measure) || badEnd || !staffIds.contains(region.staff)
            || region.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !scale.isFinite || scale <= 0 || scale > 1 {
            throw invalidPage("Expected a labeled cue or ossia on a source staff and measure with scale in (0, 1].")
        }
    }
    for staff in source.staves {
        for measure in staff.measures {
            for voice in measure.voices {
                for item in voice.notes {
                    if case .tickable = item {
                        throw invalidPage("Use declarative events for independently rendered publication views.")
                    }
                }
            }
        }
    }
}

/// The note IDs at the two ends of a composition span.
private func spanEnds(_ span: EasyScoreSpanSpec) -> (from: String?, to: String?) {
    switch span {
    case .tie(let from, let to, _, _, _): return (from, to)
    case .curve(let from, let to, _): return (from, to)
    case .hairpin(let from, let to, _, _): return (from, to)
    }
}

/// Track only declared IDs for relationships. The score's native lookup also handles IDs in EasyScore
/// strings. (VexFlow 5.4.0)
func projectScore(
    _ source: EasyScoreCompositionSpec,
    _ view: PublicationView,
    width: Double,
    reference: EasyScoreComposition? = nil,
    omitted: ((String, [Int]) -> Void)? = nil
) throws -> EasyScoreCompositionSpec {
    let selected = Set(view.staves ?? view.condense?.players ?? source.staves.map { $0.id })
    let staves = source.staves.filter { selected.contains($0.id) }
        .map { view.staves != nil || view.condense != nil ? homeStaff($0, selected) : $0 }
    let printedStaves = try view.condense.map { try condenseStaves(staves, $0) } ?? staves
    let printedIds = Set(printedStaves.map { $0.id })
    // Follow rhythmic ownership when a note is displayed on a different staff.
    var owners: [ObjectIdentifier: (staff: String, measure: Int)] = [:]
    if let reference {
        for (m, parts) in reference.notes.enumerated() {
            for (j, voices) in parts.enumerated() {
                for event in voices.joined() { owners[ObjectIdentifier(event)] = (source.staves[j].id, m + 1) }
            }
        }
    }
    func keep(_ a: String?, _ b: String?, _ id: String? = nil) -> Bool {
        guard let reference else { return true }
        let ends = [a, b].compactMap { name -> (staff: String, measure: Int)? in
            guard let name, !name.isEmpty, let note = try? reference.getNote(name) else { return nil }
            return owners[ObjectIdentifier(note)]
        }
        let included = ends.filter { selected.contains($0.staff) }
        if !included.isEmpty && included.count < ends.count {
            omitted?(id ?? a ?? b ?? "", ends.map { $0.measure })
        }
        return ends.count == included.count
    }
    let original = source.continuous ?? ContinuousOptions()
    // Keep the insertion order of the upstream Map.
    var order: [Int] = []
    var boundaries: [Int: ContinuousBoundary] = [:]
    for b in original.boundaries where boundaries[b.measure] == nil {
        order.append(b.measure)
        boundaries[b.measure] = b
    }
    if boundaries.count != original.boundaries.count { throw invalidPage("Expected unique source boundary measures.") }
    func boundary(_ n: Int, _ change: (inout ContinuousBoundary) -> Void) {
        if boundaries[n] == nil {
            boundaries[n] = ContinuousBoundary(measure: n)
            order.append(n)
        }
        change(&boundaries[n]!)
    }
    for n in view.systemBreaks + view.pageBreaks { boundary(n) { $0.breakBefore = .force } }
    if let passage = view.condense?.measures, passage.count == 2 {
        boundary(passage[0]) { $0.breakBefore = .force }
        if passage[1] < source.staves[0].measures.count { boundary(passage[1] + 1) { $0.breakBefore = .force } }
    }
    // Cued rests must remain individually addressable even when their neighbours form a multi-measure rest.
    for region in view.regions {
        for m in region.measure...max(region.measure, region.endMeasure ?? region.measure) {
            boundary(m) { $0.keepRest = true }
        }
    }
    var projected = source
    projected.staves = printedStaves
    projected.sheet.x = 0
    projected.sheet.y = 0
    projected.sheet.rowGap = 150
    projected.sheet.width = width
    projected.spans = source.spans.filter { let e = spanEnds($0); return keep(e.from, e.to) }
    var continuous = original
    continuous.boundaries = order.compactMap { boundaries[$0] }
    continuous.spans = original.spans.filter { keep($0.from, $0.to, $0.id) }
    continuous.tuplets = original.tuplets.filter { keep($0.members.first, $0.members.last, $0.id) }
    continuous.splitChords = original.splitChords.filter { keep($0.upper, $0.lower, $0.id) }
    if view.staves != nil || view.condense != nil {
        continuous.groups = original.groups.compactMap { g in
            guard let start = source.staves.firstIndex(where: { $0.id == g.first }),
                  let end = source.staves.firstIndex(where: { $0.id == g.last }), start <= end
            else { return nil }
            let members = source.staves[start...end].filter { printedIds.contains($0.id) }
            guard members.count >= 2, let top = members.first, let bottom = members.last else { return nil }
            var group = g
            group.first = top.id
            group.last = bottom.id
            return group
        }
    }
    projected.continuous = continuous
    return projected
}

/// Return a cross-staff event to its rhythmic staff when its display staff is absent in this view.
private func homeStaff(_ staff: EasyScoreStaveSpec, _ selected: Set<String>) -> EasyScoreStaveSpec {
    var result = staff
    result.measures = staff.measures.map { m in
        var measure = m
        measure.voices = m.voices.map { v in
            var voice = v
            voice.notes = v.notes.map { item in
                switch item {
                case .note(var note, let id, let stave?, let grace) where !stave.isEmpty && !selected.contains(stave):
                    note.clef = nil
                    return .note(note, id: id, stave: staff.id, grace: grace)
                case .tab(let tab, let id, let stave?, let drawStem) where !stave.isEmpty && !selected.contains(stave):
                    return .tab(tab, id: id, stave: staff.id, drawStem: drawStem)
                default:
                    return item
                }
            }
            return voice
        }
        return measure
    }
    return result
}

/// Carry written clef, key and meter into a reference fragment, including preceding inline changes.
/// `endMeasure` is inclusive and defaults to `measure`. (VexFlow 5.8.0)
func insetStaff(_ staff: EasyScoreStaveSpec, _ measure: Int, _ endMeasure: Int? = nil) -> EasyScoreStaveSpec {
    var state = EasyScoreStaffState(
        clef: staff.clef, key: staff.key, time: staff.time, showTimeSignature: staff.showTimeSignature
    )
    for m in staff.measures.prefix(measure - 1) {
        state.clef = m.clef ?? state.clef
        state.key = m.key ?? state.key
        state.time = m.time ?? state.time
        state.showTimeSignature = m.showTimeSignature ?? state.showTimeSignature
        for v in m.voices.prefix(1) {
            for item in v.notes {
                if case .change(let change) = item {
                    state.clef = change.clef ?? state.clef
                    state.key = change.key ?? state.key
                    state.time = change.time ?? state.time
                    state.showTimeSignature = change.showTimeSignature ?? state.showTimeSignature
                }
            }
        }
    }
    var inset = staff
    inset.clef = state.clef
    inset.key = state.key
    inset.time = state.time
    inset.showTimeSignature = state.showTimeSignature
    inset.name = nil
    inset.shortName = nil
    inset.measures = Array(staff.measures[(measure - 1)..<min(endMeasure ?? measure, staff.measures.count)])
    return homeStaff(inset, [staff.id])
}

/// Conservative playable turn: every timed event in every performing voice is a rest in the preceding
/// measure. (VexFlow 5.4.0)
func restingMeasure(_ score: EasyScoreComposition, _ number: Int) -> Bool {
    let notes = score.notes[number - 1].flatMap { $0.joined() }.filter { !$0.shouldIgnoreTicks() }
    return !notes.isEmpty && notes.allSatisfy { ($0 as? Note)?.isRest() == true }
}
