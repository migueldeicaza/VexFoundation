// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/continuouslayout.ts` (VexFlow 5.7.0).
// Row-dependent notation for a responsive EasyScore composition. Source measures and notes keep their identity.

import Foundation

/// A navigation mark at a measure. (VexFlow 5.4.0)
public enum ContinuousNavigation: Sendable, Equatable {
    case segno(id: String)
    case coda(id: String)
    case dalSegno(target: String)
    case toCoda(target: String)
    case daCapo
    case fine

    /// Upstream `kind`.
    public var kind: String {
        switch self {
        case .segno: return "segno"
        case .coda: return "coda"
        case .dalSegno: return "dalSegno"
        case .toCoda: return "toCoda"
        case .daCapo: return "daCapo"
        case .fine: return "fine"
        }
    }
}

/// Structural information at the start of one source measure. (VexFlow 5.4.0)
public struct ContinuousBoundary: Sendable, Equatable {
    /// One-based source measure number, independent of rest compression.
    public var measure: Int
    public var breakBefore: BreakConstraint?
    public var rehearsal: String?
    public var navigation: ContinuousNavigation?
    public var repeatStart: Bool
    public var repeatEnd: Bool
    public var keepRest: Bool

    public init(
        measure: Int, breakBefore: BreakConstraint? = nil, rehearsal: String? = nil,
        navigation: ContinuousNavigation? = nil, repeatStart: Bool = false, repeatEnd: Bool = false,
        keepRest: Bool = false
    ) {
        self.measure = measure
        self.breakBefore = breakBefore
        self.rehearsal = rehearsal
        self.navigation = navigation
        self.repeatStart = repeatStart
        self.repeatEnd = repeatEnd
        self.keepRest = keepRest
    }
}

/// Aligned half or quarter notes, or eighth notes with a native beam on one of the two staves.
/// (VexFlow 5.4.0, eighths in 5.7.0)
public struct ContinuousSplitChord: Sendable, Equatable {
    public var id: String
    public var upper: String
    public var lower: String

    public init(id: String, upper: String, lower: String) {
        self.id = id
        self.upper = upper
        self.lower = lower
    }
}

/// A brace or bracket over consecutive staves. (VexFlow 5.4.0)
public struct ContinuousGroup: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case brace
        case bracket
    }

    public var first: String
    public var last: String
    public var type: Kind
    /// Draw barlines through the group.
    public var barlines: Bool

    public init(first: String, last: String, type: Kind, barlines: Bool = false) {
        self.first = first
        self.last = last
        self.type = type
        self.barlines = barlines
    }
}

/// Continuous-score options of an EasyScore composition. (VexFlow 5.4.0)
public struct ContinuousOptions: Sendable, Equatable {
    public var mode: SystemBreakMode?
    public var boundaries: [ContinuousBoundary]
    public var spans: [ContinuousSpan]
    public var hideEmptyStaves: Bool
    public var compressRests: Bool
    public var measureNumbers: Bool
    /// Courtesy clef, key and time signatures at row ends (upstream `courtesy !== false`).
    public var courtesy: Bool
    public var splitChords: [ContinuousSplitChord]
    public var groups: [ContinuousGroup]

    public init(
        mode: SystemBreakMode? = nil, boundaries: [ContinuousBoundary] = [], spans: [ContinuousSpan] = [],
        hideEmptyStaves: Bool = false, compressRests: Bool = false, measureNumbers: Bool = false,
        courtesy: Bool = true, splitChords: [ContinuousSplitChord] = [], groups: [ContinuousGroup] = []
    ) {
        self.mode = mode
        self.boundaries = boundaries
        self.spans = spans
        self.hideEmptyStaves = hideEmptyStaves
        self.compressRests = compressRests
        self.measureNumbers = measureNumbers
        self.courtesy = courtesy
        self.splitChords = splitChords
        self.groups = groups
    }
}

/// One row of a continuous score (upstream `ContinuousRow extends SheetRow`). (VexFlow 5.4.0)
public struct ContinuousRow {
    public var systems: [System]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var overflow: Double
    /// One-based source measures.
    public var measures: [Int]
    public var visibleStaves: [String]
    /// One-based source measures of each compressed rest.
    public var restGroups: [[Int]]

    /// The row as a plain sheet row.
    public var sheetRow: SheetRow {
        SheetRow(systems: systems, x: x, y: y, width: width, height: height, overflow: overflow)
    }
}

/// A layout diagnostic. Measures are one-based. (VexFlow 5.4.0)
public struct ContinuousDiagnostic: Sendable, Equatable {
    public enum Code: String, Sendable {
        case rowOverflow = "RowOverflow"
        case curveCollision = "CurveCollision"
        case splitStemAlignment = "SplitStemAlignment"
        case spanOverflow = "SpanOverflow"
        case staffSpacingLimit = "StaffSpacingLimit"
    }

    public var code: Code
    public var measures: [Int]
    public var source: String?
}

private func invalid(_ message: String) -> VexError {
    VexError("BadContinuousScore", message)
}

/// Resolve each end independently because chord positions can be reordered between attacks. (VexFlow 5.6.0)
private func resolveTabTie(_ span: ContinuousSpan, _ first: TabNote, _ last: TabNote) throws -> ContinuousSpan {
    let start = first.getPositions()
    let end = last.getPositions()
    for head in [span.fromHead, span.toHead] {
        if let head, head < 0 { throw invalid("Invalid tab tie position index.") }
    }
    func at(_ positions: [TabNotePosition], _ i: Int?) -> TabNotePosition? {
        guard let i, i >= 0, i < positions.count else { return nil }
        return positions[i]
    }
    let selected = span.fromHead == nil && span.toHead != nil ? at(end, span.toHead) : at(start, span.fromHead ?? 0)
    guard let string = span.string ?? selected?.str, string >= 1, string <= first.checkStave().getNumLines() else {
        throw invalid("A tab tie needs a string on its staff.")
    }
    let fromHead = span.fromHead ?? start.firstIndex { $0.str == string } ?? -1
    let toHead = span.toHead ?? end.firstIndex { $0.str == string } ?? -1
    guard let from = at(start, fromHead), let to = at(end, toHead), from.str == string, to.str == string,
          from.fret == to.fret
    else { throw invalid("Tab tie endpoints must play the same string and fret.") }
    var resolved = span
    resolved.fromHead = fromHead
    resolved.toHead = toHead
    resolved.string = string
    if span.bend != nil, Double(from.fret) == nil { throw invalid("A tied bend needs a pitched fret.") }
    resolved.side = span.side ?? (span.bend != nil ? .below : .above)
    return resolved
}

/// A string sustains into the immediately following event of the same rhythmic voice. (VexFlow 5.7.0)
private func adjacentBendEvents(_ notes: [[[[Tickable]]]], _ first: SpanAnchor, _ last: SpanAnchor) -> Bool {
    let parts = notes[first.measure][first.staff]
    guard let voice = parts.firstIndex(where: { group in group.contains { $0 === first.note } }),
          last.measure <= first.measure + 1 else { return false }
    let members = parts[voice].filter { !$0.shouldIgnoreTicks() }
    guard let index = members.firstIndex(where: { $0 === first.note }) else { return false }
    if first.measure == last.measure { return index + 1 < members.count && members[index + 1] === last.note }
    let next = notes[last.measure][last.staff]
    return index == members.count - 1 && voice < next.count
        && next[voice].first(where: { !$0.shouldIgnoreTicks() }) === last.note
}

private struct Marks {
    var start: [StaveModifier]
    var end: [StaveModifier]
}

private struct Unit {
    var first: Int
    var last: Int
    var breakUnit: BreakUnit
    var width: Double { breakUnit.width }
    var start: Double { breakUnit.start }
    var end: Double { breakUnit.end }
    var after: Double {
        get { breakUnit.after }
        set { breakUnit.after = newValue }
    }
}

private struct PlacedMeasure {
    var u: Unit
    var sys: System
    var endPadding: Double
}

private struct Names {
    var full: VexElement?
    var short: VexElement?
}

private struct Arrival {
    var note: Note
    var mark: Accidental
    var index: Int
}

/// A row has one shared staff map. A compressed rest maps back to every original measure. (VexFlow 5.4.0)
///
/// Created by `EasyScore.compose(_:)` when `EasyScoreCompositionSpec.continuous` is set. Read it with
/// `Sheet.getContinuousLayout()`.
public final class ContinuousLayout {
    /// Elements (staves, voices, notes and systems) that `Factory.draw` skips.
    public private(set) var hidden = Set<ObjectIdentifier>()
    public private(set) var diagnostics: [ContinuousDiagnostic] = []
    public private(set) var fragments: [SpanFragment] = []
    public private(set) var rows: [ContinuousRow] = []

    private var marks: [[Marks]] = []
    private var boundaries: [Int: ContinuousBoundary] = [:]
    private var spans: [ResolvedSpan] = []
    private var names: [[Names]] = []
    private var groups: [(first: Int, last: Int, type: ContinuousGroup.Kind, barlines: Bool)] = []
    private var drawing: [(RenderContext) throws -> Void] = []
    private var headerLabels: [String: VexElement] = [:]
    private var splitChords: [(id: String, measure: Int, upper: StaveNote, lower: StaveNote)] = []
    private var spelledSpans = Set<Int>()
    private let options: ContinuousOptions
    /// Keep incoming ties and beams clear of the repeated clef at a row start. (VexFlow 5.7.0)
    private var continuationPadding: [ObjectIdentifier: Double] = [:]
    private var arrivals: [Int: [Arrival]] = [:]
    /// The composition arrays (final when the layout is created). The layout does not keep the composition,
    /// which owns the sheet that owns this layout.
    private let score: (systems: [System], staves: [[Stave]], voices: [[[Voice]]], notes: [[[[Tickable]]]])
    private let spec: EasyScoreCompositionSpec

    /// True when `Factory.draw` skips `element`.
    public func isHidden(_ element: AnyObject) -> Bool {
        hidden.contains(ObjectIdentifier(element))
    }

    /// Reuse measured labels when a resize moves a measure to another row.
    private func headerLabel(_ text: String, _ symbol: Bool = false) -> VexElement {
        let key = (symbol ? "glyph:" : "text:") + text
        if let mark = headerLabels[key] { return mark }
        let mark = VexElement(category: symbol ? "Repetition" : "Annotation").setText(text)
        if symbol { mark.setFontSize(18) }
        headerLabels[key] = mark
        return mark
    }

    private func headerParts(_ i: Int, _ atStart: Bool) -> [(mark: VexElement, boxed: Bool)] {
        let boundary = boundaries[i]
        let kind = boundary?.navigation?.kind
        let nav: String
        switch boundary?.navigation {
        case .segno?: nav = Glyphs.segno
        case .coda?: nav = Glyphs.coda
        case .dalSegno?: nav = "D.S."
        case .toCoda?: nav = "To Coda"
        case .daCapo?: nav = "D.C."
        case .fine?: nav = "Fine"
        case nil: nav = ""
        }
        var texts: [String?] = [options.measureNumbers && atStart ? String(i + 1) : "", boundary?.rehearsal]
        if !atStart { texts += spec.staves.map { $0.measures[i].instrument?.name } }
        texts.append(nav)
        var parts: [(mark: VexElement, boxed: Bool)] = []
        for (k, text) in texts.enumerated() {
            guard let text, !text.isEmpty else { continue }
            let symbol = k == texts.count - 1 && (kind == "segno" || kind == "coda")
            parts.append((headerLabel(text, symbol), k == 1))
        }
        return parts
    }

    init(
        _ score: EasyScoreComposition, _ spec: EasyScoreCompositionSpec, _ starts: [[EasyScoreResolvedStaffState]],
        _ ends: [[EasyScoreResolvedStaffState]], _ placed: Set<ObjectIdentifier>?
    ) throws {
        self.score = (score.systems, score.staves, score.voices, score.notes)
        self.spec = spec
        self.options = spec.continuous ?? ContinuousOptions()
        for voice in score.voices.flatMap({ $0.flatMap { $0 } }) { voice.preserveStaveAssignments = true }
        let ids = spec.staves.map { $0.id }
        for b in options.boundaries {
            if b.measure < 1 || b.measure > score.systems.count || boundaries[b.measure - 1] != nil {
                throw invalid("Expected a unique, in-range boundary measure.")
            }
            boundaries[b.measure - 1] = b
        }
        var destinations: [String: String] = [:]
        for b in boundaries.values {
            switch b.navigation {
            case .segno(let id)?, .coda(let id)?:
                if id.isEmpty || destinations[id] != nil { throw invalid("Duplicate or empty navigation destination.") }
                destinations[id] = b.navigation?.kind
            default: break
            }
        }
        for b in boundaries.values {
            switch b.navigation {
            case .dalSegno(let target)?:
                if destinations[target] != "segno" { throw invalid("Navigation instruction needs a matching destination.") }
            case .toCoda(let target)?:
                if destinations[target] != "coda" { throw invalid("Navigation instruction needs a matching destination.") }
            default: break
            }
        }
        groups = try options.groups.map { g in
            guard let first = ids.firstIndex(of: g.first), let last = ids.firstIndex(of: g.last), last > first else {
                throw invalid("Invalid staff group.")
            }
            return (first, last, g.type, g.barlines)
        }
        let label = { (text: String?) -> VexElement? in
            guard let text, !text.isEmpty else { return nil }
            return VexElement(category: "Annotation").setText(text)
        }
        var current = spec.staves.map { Names(full: label($0.name), short: label($0.shortName ?? $0.name)) }
        names = score.systems.indices.map { i in
            spec.staves.enumerated().map { j, s in
                if let change = s.measures[i].instrument {
                    current[j] = Names(full: label(change.name), short: label(change.shortName ?? change.name))
                }
                return current[j]
            }
        }
        marks = starts.enumerated().map { i, states in
            states.enumerated().map { j, state in
                let stave = score.staves[i][j]
                let boundary = boundaries[i]
                if boundary?.repeatStart == true { stave.setBegBarType(.repeatBegin) }
                if boundary?.repeatEnd == true { stave.setEndBarType(.repeatEnd) }
                var start: [StaveModifier] = []
                var end: [StaveModifier] = []
                let present = { (category: String) in !stave.getModifiers(position: .begin, category: category).isEmpty }
                if !present(Clef.category) { start.append(Clef(type: state.clef)) }
                if state.clef != .tab && state.key != "C" && !present(KeySignature.category) {
                    start.append(KeySignature(keySpec: state.key))
                }
                // Meter is carried silently at a repeated row start. Explicit changes remain native modifiers.
                if i + 1 < starts.count, options.courtesy {
                    let next = starts[i + 1][j]
                    let current = ends[i][j]
                    if next.clef != current.clef { end.append(Clef(type: next.clef, size: .small)) }
                    if next.clef != .tab && next.key != current.key {
                        end.append(KeySignature(keySpec: next.key, cancelKeySpec: current.key))
                    }
                    if next.showTimeSignature && next.time != current.time {
                        end.append(TimeSignature(timeSpec: next.time))
                    }
                }
                end.forEach { $0.setPosition(.end) }
                return Marks(start: start, end: end)
            }
        }
        var locations: [ObjectIdentifier: SpanAnchor] = [:]
        for (measure, parts) in score.notes.enumerated() {
            for n in parts.flatMap({ $0.flatMap { $0 } }) {
                guard let n = n as? Note, let stave = n.getStave() else { continue }
                let staff = score.staves[measure].firstIndex { $0 === stave } ?? -1
                locations[ObjectIdentifier(n)] = SpanAnchor(measure: measure, staff: staff, note: n)
            }
        }
        func locate(_ id: String?) -> SpanAnchor? {
            guard let id, let note = try? score.getNote(id) else { return nil }
            return locations[ObjectIdentifier(note)]
        }
        var seen = Set<String>()
        func onset(_ n: Note) -> Fraction {
            let time = Fraction(0, 1)
            for tick in n.getVoice().getTickables() {
                if tick === n { break }
                if !tick.shouldIgnoreTicks() { time.add(tick.getTicks()) }
            }
            return time
        }
        for sp in spec.spans {
            let ids: (from: String?, to: String?)
            switch sp {
            case .tie(let from, let to, _, _, _): ids = (from, to)
            case .curve(let from, let to, _): ids = (from, to)
            case .hairpin(let from, let to, _, _): ids = (from, to)
            }
            if let from = locate(ids.from), let to = locate(ids.to), from.measure <= to.measure {
                for i in from.measure...to.measure { spelledSpans.insert(i) }
            }
        }
        var beamedMembers = Set<ObjectIdentifier>()
        for chord in options.splitChords {
            let a = locate(chord.upper), b = locate(chord.lower)
            guard !chord.id.isEmpty, !seen.contains(chord.id), let a, let b, a.measure == b.measure, a.staff < b.staff,
                  let upper = a.note as? StaveNote, let lower = b.note as? StaveNote,
                  !upper.isRest(), !lower.isRest(),
                  ["h", "q", "2", "4", "8"].contains(upper.getDuration()),
                  upper.getDuration() == lower.getDuration(),
                  upper.getStemDirection() == lower.getStemDirection(),
                  upper.getTicks().equals(lower.getTicks()),
                  onset(upper).equals(onset(lower))
            else {
                throw invalid("A split stem needs matching simultaneous half, quarter or eighth notes on ordered staves.")
            }
            if upper.getDuration() == "8" {
                if beamedMembers.contains(ObjectIdentifier(upper)) || beamedMembers.contains(ObjectIdentifier(lower)) {
                    throw invalid("A beamed note can belong to only one split chord.")
                }
                beamedMembers.insert(ObjectIdentifier(upper))
                beamedMembers.insert(ObjectIdentifier(lower))
            }
            seen.insert(chord.id)
            splitChords.append((chord.id, a.measure, upper, lower))
        }
        var pendingBeams: [(index: Int, members: [ContinuousBeamMember])] = []
        var claimedNotes = Set<ObjectIdentifier>()
        for span in options.spans {
            guard !span.id.isEmpty, !seen.contains(span.id), let first = locate(span.from), let last = locate(span.to),
                  first.measure <= last.measure
            else { throw invalid("Expected a unique span ID and ordered composition anchors.") }
            var spec = span
            if span.bend != nil && !(span.kind == .tie && first.note is TabNote && last.note is TabNote) {
                throw invalid("A tied bend needs two TAB endpoints.")
            }
            if span.string != nil && !(span.kind == .tie && first.note is TabNote) {
                throw invalid("A string selector requires a tab tie.")
            }
            if span.kind == .palmMute {
                guard let a = first.note as? TabNote, let b = last.note as? TabNote, first.staff == last.staff else {
                    throw invalid("A palm mute needs two TAB anchors on the same staff.")
                }
                let strings = span.strings ?? []
                let lines = first.note.checkStave().getNumLines()
                if strings.isEmpty || Set(strings).count != strings.count || !strings.allSatisfy({ $0 > 0 && $0 <= lines }) {
                    throw invalid("A palm mute needs distinct string numbers on its staff.")
                }
                for note in [a, b] where !note.getPositions().contains(where: { strings.contains($0.str) }) {
                    throw invalid("Each palm-mute anchor must play a targeted string.")
                }
            } else if let a = first.note as? TabNote, let b = last.note as? TabNote {
                // VexFlow 5.6.0: tab ties and endings.
                if first.staff != last.staff || (span.kind != .tie && span.kind != .volta) {
                    throw invalid("Tab ties and endings need anchors on the same tab staff.")
                }
                if span.kind == .tie {
                    spec = try resolveTabTie(span, a, b)
                    if let bend = span.bend {
                        if !adjacentBendEvents(score.notes, first, last) {
                            throw invalid("A tied bend needs adjacent events in the same TAB voice.")
                        }
                        spec.bend = try copyTiedBend(bend)
                    }
                    if first.measure != last.measure && onset(b).numerator == 0 {
                        let stave = b.checkStave()
                        continuationPadding[ObjectIdentifier(stave)] = stave.space(1.5)
                    }
                }
            } else {
                guard first.note is StaveNote, last.note is StaveNote else {
                    throw invalid("Continuous spans need staff-note anchors.")
                }
                for (head, n) in [(span.fromHead ?? 0, first.note), (span.toHead ?? 0, last.note)]
                where head < 0 || head >= n.getKeys().count {
                    throw invalid("Invalid span head index.")
                }
            }
            if span.kind == .glissando {
                if first.staff != last.staff || first.note.isRest() || last.note.isRest()
                    || (first.measure == last.measure && onset(first.note).equals(onset(last.note))) {
                    throw invalid("A glissando needs two ordered pitched attacks on the same staff.")
                }
                // Reserve a visible lead-in after the clef when the arrival is the first attack on its row.
                if first.measure != last.measure && onset(last.note).numerator == 0 {
                    let stave = last.note.checkStave()
                    continuationPadding[ObjectIdentifier(stave)] = stave.space(1.5)
                }
            }
            if first.measure == last.measure && onset(first.note).greaterThan(onset(last.note)) {
                throw invalid("Reversed span.")
            }
            if let syllableId = span.syllableId,
               syllableId.isEmpty || span.kind != .lyric || first.staff != last.staff || span.text != nil
                || span.labelFontSize != nil {
                throw invalid(
                    "An anchored lyric extender needs a syllable ID and two notes on the same staff. "
                        + "Its annotation supplies the text and font."
                )
            }
            if span.kind == .tie && first.note is StaveNote && first.measure != last.measure {
                let fi = span.fromHead ?? 0, li = span.toHead ?? 0
                if first.note.getKeys()[fi].lowercased() != last.note.getKeys()[li].lowercased() {
                    throw invalid("Tied heads must have the same written pitch.")
                }
                let mods = last.note.getModifiers()
                if let index = mods.firstIndex(where: { m in
                    guard let m = m as? Accidental else { return false }
                    return m.getIndex() == li && placed?.contains(ObjectIdentifier(m)) == true
                }), let mark = mods[index] as? Accidental {
                    arrivals[last.measure, default: []].append(Arrival(note: last.note, mark: mark, index: index))
                }
            }
            seen.insert(span.id)
            var resolved = ResolvedSpan(spec: spec, first: first, last: last, label: spanLabel(spec))
            if let bend = spec.bend { resolved.bendLabel = VexElement(category: "Bend").setText(bendAmount(bend)) }
            if span.kind == .beam {
                let members = try beamMembers(score.notes, score.staves, first, last)
                for member in members {
                    let note = member.note
                    if note.getBeam() != nil || claimedNotes.contains(ObjectIdentifier(note)) {
                        throw invalid("A continuous beam member already belongs to a beam.")
                    }
                    claimedNotes.insert(ObjectIdentifier(note))
                    if member.measure > first.measure {
                        let stave = note.checkStave()
                        continuationPadding[ObjectIdentifier(stave)] = stave.space(1.5)
                    }
                }
                pendingBeams.append((spans.count, members))
            }
            spans.append(resolved)
        }
        // Resolve every span before attaching beams to caller-owned notes.
        for pending in pendingBeams { spans[pending.index].beam = try ContinuousBeam(pending.members) }
    }

    /// Only undecorated, wholly resting measures can disappear into a numbered rest.
    private func plainRest(_ i: Int) -> Bool {
        if boundaries[i] != nil || spelledSpans.contains(i)
            || spec.staves.contains(where: { $0.measures[i].instrument != nil })
            || spans.contains(where: { $0.first.measure <= i && i <= $0.last.measure }) {
            return false
        }
        let decorated = score.staves[i].contains { s in
            s.getModifiers().contains { m in
                guard let bar = m as? Barline else { return true }
                return bar.getType() != .single && bar.getType() != .none
            }
        }
        if decorated { return false }
        return score.notes[i].flatMap { $0.flatMap { $0 } }.allSatisfy { n in
            guard let n = n as? StaveNote else { return false }
            return n.isRest() && n.restLine == nil && n.getModifiers().isEmpty && n.getBeam() == nil
                && n.getTupletStack().isEmpty
        }
    }

    /// Add cached signs for the candidate boundaries and reserve actual end-modifier width.
    private func boundaryWidth(_ i: Int, _ start: Bool, _ end: Bool) -> Double {
        // Only signs generated by key-aware composition change with a tied arrival. Authored signs survive.
        for arrival in arrivals[i] ?? [] {
            let note = arrival.note
            let current = note.modifiers.firstIndex { $0 === arrival.mark }
            if start && current == nil {
                note.modifiers.insert(arrival.mark, at: min(arrival.index, note.modifiers.count))
            } else if !start, let current {
                note.modifiers.remove(at: current)
            }
        }
        let staves = score.staves[i]
        return staves.enumerated().map { j, s in
            let marks = self.marks[i][j]
            s.setBoundaryModifiers(
                (start ? marks.start : []) + (end ? marks.end : []),
                notePadding: start ? continuationPadding[ObjectIdentifier(s)] ?? 0 : 0
            )
            let bar = s.getModifiers(position: .end, category: Barline.category).first as? Barline
            return max(s.getX() + s.getWidth() - s.getNoteEndX(), -(bar?.getLayoutMetrics()?.xMin ?? 0))
        }.max() ?? -.infinity
    }

    private func units(_ padding: Double) throws -> [Unit] {
        score.staves.joined().forEach { $0.setBoundaryModifiers([]) }
        var result: [Unit] = []
        var i = 0
        while i < score.systems.count {
            var last = i
            if options.compressRests && plainRest(i) {
                while last + 1 < score.systems.count && plainRest(last + 1) { last += 1 }
            }
            let sys = score.systems[i]
            // Give end modifiers a finite reference edge before measuring intrinsic width.
            sys.setX(0).setY(0).setWidth(1)
            let measure = { (start: Bool, end: Bool) throws -> Double in
                let tail = self.boundaryWidth(i, start, end)
                try sys.setWidth().formatThrowing(row: SystemRowLayout(endPadding: tail))
                return sys.getWidth()
            }
            let base = try measure(false, false)
            let prefix = try measure(true, false) - base
            // A compressed run ends before a structural change, using the final source measure's courtesy signs.
            let tail = endWidth(i, last)
            let reserve = spans.filter { $0.first.measure == i && $0.label != nil }
                .reduce(0.0) { w, s in max(w, s.label!.getWidth() + 12) }
            let headers = [false, true].map { atStart in
                headerParts(i, atStart).reduce(0.0) { w, p in w + p.mark.getWidth() + (p.boxed ? 12 : 7) }
            }
            result.append(Unit(
                first: i,
                last: last,
                breakUnit: BreakUnit(
                    width: max(base + padding, last > i ? 68 : 0, reserve, headers[0], headers[1]),
                    start: max(0, prefix),
                    end: tail,
                    after: 0,
                    breakBefore: boundaries[i]?.breakBefore
                )
            ))
            i = last + 1
        }
        return result
    }

    private func endWidth(_ i: Int, _ last: Int) -> Double {
        let plain = boundaryWidth(i, false, false)
        return max(0, install(i, last, false, true) - plain)
    }

    private func install(_ i: Int, _ last: Int, _ start: Bool, _ end: Bool) -> Double {
        if i == last { return boundaryWidth(i, start, end) }
        return score.staves[i].enumerated().map { j, stave in
            let m = marks[i][j]
            stave.setBoundaryModifiers((start ? m.start : []) + (end ? marks[last][j].end : []))
            return stave.getX() + stave.getWidth() - stave.getNoteEndX()
        }.max() ?? -.infinity
    }

    private func indent(_ measure: Int) -> Double {
        let widths = names[measure].enumerated().map { j, n in
            ((measure == 0 || spec.staves[j].measures[measure].instrument != nil) ? n.full : n.short)?.getWidth() ?? 0
        }
        let w = max(0, widths.max() ?? 0)
        return (w != 0 ? w + 10 : 0) + Double(groups.count) * 9
    }

    /// Preserve staves carrying a spanning instruction or cross-staff note, including silent middle rows.
    private func visible(_ first: Int, _ last: Int) -> [Int] {
        let indices = Array(spec.staves.indices)
        if !options.hideEmptyStaves { return indices }
        var used = Set<Int>()
        for i in first...last {
            for n in score.notes[i].flatMap({ $0.flatMap { $0 } }) {
                guard let n = n as? Note else { continue }
                if let sn = n as? StaveNote, sn.isRest(), sn.restLine == nil, sn.getModifiers().isEmpty { continue }
                let stave = n.checkStave()
                if let index = score.staves[i].firstIndex(where: { $0 === stave }) { used.insert(index) }
            }
        }
        for s in spans where s.first.measure <= last && first <= s.last.measure {
            used.insert(s.first.staff)
            used.insert(s.last.staff)
        }
        return used.isEmpty ? [0] : indices.filter { used.contains($0) }
    }

    private func suppress(_ i: Int, _ visible: [Int], _ compressed: Bool, _ omitted: Bool) {
        if omitted { hidden.insert(ObjectIdentifier(score.systems[i])) }
        for (j, s) in score.staves[i].enumerated() where omitted || !visible.contains(j) {
            hidden.insert(ObjectIdentifier(s))
        }
        for voice in score.voices[i].joined() {
            let ticks = voice.getTickables()
            let silent = ticks.allSatisfy { n in
                guard let stave = n.getStave() ?? voice.getStave() else { return false }
                return hidden.contains(ObjectIdentifier(stave))
            }
            if omitted || compressed || silent {
                hidden.insert(ObjectIdentifier(voice))
                ticks.forEach { hidden.insert(ObjectIdentifier($0)) }
            }
        }
    }

    /// Lay out the rows. Called by `Sheet.format()`.
    @discardableResult
    public func format(_ options: SheetOptions) throws -> [ContinuousRow] {
        // VexFlow 5.6.0: a verse can be attached after composition. Resolve its current mark before every reflow.
        for k in spans.indices {
            guard let id = spans[k].spec.syllableId, !id.isEmpty else { continue }
            let matches = spans[k].first.note.getModifiers().compactMap { $0 as? Annotation }
                .filter { $0.getAttribute("id") == id }
            if matches.count != 1 { throw invalid("Expected one lyric annotation on the source note: " + id) }
            spans[k].syllable = matches[0]
        }
        // A caller may attach the native beam after composition. Validate every owner before modifying either voice.
        let eighths = splitChords.filter { $0.upper.getDuration() == "8" }
        for chord in eighths
        where (chord.upper.getBeam() != nil) == (chord.lower.getBeam() != nil)
            || chord.upper.getStemDirection() != chord.lower.getStemDirection() {
            throw invalid(
                "A split eighth-note chord needs a beam on exactly one of its two notes and matching stem directions."
            )
        }
        for chord in eighths { linkSplitStem(chord.upper, chord.lower) }
        for span in spans { span.beam?.clearRows() }
        var units = try self.units(options.measurePadding)
        var padding: [ObjectIdentifier: Double] = [:]
        repeat {
            for span in spans { span.beam?.clearRows() }
            hidden.removeAll()
            diagnostics.removeAll()
            fragments.removeAll()
            rows.removeAll()
            drawing = []
            for k in units.indices { units[k].after = padding[ObjectIdentifier(score.systems[units[k].first])] ?? 0 }
            let groups = chooseSystemBreaks(
                units.map { $0.breakUnit },
                width: options.width,
                gap: options.measureGap,
                indent: { self.indent(units[$0].first) },
                mode: self.options.mode ?? .balanced
            )
            var y = options.y
            for indices in groups {
                let row = try layoutRow(indices.map { units[$0] }, options, y)
                rows.append(row)
                y += row.height + options.rowGap
            }
        } while try reserveChordSpacing(rows.map { $0.systems }, &padding)
        for s in spans {
            let indices = fragments.indices.filter { fragments[$0].id == s.spec.id }
            let total = indices.reduce(0.0) { $0 + fragments[$1].x2 - fragments[$1].x1 }
            var prior = 0.0
            for k in indices {
                let length = fragments[k].x2 - fragments[k].x1
                fragments[k].progress = (prior / total, (prior + length) / total)
                prior += length
                if fragments[k].kind == .glissando {
                    let measures = rows[fragments[k].row].measures
                    let firstStave = score.staves[measures[0] - 1][s.first.staff]
                    let lastStave = score.staves[measures[measures.count - 1] - 1][s.last.staff]
                    fragments[k].y1 = glissandoY(s, firstStave, fragments[k].progress.0)
                    fragments[k].y2 = glissandoY(s, lastStave, fragments[k].progress.1)
                }
                let fragment = fragments[k], label = s.label, bendLabel = s.bendLabel
                if s.beam == nil { drawing.append { ctx in drawSpan(ctx, fragment, label: label, bendLabel: bendLabel) } }
            }
        }
        for span in spans {
            guard let beam = span.beam else { continue }
            beam.finishRows()
            drawing.append { ctx in try beam.setContext(ctx).drawWithStyle() }
        }
        return rows
    }

    /// Measure native ink once the horizontal positions and beam fits for this row are known.
    private func measureStaffInk(_ positions: [PlacedMeasure], _ visible: [Int]) -> [(top: Double, bottom: Double)] {
        // Staff-relative extrema exclude crossing beams and their stems, which are refitted to these very gaps.
        var ink = spec.staves.map { _ in (top: Double.infinity, bottom: -Double.infinity) }
        for p in positions {
            let u = p.u
            for j in visible {
                let stave = score.staves[u.first][j]
                let base = stave.getY()
                func take(_ top: Double, _ bottom: Double) {
                    ink[j].top = min(ink[j].top, top - base)
                    ink[j].bottom = max(ink[j].bottom, bottom - base)
                }
                take(stave.getYForLine(0) - stave.space(1.6), stave.getYForLine(Double(stave.getNumLines() - 1)) + stave.space(1.6))
                for m in stave.getModifiers() {
                    var boxes: [BoundingBox] = []
                    if let clef = m as? Clef, let box = try? clef.getInkBounds() {
                        boxes = [box]
                    } else if let time = m as? TimeSignature, let box = try? time.getInkBounds() {
                        boxes = [box]
                    } else if let key = m as? KeySignature {
                        boxes = key.getInkParts()
                    }
                    for box in boxes { take(box.y, box.y + box.h) }
                }
                if u.first == u.last {
                    for n in score.notes[u.first].flatMap({ $0.flatMap { $0 } }) {
                        if let tab = n as? TabNote, tab.getStave() === stave, tab.hasStem() {
                            let e = tab.getStemExtents()
                            take(min(e.topY, e.baseY), max(e.topY, e.baseY))
                        }
                        guard let n = n as? StaveNote, n.getStave() === stave else { continue }
                        let shared = splitStemFor(n)
                        let beam = shared.map { $0.owner.getBeam() } ?? n.getBeam()
                        let tipStave = beam != nil ? beamStave(n) : nil
                        let bridge = !(beam is ContinuousBeam)
                            && (beam?.getNotes().contains { beamStave($0) !== tipStave } ?? false)
                        let parts = bridge && shared == nil ? n.getHeadInk() : ((try? measureEngraving(n))?.parts ?? [])
                        for (index, box) in parts.enumerated() {
                            // The shared stem spans this very gap and must not increase it.
                            if shared?.owner !== n || index != n.noteHeads.count { take(box.y, box.y + box.h) }
                        }
                        if let beam, !(beam is ContinuousBeam), !bridge, tipStave === stave,
                           let box = beam.getBoundingBox() {
                            take(box.y, box.y + box.h)
                        }
                        for t in n.getTupletStack() {
                            if let box = t.getBoundingBox() { take(box.y, box.y + box.h) }
                        }
                    }
                }
            }
        }
        return ink
    }

    /// Share the largest required staff distance across all measures, bounded to four native refits.
    private func alignStaves(_ positions: [PlacedMeasure], _ visible: [Int], _ origin: Double, _ offsets: inout [Double]) throws -> Bool {
        // A native phrase may demand a larger separation. Propagate that minimum to every measure.
        for pass in 0..<4 {
            var next = offsets
            for p in positions {
                try p.sys.setY(origin).formatThrowing(row: SystemRowLayout(staffOffsets: offsets, endPadding: p.endPadding))
                let staves = p.sys.getStaves()
                for k in 1..<max(1, visible.count) {
                    let a = visible[k - 1], b = visible[k]
                    next[b] = max(next[b], next[a] + staves[b].getY() - staves[a].getY())
                }
            }
            if visible.allSatisfy({ abs(next[$0] - offsets[$0]) < 0.01 }) { return true }
            if pass == 3 { return false }
            offsets = next
        }
        return false
    }

    /// Reconcile staff envelopes across all measures in a row, then translate the entire solved row once.
    private func layoutRow(_ units: [Unit], _ options: SheetOptions, _ y: Double) throws -> ContinuousRow {
        let first = units[0].first
        let last = units[units.count - 1].last
        let visible = self.visible(first, last)
        let spans = self.spans.filter { $0.first.measure <= last && first <= $0.last.measure }
        let indent = self.indent(first)
        let minimum = indent
            + units.enumerated().reduce(0) { $0 + $1.element.width + ($1.offset + 1 < units.count ? $1.element.after : 0) }
            + units[0].start + units[units.count - 1].end
            + Double(units.count - 1) * options.measureGap
        let extra = options.justify ? max(0, options.width - minimum) / Double(units.count) : 0
        var x = options.x + indent
        var offsets = spec.staves.map { _ in 0.0 }
        var positions: [PlacedMeasure] = []
        for (k, u) in units.enumerated() {
            let begin = k == 0, end = k == units.count - 1
            let sys = score.systems[u.first]
            sys.setX(x).setY(0)
            let chordPadding = end ? 0 : u.after
            let endPadding = install(u.first, u.last, begin, end) + chordPadding
            let width = u.width + extra + chordPadding + (begin ? u.start : 0) + (end ? u.end : 0)
            try sys.setWidthThrowing(width).formatThrowing(row: SystemRowLayout(endPadding: endPadding))
            for j in 1..<max(1, visible.count) {
                let staves = sys.getStaves(), b = visible[j]
                let nominal = staves[b].getY() - staves[b - 1].getY()
                offsets[b] = max(offsets[b], nominal)
            }
            for i in u.first...u.last { suppress(i, visible, u.first != u.last, i != u.first) }
            x += width + options.measureGap
            positions.append(PlacedMeasure(u: u, sys: sys, endPadding: endPadding))
        }
        var fitted: [(beam: Beam, staff: Int)] = []
        for s in spans {
            if let beam = s.beam { fitted.append((try beam.measureRow(first, last), s.first.staff)) }
        }
        var ink = measureStaffInk(positions, visible)
        for (beam, staff) in fitted {
            if let bounds = beam.getBoundingBox() {
                let staveY = score.staves[first][staff].getY()
                ink[staff].top = min(ink[staff].top, bounds.y - staveY)
                ink[staff].bottom = max(ink[staff].bottom, bounds.y + bounds.h - staveY)
            }
            beam.resetLayout()
        }
        var laneOf: [Int] = []
        // Prefer the nearest free lane. Non-overlapping spans can reuse it.
        var laneEnds: [String: [Int]] = [:]
        for s in spans {
            if s.beam != nil || (s.spec.kind == .tie && s.spec.bend == nil) || s.spec.kind == .slur
                || s.spec.kind == .glissando {
                laneOf.append(0)
                continue
            }
            if let syllable = s.syllable {
                // A continuation row may have no sung words of its own. Include the extender in that staff's envelope.
                let stave = score.staves[first][s.first.staff]
                let relativeY = lyricBaseline(syllable, stave) - stave.getY()
                ink[s.first.staff].top = min(ink[s.first.staff].top, relativeY)
                ink[s.first.staff].bottom = max(ink[s.first.staff].bottom, relativeY + 2)
                laneOf.append(0)
                continue
            }
            let side = s.spec.bend != nil || spanAbove(s.spec), staff = s.first.staff
            let key = "\(staff)-\(side)"
            var ends = laneEnds[key] ?? []
            var lane = ends.firstIndex { $0 < s.first.measure } ?? -1
            if lane < 0 { lane = ends.count }
            if lane == ends.count { ends.append(s.last.measure) } else { ends[lane] = s.last.measure }
            laneEnds[key] = ends
            laneOf.append(lane)
        }
        let limits = ink.enumerated().map { j, bounds -> (top: Double, bottom: Double) in
            let space = score.staves[first][j].space(1)
            let above = Double(laneEnds["\(j)-true"]?.count ?? 0)
            let below = Double(laneEnds["\(j)-false"]?.count ?? 0)
            return (bounds.top - space * (2 + above * 2.5), bounds.bottom + space * (1 + below * 2.5))
        }
        for j in 1..<max(1, visible.count) {
            let a = visible[j - 1], b = visible[j]
            offsets[b] = offsets[a] + max(offsets[b], limits[a].bottom - limits[b].top + 8)
        }
        let instrumentChange = units.enumerated().contains { k, u in
            k > 0 && spec.staves.contains { $0.measures[u.first].instrument != nil }
        }
        let header: Double = instrumentChange
            || units.contains(where: { boundaries[$0.first]?.rehearsal != nil || boundaries[$0.first]?.navigation != nil })
            || self.options.measureNumbers ? 20 : 0
        let origin = y + header - limits[visible[0]].top
        let stable = try alignStaves(positions, visible, origin, &offsets)
        let measures = Array((first + 1)...(last + 1))
        if !stable { diagnostics.append(ContinuousDiagnostic(code: .staffSpacingLimit, measures: measures)) }
        let bottomStaff = visible[visible.count - 1]
        let row = ContinuousRow(
            systems: positions.map { $0.sys },
            x: options.x,
            y: y,
            width: x - options.measureGap - options.x,
            height: origin - y + offsets[bottomStaff] + limits[bottomStaff].bottom,
            overflow: max(0, minimum - options.width),
            measures: measures,
            visibleStaves: visible.map { spec.staves[$0].id },
            restGroups: units.filter { $0.last > $0.first }.map { Array(($0.first + 1)...($0.last + 1)) }
        )
        if row.overflow != 0 { diagnostics.append(ContinuousDiagnostic(code: .rowOverflow, measures: measures)) }
        decorate(units, visible, first == 0, y + 15)
        for chord in splitChords where chord.measure >= first && chord.measure <= last {
            let a = chord.upper, b = chord.lower
            let x = a.getStemX()
            let top = a.getYs().max() ?? 0
            let bottom = b.getYs().min() ?? 0
            if abs(x - b.getStemX()) > Stem.WIDTH {
                diagnostics.append(ContinuousDiagnostic(code: .splitStemAlignment, measures: [chord.measure + 1], source: chord.id))
            } else if splitStemFor(a) == nil {
                drawing.append { ctx in ctx.fillRect(x - Stem.WIDTH / 2, top, Stem.WIDTH, bottom - top) }
            }
        }
        for (index, s) in spans.enumerated() {
            if let beam = s.beam {
                fragments.append(try beam.placeRow(first, last, rows.count, s.spec.id))
                continue
            }
            let staff = s.first.staff
            let lane = Double(laneOf[index])
            let yBase = origin + offsets[staff]
                + (s.spec.bend != nil || spanAbove(s.spec)
                    ? ink[staff].top - lane * 25 - 4 : ink[staff].bottom + lane * 25 + 14)
            addFragment(s, units, row, yBase)
        }
        return row
    }

    /// Carry the source syllable's distance from its top staff line to each continuation. (VexFlow 5.6.0)
    private func lyricBaseline(_ word: Annotation, _ stave: Stave) -> Double {
        let source = word.checkAttachedNote().checkStave()
        let y = (try? word.computeY().y) ?? source.getYForLine(0)
        let spaces = (y + word.getYShift() - source.getYForLine(0)) / source.space(1)
        return stave.getYForLine(0) + stave.space(spaces)
    }

    /// Keep continuation hooks and labels on the correct end when a span crosses a row.
    private func addFragment(_ s: ResolvedSpan, _ units: [Unit], _ row: ContinuousRow, _ baseline: Double) {
        let first = units[0].first
        let last = units[units.count - 1].first
        let starts = s.first.measure >= first
        let ends = s.last.measure <= units[units.count - 1].last
        let kind = s.spec.kind, above = spanAbove(s.spec)
        let startStaff = score.staves[first][s.first.staff]
        let endStaff = score.staves[last][ends ? s.last.staff : s.first.staff]
        let space = startStaff.space(1)
        let sign: Double = above ? -1 : 1
        var x1 = starts ? s.first.note.getAbsoluteX() : startStaff.getNoteStartX() + 2
        var x2 = ends ? s.last.note.getAbsoluteX() + s.last.note.getGlyphWidth() : endStaff.getNoteEndX() - 3
        var y1 = baseline, y2 = baseline
        if let syllable = s.syllable {
            y1 = lyricBaseline(syllable, startStaff)
            y2 = y1
            if starts, let x = try? syllable.computeX().x, let y = try? syllable.computeY().y {
                let ink = syllable.getTextInk(x, y)
                x1 = ink.x + ink.w + space * 0.35
            }
            if ends, let last = s.last.note as? StaveNote {
                x2 = last.getNoteHeadBeginX() + last.getGlyphWidth()
            }
        }
        if kind == .tie || kind == .slur {
            if starts { x1 = s.first.note.getTieRightX() }
            if ends { x2 = s.last.note.getTieLeftX() }
            if let string = s.spec.string {
                // Follow the same physical string at both row edges, with clearance for the fret numbers.
                if !starts { x1 -= continuationPadding[ObjectIdentifier(startStaff)] ?? 0 }
                let line = Double(string - 1)
                let clearance = sign * space * 0.3
                y1 = (starts ? s.first.note.checkStave() : startStaff).getYForLine(line) + clearance
                y2 = (ends ? s.last.note.checkStave() : endStaff).getYForLine(line) + clearance
            } else {
                y1 = (starts
                    ? s.first.note.getYs()[s.spec.fromHead ?? 0]
                    : continuationPitch(s.first, startStaff, s.spec.fromHead ?? 0)) + sign * space * (starts ? 0.5 : 1.1)
                y2 = (ends
                    ? s.last.note.getYs()[s.spec.toHead ?? 0]
                    : continuationPitch(s.last, endStaff, s.spec.toHead ?? 0)) + sign * space * (ends ? 0.5 : 1.1)
            }
        }
        if kind == .glissando {
            if starts, let note = s.first.note as? StaveNote {
                let head = note.getHeadInk()[s.spec.fromHead ?? 0]
                x1 = head.x + head.w + space * 0.3
            } else if !starts {
                x1 -= continuationPadding[ObjectIdentifier(startStaff)] ?? 0
            }
            if ends, let note = s.last.note as? StaveNote {
                let head = note.getHeadInk()[s.spec.toHead ?? 0]
                x2 = head.x - endStaff.space(0.3)
            }
        }
        if kind == .volta {
            x1 = starts ? score.staves[s.first.measure][s.first.staff].getX() + 1 : startStaff.getX() + 1
            x2 = ends ? score.staves[s.last.measure][s.last.staff].getNoteEndX() : endStaff.getNoteEndX()
        }
        // On a short mute, keep the closing hook at the last string attack and let the label lead into it.
        if kind == .palmMute && starts, let label = s.label {
            x1 = max(startStaff.getX(), min(x1, x2 - label.getWidth() - space))
        }
        if kind == .hyphen && ends { x2 = s.last.note.getAbsoluteX() - space * 0.3 }
        if x2 <= x1 || (starts && s.label != nil && x1 + s.label!.getWidth() > x2) {
            diagnostics.append(ContinuousDiagnostic(code: .spanOverflow, measures: row.measures, source: s.spec.id))
            if x2 <= x1 { return }
        }
        var fragment = SpanFragment(
            id: s.spec.id,
            kind: kind,
            row: rows.count,
            part: starts ? (ends ? .single : .first) : ends ? .last : .middle,
            x1: x1,
            x2: x2,
            y1: y1,
            y2: y2,
            progress: (0, 1),
            strings: s.spec.string.map { [$0] } ?? (kind == .palmMute ? s.spec.strings : nil),
            from: (kind == .palmMute || s.spec.string != nil) && starts ? s.spec.from : nil,
            to: (kind == .palmMute || s.spec.string != nil) && ends ? s.spec.to : nil,
            rise: nil,
            above: above,
            space: space
        )
        if let bend = s.spec.bend, let bendLabel = s.bendLabel, let string = s.spec.string {
            fragment.bend = layoutTiedBend(
                bend,
                starts ? s.first.note : nil,
                ends ? s.last.note : nil,
                x1,
                endStaff.getNoteEndX() - space * 0.35,
                startStaff.getYForLine(Double(string - 1)),
                baseline,
                space,
                bendLabel
            )
        }
        if s.spec.niente == true && kind == .crescendo && starts { fragment.nienteTip = nienteTip(x1, y1, space, .left) }
        if s.spec.niente == true && kind == .diminuendo && ends { fragment.nienteTip = nienteTip(x2, y2, space, .right) }
        if kind == .tie || kind == .slur {
            let events = units.flatMap { u -> [StaveNote] in
                let staves = score.staves[u.first]
                return score.notes[u.first].flatMap { $0.flatMap { $0 } }.compactMap { n in
                    guard let n = n as? StaveNote else { return nil }
                    return n.getStave() === staves[s.first.staff] || n.getStave() === staves[s.last.staff] ? n : nil
                }
            }
            let obstacles = events.filter { $0 !== s.first.note && $0 !== s.last.note }
                .flatMap { (try? measureEngraving($0))?.parts ?? [] }
            if kind == .slur {
                func endpoint(_ n: Note, _ y: Double) -> Double {
                    n.hasStem() && Double(n.getStemDirection().rawValue) == -sign
                        ? n.getStemExtents().topY + sign * space * 0.4
                        : y
                }
                if starts { fragment.y1 = endpoint(s.first.note, y1) }
                if ends { fragment.y2 = endpoint(s.last.note, y2) }
                let within = obstacles.filter { $0.x + $0.w > x1 && $0.x < x2 }
                let edge = above
                    ? ([y1, y2] + within.map { $0.y }).min()! - space * 0.6
                    : ([y1, y2] + within.map { $0.y + $0.h }).max()! + space * 0.6
                if !starts { fragment.y1 = edge }
                if !ends { fragment.y2 = edge }
            }
            if !fitSpan(&fragment, obstacles) {
                diagnostics.append(ContinuousDiagnostic(code: .curveCollision, measures: row.measures, source: s.spec.id))
            }
        }
        fragments.append(fragment)
    }

    /// Add labels, connectors and numbered rests after all native positions have settled.
    private func decorate(_ units: [Unit], _ visible: [Int], _ firstRow: Bool, _ headerY: Double) {
        let head = score.staves[units[0].first]
        let groupIndent = Double(groups.count) * 9
        for j in visible {
            let names = self.names[units[0].first][j]
            let full = firstRow || spec.staves[j].measures[units[0].first].instrument != nil
            if let label = full ? names.full : names.short {
                let stave = head[j]
                drawing.append { ctx in
                    label.renderText(ctx, xPos: stave.getX() - groupIndent - 7 - label.getWidth(), yPos: stave.getYForLine(2) + 4)
                }
            }
        }
        for (index, g) in groups.enumerated() {
            let members = visible.filter { $0 >= g.first && $0 <= g.last }
            if members.count < 2 { continue }
            let top = members[0], bottom = members[members.count - 1]
            let connector = StaveConnector(topStave: head[top], bottomStave: head[bottom])
                .setType(g.type == .brace ? .brace : .bracket)
            connector.setXShift(-Double(index) * 8)
            drawing.append { ctx in try connector.setContext(ctx).drawWithStyle() }
            if g.barlines {
                for u in units {
                    let staves = score.staves[u.first]
                    let line = StaveConnector(topStave: staves[top], bottomStave: staves[bottom]).setType(.singleRight)
                    drawing.append { ctx in try line.setContext(ctx).drawWithStyle() }
                }
            }
        }
        for (k, u) in units.enumerated() {
            let staves = score.staves[u.first]
            var x = staves[visible[0]].getX() + 2
            for (mark, boxed) in headerParts(u.first, k == 0) {
                let left = x + (boxed ? 3 : 0)
                drawing.append { ctx in
                    if boxed {
                        let box = mark.getTextInk(left, headerY)
                        ctx.beginPath()
                        ctx.rect(box.x - 3, box.y - 3, box.w + 6, box.h + 6)
                        ctx.stroke()
                    }
                    mark.renderText(ctx, xPos: left, yPos: headerY)
                }
                x += mark.getWidth() + (boxed ? 12 : 7)
            }
            if u.last > u.first {
                for j in visible {
                    let count = u.last - u.first + 1
                    let rest = MultiMeasureRest(numberOfMeasures: count, options: MultiMeasureRestRenderOptions(numberOfMeasures: count))
                        .setStave(staves[j])
                    drawing.append { ctx in try rest.setContext(ctx).drawWithStyle() }
                }
            }
        }
    }

    /// Draw the row-dependent notation: names, connectors, headers, numbered rests, shared stems and spans.
    public func draw(_ context: RenderContext) throws {
        for draw in drawing { try draw(context) }
    }
}
