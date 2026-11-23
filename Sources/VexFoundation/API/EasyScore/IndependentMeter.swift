// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/easyscore/independentmeter.ts` (VexFlow 5.8.0).
// Project staff-local bars onto shared formatting windows. The timing and identity of the notes do not change.

import Foundation

/// The source position of an attack. It stays the same when a different system break is chosen. (VexFlow 5.8.0)
public struct MeterPosition: CustomStringConvertible {
    public var staff: String
    /// One-based measure on this staff.
    public var measure: Int
    public var voice: Int
    public var event: Int
    /// Exact ticks from the start of this staff's local measure.
    public var onset: Fraction

    public var description: String { "\(staff) m\(measure) v\(voice) e\(event) @\(onset)" }
}

/// A barline inside the held note of another staff. It follows its own next attack after formatting.
/// (VexFlow 5.8.0)
struct InteriorBar {
    var next: Note
    var bar: Barline
}

private struct MeterEntry {
    var tick: Tickable
    var at: Double
}

private struct LocalBar {
    var spec: EasyScoreMeasureSpec
    var state: EasyScoreResolvedStaffState
    var start: Double
    var end: Double
    var voices: [[MeterEntry]]
}

private func invalid(_ message: String) -> VexError {
    VexError("BadComposition", message)
}

/// The initial written state before the first local measure applies its own changes.
func initialStaffState(_ staff: EasyScoreStaveSpec) -> EasyScoreResolvedStaffState {
    EasyScoreResolvedStaffState(
        clef: staff.clef ?? (staff.kind == .tab ? .tab : .treble),
        key: staff.key ?? "C",
        time: staff.time ?? .default,
        showTimeSignature: staff.showTimeSignature ?? true
    )
}

typealias MeterMaterialize = (
    _ bar: EasyScoreMeasureSpec, _ initial: EasyScoreResolvedStaffState, _ measureIndex: Int
) throws -> (voices: [[Tickable]], end: EasyScoreResolvedStaffState)

/// Read each source bar one time and keep the exact local onset of each attack.
private func readStaff(
    _ staff: EasyScoreStaveSpec,
    _ materialize: MeterMaterialize,
    _ positions: inout [ObjectIdentifier: MeterPosition]
) throws -> [LocalBar] {
    var state = initialStaffState(staff)
    let cursor = Fraction(0, 1)
    var bars: [LocalBar] = []
    for (m, spec) in staff.measures.enumerated() {
        let initial = EasyScoreResolvedStaffState(
            clef: spec.clef ?? state.clef,
            key: spec.key ?? state.key,
            time: spec.time ?? state.time,
            showTimeSignature: spec.showTimeSignature ?? state.showTimeSignature
        )
        let (voices, end) = try materialize(spec, initial, m)
        state = end
        let duration = try Voice(validating: try spec.span ?? VoiceTime(timeSignature: initial.time)).getTotalTicks()
        let start = cursor.value()
        var entries: [[MeterEntry]] = []
        for (v, notes) in voices.enumerated() {
            let onset = Fraction(0, 1)
            var event = 0
            let result = notes.map { tick -> MeterEntry in
                let at = cursor.clone().add(onset).value()
                if !tick.shouldIgnoreTicks() {
                    positions[ObjectIdentifier(tick)] = MeterPosition(
                        staff: staff.id, measure: m + 1, voice: v, event: event, onset: onset.clone().simplify()
                    )
                    event += 1
                    onset.add(tick.getTicks())
                }
                return MeterEntry(tick: tick, at: at)
            }
            if !onset.equals(duration) {
                throw invalid("Measure \(m + 1) on \(staff.id) does not fill its declared span.")
            }
            entries.append(result)
        }
        bars.append(LocalBar(spec: spec, state: initial, start: start, end: cursor.add(duration).value(), voices: entries))
    }
    return bars
}

/// A system can break where all voices have an attack and no native beam or tuplet crosses the cut.
private func canBreak(_ bar: LocalBar, _ at: Double) -> Bool {
    if bar.start == at || bar.end == at { return true }
    return bar.voices.allSatisfy { voice in
        guard let next = voice.firstIndex(where: { $0.at == at && !$0.tick.shouldIgnoreTicks() }) else { return false }
        let note = voice[next].tick
        let previous = voice[..<next].reversed().first { !$0.tick.shouldIgnoreTicks() }?.tick
        guard let note = note as? Note, let previous = previous as? Note else { return true }
        let sharedBeam = note.getBeam() != nil && note.getBeam() === previous.getBeam()
        let sharedTuplet = note.getTupletStack().contains { t in previous.getTupletStack().contains { $0 === t } }
        return !(sharedBeam || sharedTuplet)
    }
}

/// Keep one stave for each staff in each shared window. A window edge closes only a bar of its own staff.
private func windowMeasure(
    _ bars: [LocalBar], _ start: Double, _ end: Double, _ interior: inout [InteriorBar]
) -> EasyScoreMeasureSpec {
    let first = bars[0]
    let last = bars[bars.count - 1]
    let width = Fraction(Int((end - start).rounded()), Tables.RESOLUTION).simplify()
    let voices = first.voices.indices.map { v -> EasyScoreVoiceSpec in
        let notes = bars.flatMap { bar in bar.voices[v].filter { $0.at >= start && $0.at < end }.map { $0.tick } }
        return EasyScoreVoiceSpec(
            notes: notes.map { .tickable($0) }, softmaxFactor: first.spec.voices[v].softmaxFactor
        )
    }
    for (i, bar) in bars.enumerated() where i > 0 {
        let next = bar.voices[0].first { $0.tick is Note && !$0.tick.shouldIgnoreTicks() }?.tick
        if let next = next as? Note {
            interior.append(InteriorBar(next: next, bar: Barline(bars[i - 1].spec.endBarline ?? .single)))
        }
    }
    var ids = Set<String>()
    for v in voices {
        for case .tickable(let n) in v.notes {
            if let id = n.getAttribute("id") { ids.insert(id) }
        }
    }
    let chords = bars.flatMap { $0.spec.chords }.filter { ids.contains($0.note) }
    let verses = bars.flatMap { bar in
        bar.spec.verses.map { verse in
            EasyScoreVerse(stanza: verse.stanza, syllables: verse.syllables.filter { ids.contains($0.note) })
        }.filter { !$0.syllables.isEmpty }
    }
    return EasyScoreMeasureSpec(
        clef: first.state.clef, key: first.state.key, time: first.state.time,
        span: VoiceTime(numBeats: width.numerator, beatValue: width.denominator),
        voices: voices,
        instrument: first.start == start ? first.spec.instrument : nil,
        showTimeSignature: first.state.showTimeSignature,
        endBarline: last.end == end ? (last.spec.endBarline ?? .single) : BarlineType.none,
        chords: chords,
        verses: verses
    )
}

/// The result of `independentMeterGrid`.
struct IndependentMeterGrid {
    var positions: [ObjectIdentifier: MeterPosition]
    var interior: [InteriorBar]
    var spec: EasyScoreCompositionSpec
}

/// Build shared cuts from the union of real barlines. Notes that cross a cut keep their written durations.
func independentMeterGrid(
    _ spec: EasyScoreCompositionSpec,
    _ materialize: (
        _ staffIndex: Int, _ bar: EasyScoreMeasureSpec, _ initial: EasyScoreResolvedStaffState, _ measureIndex: Int
    ) throws -> (voices: [[Tickable]], end: EasyScoreResolvedStaffState)
) throws -> IndependentMeterGrid {
    var positions: [ObjectIdentifier: MeterPosition] = [:]
    var interior: [InteriorBar] = []
    let parts = try spec.staves.enumerated().map { j, staff in
        try readStaff(staff, { bar, initial, m in try materialize(j, bar, initial, m) }, &positions)
    }
    guard let total = parts.first?.last?.end, total != 0, parts.allSatisfy({ $0.last?.end == total }) else {
        throw invalid("Independent staves must cover the same total duration.")
    }
    let candidates = Set(parts.flatMap { $0.map { $0.start } }).sorted()
    var cursors = parts.map { _ in 0 }
    var cuts = candidates.filter { at in
        parts.indices.allSatisfy { j in
            let bars = parts[j]
            while bars[cursors[j]].end <= at { cursors[j] += 1 }
            return canBreak(bars[cursors[j]], at)
        }
    }
    cuts.append(total)
    let staves = try spec.staves.enumerated().map { j, staff -> EasyScoreStaveSpec in
        let bars = parts[j]
        var index = 0
        var measures: [EasyScoreMeasureSpec] = []
        for i in 0..<(cuts.count - 1) {
            let start = cuts[i], end = cuts[i + 1]
            while bars[index].end <= start { index += 1 }
            var last = index
            while bars[last].end < end { last += 1 }
            let slice = Array(bars[index...last])
            if slice.contains(where: { $0.voices.count != slice[0].voices.count }) {
                throw invalid("A change of voice count needs a shared breakable barline.")
            }
            measures.append(windowMeasure(slice, start, end, &interior))
        }
        var result = staff
        result.measures = measures
        return result
    }
    // Global navigation and forced breaks use the authored measure numbers of the first staff.
    var continuous = spec.continuous ?? ContinuousOptions()
    continuous.boundaries = try continuous.boundaries.map { b in
        let m = b.measure - 1
        guard m >= 0, m < parts[0].count, let i = cuts.firstIndex(of: parts[0][m].start) else {
            throw invalid("A requested boundary must fall at a shared breakable onset.")
        }
        var boundary = b
        boundary.measure = i + 1
        return boundary
    }
    var result = spec
    result.staves = staves
    result.accidentals = .literal
    result.graceAccidentals = nil
    result.continuous = continuous
    return IndependentMeterGrid(positions: positions, interior: interior, spec: result)
}
