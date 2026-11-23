// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/easyscore/composition.ts` (VexFlow 5.8.0).
// Structured construction delegates timing and layout to native Voice, System, and Sheet objects.

import Foundation

/// Written pitches stay literal, even when a key signature is displayed.
public struct EasyScoreStaffState: Equatable {
    public var clef: ClefName?
    public var key: String?
    public var time: TimeSignatureSpec?
    /// Hide or reveal the meter sign while preserving the meter used for timing and beaming. (VexFlow 5.6.0)
    public var showTimeSignature: Bool?

    public init(
        clef: ClefName? = nil, key: String? = nil, time: TimeSignatureSpec? = nil, showTimeSignature: Bool? = nil
    ) {
        self.clef = clef
        self.key = key
        self.time = time
        self.showTimeSignature = showTimeSignature
    }
}

/// Resolved staff state (upstream `Required<EasyScoreStaffState>`).
struct EasyScoreResolvedStaffState: Equatable {
    var clef: ClefName
    var key: String
    var time: TimeSignatureSpec
    var showTimeSignature: Bool = true

    func merging(_ change: EasyScoreStaffState) -> EasyScoreResolvedStaffState {
        EasyScoreResolvedStaffState(
            clef: change.clef ?? clef, key: change.key ?? key, time: change.time ?? time,
            showTimeSignature: change.showTimeSignature ?? showTimeSignature
        )
    }
}

/// A written mark anchored by note ID on its owning staff and measure. (VexFlow 5.6.0)
/// A chord mark has either literal `text` or a spelled `harmony` (VexFlow 5.7.0).
public struct EasyScoreLeadMark: Equatable, Sendable {
    public var note: String
    public var text: String
    /// A spelled harmony, printed with `NotationSpelling.chordText`. (VexFlow 5.7.0)
    public var harmony: ChordHarmony?

    public init(note: String, text: String) {
        self.note = note
        self.text = text
    }

    /// A spelled chord. Use `NotationSpelling.transposeChord` to transpose it. (VexFlow 5.7.0)
    public init(note: String, harmony: ChordHarmony) {
        self.note = note
        self.text = ""
        self.harmony = harmony
    }
}

/// A lyric connector stays within its verse and measure. (VexFlow 5.6.0)
public struct EasyScoreLyricMark: Equatable, Sendable {
    public var note: String
    public var text: String
    /// A second syllable sharing this attack and its verse baseline. (VexFlow 5.7.0)
    public var elideWith: String?
    public var hyphenAfter: Bool
    public var extendTo: String?

    public init(
        note: String, text: String, hyphenAfter: Bool = false, extendTo: String? = nil, elideWith: String? = nil
    ) {
        self.note = note
        self.text = text
        self.elideWith = elideWith
        self.hyphenAfter = hyphenAfter
        self.extendTo = extendTo
    }
}

/// One verse: ordered syllables that form a separate lyric lane. A verse can give a printed stanza label on the
/// measure where it starts (upstream `LyricMark[] | { stanza, syllables }`). An array literal of
/// `EasyScoreLyricMark` makes a verse without a label. (VexFlow 5.8.0)
public struct EasyScoreVerse: Equatable, Sendable, ExpressibleByArrayLiteral {
    public var stanza: String?
    public var syllables: [EasyScoreLyricMark]

    public init(stanza: String? = nil, syllables: [EasyScoreLyricMark]) {
        self.stanza = stanza
        self.syllables = syllables
    }

    public init(arrayLiteral elements: EasyScoreLyricMark...) {
        self.init(syllables: elements)
    }
}

/// Explicit signs survive key-aware generation, including cautionaries and microtones. (VexFlow 5.3.0)
public struct EasyScoreGraceAccidental {
    public var index: Int
    public var type: String
    public var cautionary: Bool

    public init(index: Int, type: String, cautionary: Bool = false) {
        self.index = index
        self.type = type
        self.cautionary = cautionary
    }
}

/// One grace pitch: the native grace note fields plus explicit accidentals. (VexFlow 5.3.0)
public struct EasyScoreGracePitchSpec {
    public var note: GraceNoteStruct
    public var accidentals: [EasyScoreGraceAccidental]

    public init(_ note: GraceNoteStruct, accidentals: [EasyScoreGraceAccidental] = []) {
        self.note = note
        self.accidentals = accidentals
    }
}

/// Grace notes before or after the host note. (VexFlow 5.3.0)
public enum EasyScoreGraceSide: String, Sendable {
    case before
    case after
}

/// The host's complete grace group. (VexFlow 5.3.0)
public struct EasyScoreGraceGroupSpec {
    public var side: EasyScoreGraceSide
    public var notes: [EasyScoreGracePitchSpec]
    public var slur: Bool
    public var beam: Bool

    public init(side: EasyScoreGraceSide, notes: [EasyScoreGracePitchSpec], slur: Bool = false, beam: Bool = false) {
        self.side = side
        self.notes = notes
        self.slur = slur
        self.beam = beam
    }
}

/// Voice content. Typed wrappers add IDs and cross-staff assignment without changing native note fields.
public enum EasyScoreContent {
    /// EasyScore notation, for example `"C4/q, D4"`.
    case notation(String)
    /// A typed staff note, with an optional score ID, cross-staff target (stave spec ID)
    /// and grace group (VexFlow 5.3.0).
    case note(StaveNoteStruct, id: String? = nil, stave: String? = nil, grace: EasyScoreGraceGroupSpec? = nil)
    /// A typed tab note.
    case tab(TabNoteStruct, id: String? = nil, stave: String? = nil, drawStem: Bool = false)
    /// An owned native tickable that is not in a voice.
    case tickable(Tickable)
    /// An inline staff change (clef, key, time).
    case change(EasyScoreStaffState)
}

/// Tuplet indexes count timed notes, excluding inline signatures and barlines.
public struct EasyScoreTupletSpec {
    public var start: Int
    public var count: Int
    public var options: TupletOptions

    public init(start: Int, count: Int, options: TupletOptions = TupletOptions()) {
        self.start = start
        self.count = count
        self.options = options
    }
}

public struct EasyScoreVoiceSpec {
    public var notes: [EasyScoreContent]
    /// `"auto"`, `"up"` or `"down"`.
    public var stem: String
    public var softmaxFactor: Double?
    public var tuplets: [EasyScoreTupletSpec]
    /// `nil` disables automatic beams (upstream `autoBeam: false`).
    public var autoBeam: EasyScoreAutoBeamOptions?

    public init(
        notes: [EasyScoreContent], stem: String = "auto", softmaxFactor: Double? = nil,
        tuplets: [EasyScoreTupletSpec] = [], autoBeam: EasyScoreAutoBeamOptions? = nil
    ) {
        self.notes = notes
        self.stem = stem
        self.softmaxFactor = softmaxFactor
        self.tuplets = tuplets
        self.autoBeam = autoBeam
    }

    /// One notation string (upstream `notes: string`).
    public init(
        _ notation: String, stem: String = "auto", softmaxFactor: Double? = nil,
        tuplets: [EasyScoreTupletSpec] = [], autoBeam: EasyScoreAutoBeamOptions? = nil
    ) {
        self.init(notes: [.notation(notation)], stem: stem, softmaxFactor: softmaxFactor, tuplets: tuplets, autoBeam: autoBeam)
    }
}

/// `span` is the actual duration of a pickup; `time` remains its displayed meter.
/// Instrument names shown at a measure where the instrument changes. (VexFlow 5.4.0)
public struct EasyScoreInstrumentName: Equatable, Sendable {
    public var name: String
    public var shortName: String?

    public init(name: String, shortName: String? = nil) {
        self.name = name
        self.shortName = shortName
    }
}

public struct EasyScoreMeasureSpec {
    /// Instrument change at this measure. Continuous layout prints it. (VexFlow 5.4.0)
    public var instrument: EasyScoreInstrumentName?
    public var clef: ClefName?
    public var key: String?
    public var time: TimeSignatureSpec?
    public var voices: [EasyScoreVoiceSpec]
    public var span: VoiceTime?
    /// Hide or reveal the meter sign from this measure on. (VexFlow 5.6.0)
    public var showTimeSignature: Bool?
    /// The barline drawn at this measure's right edge. (VexFlow 5.6.0)
    public var endBarline: BarlineType?
    /// Literal chord names sharing a lane above their notes. (VexFlow 5.6.0)
    public var chords: [EasyScoreLeadMark]
    /// Each ordered list of syllables forms a separate lyric lane. (VexFlow 5.6.0)
    /// A verse can give a printed stanza label on the measure where it starts. (VexFlow 5.8.0)
    public var verses: [EasyScoreVerse]

    public init(
        clef: ClefName? = nil, key: String? = nil, time: TimeSignatureSpec? = nil,
        span: VoiceTime? = nil, voices: [EasyScoreVoiceSpec], instrument: EasyScoreInstrumentName? = nil,
        showTimeSignature: Bool? = nil, endBarline: BarlineType? = nil, chords: [EasyScoreLeadMark] = [],
        verses: [EasyScoreVerse] = []
    ) {
        self.showTimeSignature = showTimeSignature
        self.endBarline = endBarline
        self.chords = chords
        self.verses = verses
        self.instrument = instrument
        self.clef = clef
        self.key = key
        self.time = time
        self.span = span
        self.voices = voices
    }
}

public enum EasyScoreStaveKind: Sendable {
    case stave
    case tab
}

/// Staves have aligned measure arrays. Missing or uneven measures are errors.
public struct EasyScoreStaveSpec {
    public var id: String
    /// Instrument name and abbreviation. Continuous layout prints them at system starts. (VexFlow 5.4.0)
    public var name: String?
    public var shortName: String?
    public var kind: EasyScoreStaveKind
    public var clef: ClefName?
    public var key: String?
    public var time: TimeSignatureSpec?
    /// Hide or reveal the meter sign while preserving the meter used for timing. (VexFlow 5.6.0)
    public var showTimeSignature: Bool?
    public var options: StaveOptions?
    public var spaceAbove: Double?
    public var spaceBelow: Double?
    public var measures: [EasyScoreMeasureSpec]

    public init(
        id: String, kind: EasyScoreStaveKind = .stave, clef: ClefName? = nil, key: String? = nil,
        time: TimeSignatureSpec? = nil, options: StaveOptions? = nil, spaceAbove: Double? = nil,
        spaceBelow: Double? = nil, measures: [EasyScoreMeasureSpec], name: String? = nil, shortName: String? = nil,
        showTimeSignature: Bool? = nil
    ) {
        self.showTimeSignature = showTimeSignature
        self.id = id
        self.name = name
        self.shortName = shortName
        self.kind = kind
        self.clef = clef
        self.key = key
        self.time = time
        self.options = options
        self.spaceAbove = spaceAbove
        self.spaceBelow = spaceBelow
        self.measures = measures
    }
}

/// IDs resolve only after all notes exist. Native handles remain available afterward.
public enum EasyScoreSpanSpec {
    case tie(from: String? = nil, to: String? = nil, firstIndexes: [Int] = [0], lastIndexes: [Int] = [0], text: String? = nil)
    case curve(from: String? = nil, to: String? = nil, options: CurveOptions = CurveOptions())
    case hairpin(from: String, to: String, type: HairpinType, options: HairpinRenderOptions? = nil)
}

public enum EasyScoreAccidentalPolicy: Sendable {
    case literal
    case keyAware
}

/// Include written grace pitches in key-aware state at their host onset. (VexFlow 5.3.0)
public enum EasyScoreGraceAccidentalPolicy: Sendable {
    case explicit
    case ordered
}

public enum EasyScoreSignaturePolicy: Sendable {
    case changes
    case everyMeasure
}

public enum EasyScoreCrossMeasureSpanPolicy: Sendable {
    case reject
    case manual
}

/// Layout policies are explicit. Sheet does not split spans or repeat signatures at row starts.
public struct EasyScoreCompositionSpec {
    public var staves: [EasyScoreStaveSpec]
    /// Lay out the composition as a continuous score: row-dependent signatures, names, spans split at
    /// system breaks, hidden empty staves and compressed rests. (VexFlow 5.4.0)
    public var continuous: ContinuousOptions?
    public var sheet: SheetOptions
    /// Options for each measure System. The sheet sets `factory`, `width`, `autoWidth` and `noJustification`.
    public var system: SystemOptions
    public var accidentals: EasyScoreAccidentalPolicy
    /// Include written grace pitches in key-aware state at their host onset. (VexFlow 5.3.0)
    public var graceAccidentals: EasyScoreGraceAccidentalPolicy?
    public var signatures: EasyScoreSignaturePolicy
    public var spans: [EasyScoreSpanSpec]
    public var crossMeasureSpans: EasyScoreCrossMeasureSpanPolicy

    public init(
        staves: [EasyScoreStaveSpec], sheet: SheetOptions = SheetOptions(), system: SystemOptions = SystemOptions(),
        accidentals: EasyScoreAccidentalPolicy = .literal, signatures: EasyScoreSignaturePolicy = .changes,
        spans: [EasyScoreSpanSpec] = [], crossMeasureSpans: EasyScoreCrossMeasureSpanPolicy = .reject,
        graceAccidentals: EasyScoreGraceAccidentalPolicy? = nil, continuous: ContinuousOptions? = nil
    ) {
        self.continuous = continuous
        self.graceAccidentals = graceAccidentals
        self.staves = staves
        self.sheet = sheet
        self.system = system
        self.accidentals = accidentals
        self.signatures = signatures
        self.spans = spans
        self.crossMeasureSpans = crossMeasureSpans
    }
}

/// Structured warnings identify deliberate native layout limitations.
public struct EasyScoreCompositionDiagnostic: Equatable, Sendable {
    public enum Code: String, Sendable {
        case manualSpan = "ManualSpan"
        case signaturePolicy = "SignaturePolicy"
    }

    public var code: Code
    public var message: String
}

/// Arrays are measure-first, then stave, then voice. Layout remains mutable through native objects.
public final class EasyScoreComposition {
    public let sheet: Sheet
    public internal(set) var systems: [System] = []
    public internal(set) var staves: [[Stave]] = []
    public internal(set) var voices: [[[Voice]]] = []
    public internal(set) var notes: [[[[Tickable]]]] = []
    public internal(set) var spans: [VexElement] = []
    public internal(set) var diagnostics: [EasyScoreCompositionDiagnostic] = []
    /// The staff-local measure and tick offset of each attack in an independently metered score, keyed by
    /// `ObjectIdentifier` of the tickable. `nil` for an aligned score. (VexFlow 5.8.0)
    public internal(set) var meterPositions: [ObjectIdentifier: MeterPosition]?
    private let score: EasyScore

    /// The source position of `tickable` in an independently metered score (upstream `meterPositions.get`).
    /// (VexFlow 5.8.0)
    public func getMeterPosition(_ tickable: Tickable) -> MeterPosition? {
        meterPositions?[ObjectIdentifier(tickable)]
    }

    init(sheet: Sheet, score: EasyScore) {
        self.sheet = sheet
        self.score = score
    }

    public func getElement(_ id: String) -> VexElement? { score.getElement(id) }

    public func getNote(_ id: String) throws -> Note { try score.getNote(id) }
}

/// Internal voice metadata keeps inline state and explicit cross-staff assignments separate from layout.
private struct BuiltVoice {
    var notes: [Tickable]
    var state: EasyScoreResolvedStaffState
    var changes: [(index: Int, state: EasyScoreResolvedStaffState)]
    var assignments: [(note: Note, stave: String)]
    var generated: Set<ObjectIdentifier>
}

/// Fail with a consistent construction error before drawing.
private func invalid(_ message: String) -> VexError {
    VexError("BadComposition", message)
}

/// Construct and validate the host's complete grace group inside the composition transaction. (VexFlow 5.3.0)
private func buildGraceGroup(_ score: EasyScore, _ spec: EasyScoreGraceGroupSpec) throws -> GraceNoteGroup {
    if spec.notes.isEmpty { throw invalid("Expected a nonempty before or after grace group.") }
    let children: [StemmableNote] = try spec.notes.map { pitch in
        let child = try score.make.graceNote(pitch.note)
        for accidental in pitch.accidentals {
            let mark = try score.make.accidental(type: accidental.type)
            if accidental.cautionary { mark.setAsCautionary() }
            try score.attach(child, mark, index: accidental.index)
        }
        return child
    }
    let group = try score.make.graceNoteGroup(notes: children, slur: spec.slur)
    group.setPosition(spec.side == .after ? .right : .left)
    if spec.beam { group.beamNotes() }
    return group
}

/// Return exact native ticks for a declared meter, including a pickup span.
private func ticksFor(_ time: VoiceTime) throws -> Fraction {
    try Voice(validating: time).getTotalTicks().clone()
}

private func timedTicks(_ notes: ArraySlice<Tickable>) -> Fraction {
    notes.reduce(Fraction(0, 1)) { sum, note in note.shouldIgnoreTicks() ? sum : sum.add(note.getTicks()) }
}

/// Scope staff defaults and build one voice's notation, without assigning a Voice yet.
private func buildVoice(
    _ score: EasyScore, _ spec: EasyScoreVoiceSpec, _ initial: EasyScoreResolvedStaffState, _ display: Bool,
    deferBeam: Bool = false
) throws -> BuiltVoice {
    try score.withDefaults(clef: initial.clef, time: initial.time, stem: spec.stem) { score in
        var state = initial
        var notes: [Tickable] = []
        var changes: [(index: Int, state: EasyScoreResolvedStaffState)] = []
        var assignments: [(note: Note, stave: String)] = []
        var generated = Set<ObjectIdentifier>()
        for item in spec.notes {
            switch item {
            case .notation(let text):
                notes.append(contentsOf: try score.notesThrowing(text))
                for mark in score.builder.getElements().accidentals.joined() {
                    if let mark { generated.insert(ObjectIdentifier(mark)) }
                }
            case .tickable(let tickable):
                if Factory.getOwner(tickable) !== score.factory {
                    throw invalid("Adopt native notes before composing them.")
                }
                if tickable.voice != nil {
                    throw invalid("Composition requires notes that are not already in a voice.")
                }
                notes.append(tickable)
            case .change(let change):
                let previous = state
                state = state.merging(change)
                changes.append((notes.count, state))
                if display {
                    if change.clef != nil { notes.append(try score.make.clefNote(type: state.clef, size: .small)) }
                    if change.key != nil {
                        notes.append(try score.make.keySigNote(key: state.key, cancelKey: previous.key, clef: state.clef))
                    }
                    if state.showTimeSignature && (change.time != nil || !previous.showTimeSignature) {
                        notes.append(try score.make.timeSigNote(time: state.time))
                    }
                }
                score.set(clef: state.clef, time: state.time)
            case .note(let noteStruct, let id, let stave, let grace):
                let note = try score.make.note(noteStruct)
                // VexFlow 5.6.0: each pitched head gets its own dots.
                for _ in 0..<note.writtenDots { Dot.buildAndAttach([note], all: true) }
                if let grace { try score.attach(note, try buildGraceGroup(score, grace), index: 0) }
                if let id { try note.setAttributeThrowing("id", id) }
                if let stave, !stave.isEmpty { assignments.append((note, stave)) }
                notes.append(note)
            case .tab(let tabStruct, let id, let stave, let drawStem):
                let note = try score.make.tabNote(tabStruct, drawStem: drawStem)
                // VexFlow 5.6.0: rhythmic tab shares one set of dots at the stem.
                if drawStem { for _ in 0..<note.writtenDots { Dot.buildAndAttach([note], all: false) } }
                if let id { try note.setAttributeThrowing("id", id) }
                if let stave, !stave.isEmpty { assignments.append((note, stave)) }
                notes.append(note)
            }
        }
        let timed = notes.filter { !$0.shouldIgnoreTicks() }
        for group in spec.tuplets {
            if group.start < 0 || group.count < 1 || group.start + group.count > timed.count {
                throw invalid("Tuplet range is outside its voice.")
            }
            let members = timed[group.start..<(group.start + group.count)].compactMap { $0 as? Note }
            if members.count != group.count { throw invalid("Tuplets require native notes.") }
            _ = try score.make.tuplet(notes: members, options: group.options)
        }
        if !deferBeam { try autoBeamVoice(score, spec, timed, initial.time) }
        return BuiltVoice(notes: notes, state: state, changes: changes, assignments: assignments, generated: generated)
    }
}

/// Beam the timed members after the measure-local and cross-measure ratios are applied. (VexFlow 5.8.0)
private func autoBeamVoice(
    _ score: EasyScore, _ spec: EasyScoreVoiceSpec, _ timed: [Tickable], _ time: TimeSignatureSpec
) throws {
    guard let autoBeam = spec.autoBeam else { return }
    let stemmable = timed.compactMap { $0 as? StemmableNote }
    if stemmable.count != timed.count { throw invalid("Automatic beams require stemmable notes.") }
    _ = try score.withDefaults(time: time) { score in try score.autoBeam(stemmable, options: autoBeam) }
}

/// Build the unvoiced members of cross-measure tuplets before a strict measure counts its ticks.
/// The result is staff-first, then measure, then voice. (VexFlow 5.8.0)
private func prepareTupletVoices(
    _ score: EasyScore, _ spec: EasyScoreCompositionSpec, _ initial: [EasyScoreResolvedStaffState]
) throws -> [[[BuiltVoice]]]? {
    guard let groups = spec.continuous?.tuplets, !groups.isEmpty else { return nil }
    final class LaneBox { var notes: [Tickable] = [] }
    var locations: [ObjectIdentifier: (lane: LaneBox, index: Int, measure: Int)] = [:]
    let prepared = try spec.staves.enumerated().map { j, staff -> [[BuiltVoice]] in
        var state = initial[j]
        var lanes: [LaneBox] = []
        return try staff.measures.enumerated().map { m, measure -> [BuiltVoice] in
            if measure.voices.isEmpty { throw invalid("Every stave measure needs at least one voice.") }
            let start = measureState(measure, state)
            let voices = try measure.voices.enumerated().map { v, voice -> BuiltVoice in
                let built = try buildVoice(score, voice, start, v == 0, deferBeam: true)
                while lanes.count <= v { lanes.append(LaneBox()) }
                let lane = lanes[v]
                for tick in built.notes where !tick.shouldIgnoreTicks() {
                    locations[ObjectIdentifier(tick)] = (lane, lane.notes.count, m)
                    lane.notes.append(tick)
                }
                return built
            }
            state = voices[0].state
            return voices
        }
    }
    for group in groups {
        if group.members.isEmpty || group.numNotes <= 0 || group.notesOccupied <= 0 {
            throw invalid("A continuous tuplet needs members and a positive integer ratio.")
        }
        let notes = try group.members.map { try score.getNote($0) }
        var previous: (lane: LaneBox, index: Int, measure: Int)?
        for note in notes {
            let at = locations[ObjectIdentifier(note)]
            if at == nil
                || (previous != nil
                    && (at!.lane !== previous!.lane || at!.index != previous!.index + 1
                        || at!.measure > previous!.measure + 1)) {
                throw invalid("Continuous tuplet members must be consecutive timed notes in one voice, in score order.")
            }
            previous = at
        }
        // The notes own the native timing group. ContinuousLayout draws its bracket one time on each visible
        // fragment.
        _ = try Tuplet(notes: notes, options: TupletOptions(numNotes: group.numNotes, notesOccupied: group.notesOccupied))
    }
    return prepared
}

/// Inline changes must describe the same staff state at the same exact onset in every voice.
private func stateChanges(_ voice: BuiltVoice) -> [(at: Fraction, state: EasyScoreResolvedStaffState)] {
    voice.changes.map { change in (timedTicks(voice.notes[0..<change.index]), change.state) }
}

/// Add signatures at explicit boundaries; no hidden row-dependent behavior is introduced.
private func addSignatures(
    _ score: EasyScore, _ stave: Stave, _ state: EasyScoreResolvedStaffState, _ previous: EasyScoreResolvedStaffState?
) throws {
    if previous == nil || previous?.clef != state.clef {
        try score.attachToStave(stave, try score.make.clef(state.clef))
    }
    if state.clef != .tab && (previous == nil || previous?.key != state.key) {
        try score.attachToStave(stave, try score.make.keySignature(state.key, cancelKeySpec: previous?.key))
    }
    if state.showTimeSignature && (!(previous?.showTimeSignature ?? false) || previous?.time != state.time) {
        try score.attachToStave(stave, try score.make.timeSignature(state.time))
    }
}

/// Rebuild the same native chord and lyric lanes for screen systems and independent publication views.
/// (VexFlow 5.6.0)
private func addLeadMarks(
    _ score: EasyScore, _ system: System, _ measure: EasyScoreMeasureSpec, _ voices: [[Tickable]]
) throws {
    if measure.chords.isEmpty && measure.verses.isEmpty { return }
    let members = Set(voices.joined().map { ObjectIdentifier($0) })
    func anchor(_ id: String) throws -> Note {
        let note = try score.getNote(id)
        if !members.contains(ObjectIdentifier(note)) {
            throw invalid("Lead mark anchor \(id) belongs to another staff or measure.")
        }
        return note
    }
    var chordLanes: [(stave: Stave, marks: [Annotation])] = []
    for chord in measure.chords {
        let note = try anchor(chord.note)
        if chord.harmony != nil && !chord.text.isEmpty { throw invalid("Choose either chord harmony or literal text.") }
        let text = try chord.harmony.map { try NotationSpelling.chordText($0) } ?? chord.text
        if text.isEmpty { throw invalid("A chord label needs text.") }
        let mark = try score.make.annotation(text: text, vJustify: .top, font: Metrics.getFontInfo("ChordSymbol"))
        addLeadChordAnnotation(mark)
        _ = try score.attach(note, mark)
        if let note = note as? StaveNote {
            let stave = note.checkStave()
            if let i = chordLanes.firstIndex(where: { $0.stave === stave }) {
                chordLanes[i].marks.append(mark)
            } else {
                chordLanes.append((stave, [mark]))
            }
        }
    }
    for lane in chordLanes {
        try system.getPhraseLayout().addLane(lane.stave, lane.marks, options: PhraseLaneOptions(side: .above))
    }

    func lyricAnchor(_ id: String) throws -> StaveNote {
        guard let note = try anchor(id) as? StaveNote else { throw invalid("A lyric needs a pitched staff note.") }
        return note
    }
    for verse in measure.verses {
        if verse.syllables.isEmpty { throw invalid("A verse needs at least one syllable.") }
        let syllables = try verse.syllables.map { mark in
            PhraseSyllable(
                note: try lyricAnchor(mark.note), text: mark.text, hyphenAfter: mark.hyphenAfter,
                extendTo: try mark.extendTo.map { try lyricAnchor($0) }, elideWith: mark.elideWith
            )
        }
        try system.getPhraseLayout().addVerse(
            syllables[0].note.checkStave(), syllables, options: PhraseVerseOptions(stanza: verse.stanza)
        )
    }
}

/// Carry the previous written state through omitted measure fields. (VexFlow 5.6.0)
private func measureState(
    _ measure: EasyScoreMeasureSpec, _ previous: EasyScoreResolvedStaffState
) -> EasyScoreResolvedStaffState {
    EasyScoreResolvedStaffState(
        clef: measure.clef ?? previous.clef, key: measure.key ?? previous.key, time: measure.time ?? previous.time,
        showTimeSignature: measure.showTimeSignature ?? previous.showTimeSignature
    )
}

/// Use the prepared timed tuplet members for a local bar or for a shared formatting window. (VexFlow 5.8.0)
private func measureVoices(
    _ score: EasyScore, _ measure: EasyScoreMeasureSpec, _ state: EasyScoreResolvedStaffState,
    _ prepared: [BuiltVoice]?
) throws -> [BuiltVoice] {
    guard let prepared else {
        return try measure.voices.enumerated().map { voiceIndex, voice in
            try buildVoice(score, voice, state, voiceIndex == 0)
        }
    }
    for (i, voice) in prepared.enumerated() {
        try autoBeamVoice(score, measure.voices[i], voice.notes.filter { !$0.shouldIgnoreTicks() }, state.time)
    }
    return prepared
}

/// Resolve owned notes only after the entire composition is constructed.
private func buildSpans(
    _ score: EasyScore, _ spec: EasyScoreCompositionSpec, _ measures: [ObjectIdentifier: Int],
    _ diagnostics: inout [EasyScoreCompositionDiagnostic]
) throws -> [VexElement] {
    try spec.spans.map { span -> VexElement in
        let ids: (from: String?, to: String?)
        switch span {
        case .tie(let from, let to, _, _, _): ids = (from, to)
        case .curve(let from, let to, _): ids = (from, to)
        case .hairpin(let from, let to, _, _): ids = (from, to)
        }
        let from = try ids.from.map { try score.getNote($0) }
        let to = try ids.to.map { try score.getNote($0) }
        for note in [from, to].compactMap({ $0 }) where measures[ObjectIdentifier(note)] == nil {
            throw invalid("Span endpoints must belong to this composition.")
        }
        if let from, let to, measures[ObjectIdentifier(from)] != measures[ObjectIdentifier(to)] {
            if spec.crossMeasureSpans != .manual {
                throw invalid("Cross-measure spans need explicit manual segmentation.")
            }
            diagnostics.append(EasyScoreCompositionDiagnostic(
                code: .manualSpan,
                message: "A cross-measure span will not split when Sheet wraps. "
                    + "Replace it with native partial segments before drawing across rows."
            ))
        }
        switch span {
        case .tie(_, _, let firstIndexes, let lastIndexes, let text):
            return try score.make.tie(from: from, to: to, firstIndexes: firstIndexes, lastIndexes: lastIndexes, text: text)
        case .curve(_, _, let options):
            return try score.make.curve(from: from, to: to, options: options)
        case .hairpin(_, _, let type, let options):
            guard let from, let to else { throw invalid("Hairpins require both endpoints.") }
            return try score.make.hairpin(from: from, to: to, type: type, options: options)
        }
    }
}

private struct StaffMeasure {
    var stave: Stave
    var voices: [Voice]
    var notes: [[Tickable]]
    var assignments: [(note: Note, stave: String)]
    var key: String
    var changes: [EasyScoreKeyChange]
    var generated: Set<ObjectIdentifier>
    var ticks: Fraction
    var state: EasyScoreResolvedStaffState
}

/// Build one staff measure before joining it to the shared native System.
private func buildStaffMeasure(
    _ score: EasyScore, _ spec: EasyScoreCompositionSpec, _ staff: EasyScoreStaveSpec, _ index: Int,
    _ previous: EasyScoreResolvedStaffState, seen: inout Set<ObjectIdentifier>, noteMeasures: inout [ObjectIdentifier: Int],
    prepared: [BuiltVoice]? = nil
) throws -> StaffMeasure {
    var assignments: [(note: Note, stave: String)] = []
    let measure = staff.measures[index]
    if measure.voices.isEmpty { throw invalid("Every stave measure needs at least one voice.") }
    let state = measureState(measure, previous)
    let span = try measure.span ?? VoiceTime(timeSignature: state.time)
    let ticks = try ticksFor(span)
    let built = try measureVoices(score, measure, state, prepared)
    let changes = stateChanges(built[0])
    func signature(_ items: [(at: Fraction, state: EasyScoreResolvedStaffState)]) -> [String] {
        items.map {
            "\($0.at.clone().simplify().description)|\($0.state.clef.rawValue)|\($0.state.key)|"
                + "\($0.state.time.rawValue)|\($0.state.showTimeSignature)"
        }
    }
    for voice in built {
        if signature(stateChanges(voice)) != signature(changes) {
            throw invalid("Inline staff changes must agree in all voices.")
        }
        let actual = timedTicks(voice.notes[...])
        if !actual.equals(ticks) {
            throw invalid("Measure \(index + 1) on \(staff.id) does not fill its declared span.")
        }
        for note in voice.notes {
            if seen.contains(ObjectIdentifier(note)) { throw invalid("A note cannot belong to two composition voices.") }
            seen.insert(ObjectIdentifier(note))
            if note is Note { noteMeasures[ObjectIdentifier(note)] = index }
        }
        assignments.append(contentsOf: voice.assignments)
    }
    let nativeVoices = try built.enumerated().map { voiceIndex, voice in
        try score.voiceThrowing(
            voice.notes,
            options: EasyScoreVoiceOptions(
                time: span, mode: .strict, softmaxFactor: measure.voices[voiceIndex].softmaxFactor
            )
        )
    }
    var currentKey = state.key
    var keys: [EasyScoreKeyChange] = []
    for change in changes where change.state.key != currentKey {
        currentKey = change.state.key
        keys.append(EasyScoreKeyChange(at: change.at, key: currentKey))
    }
    let generated = built.reduce(into: Set<ObjectIdentifier>()) { $0.formUnion($1.generated) }
    let stave: Stave
    if staff.kind == .tab {
        stave = try score.make.tabStave(options: staff.options)
    } else {
        var options = staff.options ?? StaveOptions()
        options.clef = state.clef
        stave = try score.make.stave(options: options)
    }
    if let endBarline = measure.endBarline {
        // Upstream also rejects values outside `BarlineType`; the Swift enum makes them unrepresentable.
        if endBarline == .repeatBegin { throw invalid("Invalid end barline.") }
        stave.setEndBarType(endBarline)
    }
    try addSignatures(score, stave, state, index > 0 && spec.signatures != .everyMeasure ? previous : nil)

    return StaffMeasure(
        stave: stave, voices: nativeVoices, notes: built.map { $0.notes }, assignments: assignments,
        key: state.key, changes: keys, generated: generated, ticks: ticks, state: built[0].state
    )
}

/// Check the source policies before staff-local or shared-window construction changes native inputs.
/// (VexFlow 5.8.0)
private func validateComposition(_ spec: EasyScoreCompositionSpec) throws -> [Note] {
    let count = spec.staves.first?.measures.count ?? 0
    if count == 0 || spec.staves.isEmpty { throw invalid("A composition needs staves and measures.") }
    if Set(spec.staves.map { $0.id }).count != spec.staves.count || spec.staves.contains(where: { $0.id.isEmpty }) {
        throw invalid("Staff IDs must be unique and nonempty.")
    }
    if spec.continuous?.independentMeters != true && spec.staves.contains(where: { $0.measures.count != count }) {
        throw invalid("All staves need the same number of measures.")
    }
    if spec.graceAccidentals == .ordered && spec.accidentals != .keyAware {
        throw invalid("Ordered grace accidentals require key-aware accidentals.")
    }
    var nativeInputs: [Note] = []
    for stave in spec.staves {
        for measure in stave.measures {
            for voice in measure.voices {
                for item in voice.notes {
                    if case .tickable(let tickable) = item, let note = tickable as? Note { nativeInputs.append(note) }
                }
            }
        }
    }
    let usesRhythmPolicies = spec.staves.contains { stave in
        stave.measures.contains { measure in
            measure.voices.contains { $0.autoBeam != nil || !$0.tuplets.isEmpty }
        }
    }
    if !nativeInputs.isEmpty
        && (spec.accidentals == .keyAware || !(spec.continuous?.tuplets.isEmpty ?? true) || usesRhythmPolicies) {
        throw invalid(
            "Apply rhythm and accidental policies before adopting native inputs, or use typed note descriptions."
        )
    }
    return nativeInputs
}

/// The grid data that an independently metered composition gives to `composeAligned`. (VexFlow 5.8.0)
private struct GridContext {
    var assignments: [ObjectIdentifier: (note: Note, stave: String)]
    var interior: [InteriorBar]
    var placed: Set<ObjectIdentifier>
}

/// Compose aligned measure arrays atomically. Formatting and drawing remain explicit native operations.
func easyScoreCompose(_ score: EasyScore, _ spec: EasyScoreCompositionSpec) throws -> EasyScoreComposition {
    let nativeInputs = try validateComposition(spec)
    if spec.continuous?.independentMeters != true { return try composeAligned(score, spec, nativeInputs) }
    return try score.build { score in
        var assignments: [ObjectIdentifier: (note: Note, stave: String)] = [:]
        var placed = Set<ObjectIdentifier>()
        let prepared = try prepareTupletVoices(score, spec, spec.staves.map(initialStaffState))
        let grid = try independentMeterGrid(spec) { j, bar, initial, m in
            if bar.voices.isEmpty { throw invalid("Every stave measure needs at least one voice.") }
            let built = try measureVoices(score, bar, initial, prepared?[j][m])
            let voices = built.map { $0.notes }
            for v in built { for a in v.assignments { assignments[ObjectIdentifier(a.note)] = a } }
            if spec.accidentals == .keyAware {
                var key = initial.key
                var changes: [EasyScoreKeyChange] = []
                for change in stateChanges(built[0]) where change.state.key != key {
                    key = change.state.key
                    changes.append(EasyScoreKeyChange(at: change.at, key: key))
                }
                try applyCompositionAccidentals(
                    score, voices, initial.key, changes,
                    built.reduce(into: Set<ObjectIdentifier>()) { $0.formUnion($1.generated) },
                    nil, spec.graceAccidentals == .ordered, { placed.insert(ObjectIdentifier($0)) }
                )
            }
            return (voices, built[0].state)
        }
        let result = try composeAligned(
            score, grid.spec, nativeInputs,
            grid: GridContext(assignments: assignments, interior: grid.interior, placed: placed)
        )
        result.meterPositions = grid.positions
        return result
    }
}

/// Construct one shared System for each formatting window. The original note objects stay the same.
private func composeAligned(
    _ score: EasyScore, _ spec: EasyScoreCompositionSpec, _ nativeInputs: [Note], grid: GridContext? = nil
) throws -> EasyScoreComposition {
    let count = spec.staves[0].measures.count
    let priorNative = nativeInputs.map { (stave: $0.getStave(), modifiers: $0.getModifiers().count) }
    // Avoid assigning the same note to more than one voice, even when references are supplied directly.
    var seen = Set<ObjectIdentifier>()
    do {
        return try score.build { score in
            let result = EasyScoreComposition(sheet: try score.sheet(spec.sheet), score: score)
            if spec.continuous == nil && spec.signatures != .everyMeasure {
                result.diagnostics.append(EasyScoreCompositionDiagnostic(
                    code: .signaturePolicy,
                    message: "Signatures appear at the first measure and explicit changes. "
                        + "Sheet does not repeat them at wrapped row starts."
                ))
            }
            var states = spec.staves.map(initialStaffState)
            var noteMeasures: [ObjectIdentifier: Int] = [:]
            // Staff states at the start and end of each measure, and the generated accidentals, for the
            // continuous layout. (VexFlow 5.4.0)
            var starts: [[EasyScoreResolvedStaffState]] = []
            var ends: [[EasyScoreResolvedStaffState]] = []
            var placed: Set<ObjectIdentifier>? = grid?.placed ?? (spec.continuous != nil ? [] : nil)
            let prepared = grid == nil ? try prepareTupletVoices(score, spec, states) : nil
            for index in 0..<count {
                starts.append(spec.staves.enumerated().map { j, staff in measureState(staff.measures[index], states[j]) })
                let system = result.sheet.addSystem(spec.system)
                result.systems.append(system)
                var parts: [StaffMeasure] = []
                for (staffIndex, staff) in spec.staves.enumerated() {
                    let part = try buildStaffMeasure(
                        score, spec, staff, index, states[staffIndex], seen: &seen, noteMeasures: &noteMeasures,
                        prepared: prepared?[staffIndex][index]
                    )
                    states[staffIndex] = part.state
                    system.addStave(SystemStave(
                        voices: part.voices, stave: part.stave,
                        spaceAbove: staff.spaceAbove ?? 0, spaceBelow: staff.spaceBelow ?? 0
                    ))
                    parts.append(part)
                }
                if parts.contains(where: { !$0.ticks.equals(parts[0].ticks) }) {
                    throw invalid("Staves must share the same actual measure span.")
                }
                let staves = parts.map { $0.stave }
                let voices = parts.map { $0.voices }
                var assignments = parts.flatMap { $0.assignments }
                if let grid {
                    for case let note as Note in parts.flatMap({ $0.notes.flatMap { $0 } }) {
                        if let target = grid.assignments[ObjectIdentifier(note)] {
                            assignments.removeAll { $0.note === note }
                            assignments.append(target)
                        }
                    }
                }
                for (note, id) in assignments {
                    guard let target = spec.staves.firstIndex(where: { $0.id == id }) else {
                        throw invalid("Unknown cross-staff target: \(id)")
                    }
                    _ = note.setStave(staves[target])
                }
                if spec.accidentals == .keyAware {
                    let generated = parts.reduce(into: Set<ObjectIdentifier>()) { $0.formUnion($1.generated) }
                    for (staffIndex, part) in parts.enumerated() {
                        try applyCompositionAccidentals(
                            score, voices.flatMap { $0 }.map { $0.getTickables() }, part.key, part.changes, generated, staves[staffIndex],
                            spec.graceAccidentals == .ordered,
                            placed == nil ? nil : { placed?.insert(ObjectIdentifier($0)) }
                        )
                    }
                }
                for (j, staff) in spec.staves.enumerated() {
                    try addLeadMarks(score, system, staff.measures[index], parts[j].notes)
                }
                ends.append(states)
                result.staves.append(staves)
                result.voices.append(voices)
                result.notes.append(parts.map { $0.notes })
            }
            result.spans = try buildSpans(score, spec, noteMeasures, &result.diagnostics)
            if spec.continuous != nil {
                result.sheet.setContinuousLayout(
                    try ContinuousLayout(result, spec, starts, ends, placed, grid?.interior ?? [])
                )
            }
            return result
        }
    } catch {
        // Restore caller-owned note assignments. Rhythm/accidental mutation of native inputs is rejected above.
        for (index, note) in nativeInputs.enumerated() where seen.contains(ObjectIdentifier(note)) {
            note.clearVoice()
            let prior = priorNative[index]
            // VexFlow 5.6.0: drop the modifiers that the failed composition attached (for example dots).
            if note.modifiers.count > prior.modifiers { note.modifiers.removeSubrange(prior.modifiers...) }
            if let stave = prior.stave { _ = note.setStave(stave) } else { note.clearStave() }
        }
        throw error
    }
}
