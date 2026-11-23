// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/easyscore/elements.ts` (VexFlow 5.2.0).
// Typed notation constructors. Factory owns drawing; EasyScore owns references and construction boundaries.
//
// Swift: the helpers hold the score directly (upstream uses a host bridge to avoid a module cycle).
// Each helper validates its input, then constructs the native object inside the score transaction.

import Foundation

/// Typed constructors of `EasyScore.make`. Each returns the native object.
/// The helpers keep their score alive (as upstream closures do), so `create().make.clef(...)` is safe.
public final class EasyScoreElements {
    let score: EasyScore

    init(score: EasyScore) {
        self.score = score
    }

    private var factory: Factory { score.factory }

    private func manage<T: VexElement>(_ construct: () throws -> T) throws -> T {
        try score.manage(construct)
    }

    // MARK: - Staves and staff modifiers

    /// Construct a native Stave; attach staff modifiers with `attachToStave`.
    public func stave(x: Double = 0, y: Double = 0, width: Double? = nil, options: StaveOptions? = nil) throws -> Stave {
        try manage { factory.Stave(x: x, y: y, width: width, options: options) }
    }

    /// Construct a native TabStave; attach staff modifiers with `attachToStave`.
    public func tabStave(x: Double = 0, y: Double = 0, width: Double? = nil, options: StaveOptions? = nil) throws -> TabStave {
        try manage { factory.TabStave(x: x, y: y, width: width, options: options) }
    }

    /// Construct a native GlyphNote.
    public func glyphNote(_ glyph: String, _ noteStruct: NoteStruct, options: GlyphNoteOptions = GlyphNoteOptions()) throws -> GlyphNote {
        try manage { factory.GlyphNote(glyph: glyph, noteStruct: noteStruct, options: options) }
    }

    /// Construct a native RepeatNote.
    public func repeatNote(_ type: String, _ noteStruct: NoteStruct? = nil, options: GlyphNoteOptions? = nil) throws -> RepeatNote {
        try manage { factory.RepeatNote(type: type, noteStruct: noteStruct, options: options) }
    }

    /// Construct a native BarNote.
    public func barNote(type: BarlineType = .single) throws -> BarNote {
        try manage { factory.BarNote(type: type) }
    }

    /// Construct a native ClefNote.
    public func clefNote(type: ClefName = .treble, size: ClefSize = .default, annotation: ClefAnnotation? = nil) throws -> ClefNote {
        try manage { factory.ClefNote(type: type, size: size, annotation: annotation) }
    }

    /// Construct a native KeySigNote.
    public func keySigNote(key: String, cancelKey: String? = nil, alterKey: [String]? = nil, clef: ClefName? = nil) throws -> KeySigNote {
        try manage { factory.KeySigNote(key: key, cancelKey: cancelKey, alterKey: alterKey, clef: clef) }
    }

    /// Construct a native TimeSigNote.
    public func timeSigNote(time: TimeSignatureSpec = .default) throws -> TimeSigNote {
        try manage { factory.TimeSigNote(time: time) }
    }

    /// Construct a native Clef; attach it with `attachToStave`.
    public func clef(_ type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) throws -> Clef {
        try manage { factory.Clef(type, size: size, annotation: annotation) }
    }

    /// Construct a native KeySignature; attach it with `attachToStave`.
    public func keySignature(_ keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil) throws -> KeySignature {
        try manage { factory.KeySignature(keySpec, cancelKeySpec: cancelKeySpec, alterKeySpec: alterKeySpec) }
    }

    /// Construct a native TimeSignature; attach it with `attachToStave`.
    public func timeSignature(_ timeSpec: TimeSignatureSpec = .default, customPadding: Double = 15) throws -> TimeSignature {
        try manage { factory.TimeSignature(timeSpec, customPadding: customPadding) }
    }

    /// Construct a native Barline; attach it with `attachToStave`.
    public func barline(_ type: BarlineType) throws -> Barline {
        try manage { factory.Barline(type) }
    }

    /// Construct a native Repetition; attach it with `attachToStave`.
    public func repetition(_ type: RepetitionType, x: Double, yShift: Double) throws -> Repetition {
        try manage { factory.Repetition(type, x: x, yShift: yShift) }
    }

    /// Construct a native Volta; attach it with `attachToStave`.
    public func volta(_ type: VoltaType, number: String, x: Double, yShift: Double) throws -> Volta {
        try manage { factory.Volta(type, number: number, x: x, yShift: yShift) }
    }

    /// Construct a native StaveSection; attach it with `attachToStave`.
    public func section(_ section: String, x: Double = 0, shiftY: Double = 0, drawRect: Bool = true) throws -> StaveSection {
        try manage { factory.StaveSection(section, x: x, shiftY: shiftY, drawRect: drawRect) }
    }

    /// Construct a native StaveTempo; attach it with `attachToStave`.
    public func tempo(_ tempo: StaveTempoOptions, x: Double, shiftY: Double) throws -> StaveTempo {
        try manage { factory.StaveTempo(tempo, x: x, shiftY: shiftY) }
    }

    /// Construct a native StaveText; attach it with `attachToStave`.
    public func staveText(
        _ text: String, position: StaveModifierPosition, shiftX: Double = 0, shiftY: Double = 0,
        justification: StaveTextJustification = .center
    ) throws -> StaveText {
        try manage {
            factory.StaveText(text, position: position, shiftX: shiftX, shiftY: shiftY, justification: justification)
        }
    }

    // MARK: - Tablature

    /// Preserve native fret text and arbitrary string counts; reject invalid positions early.
    private func tabPositions(_ options: TabNoteStruct) throws {
        if options.positions.isEmpty { throw VexError("BadArguments", "Tab notes need positions.") }
        for position in options.positions where position.str < 1 || position.fret.isEmpty
            || (Double(position.fret).map { !$0.isFinite || $0 < 0 } ?? false) {
            throw VexError("BadArguments", "Invalid tablature position.")
        }
    }

    /// Construct tablature with all native note fields.
    public func tabNote(_ options: TabNoteStruct, drawStem: Bool = false) throws -> TabNote {
        try tabPositions(options)
        return try manage { factory.TabNote(options, drawStem: drawStem) }
    }

    /// Grace tablature shares the same group ownership as pitched grace notes.
    public func graceTabNote(_ options: TabNoteStruct) throws -> GraceTabNote {
        try tabPositions(options)
        return try manage { factory.GraceTabNote(options) }
    }

    /// Preserve the complete native bend phrase, including custom widths.
    public func bend(_ phrase: [BendPhrase]) throws -> Bend {
        if phrase.isEmpty || phrase.contains(where: { $0.type != 0 && $0.type != 1 }) {
            throw VexError("BadArguments", "A bend needs valid phrase directions.")
        }
        return try manage { factory.Bend(phrase) }
    }

    /// Validate tab endpoint types and head indexes before native span construction.
    private func tabEndpoints(_ notes: TieNotes) throws {
        try endpoints(notes.firstNote, notes.lastNote, partial: true)
        let first = notes.firstIndexes, last = notes.lastIndexes
        if first.isEmpty || first.count != last.count {
            throw VexError("BadArguments", "Tab span index lists must match.")
        }
        for (note, indices) in [(notes.firstNote, first), (notes.lastNote, last)] {
            guard let note else { continue }
            guard note is TabNote else { throw VexError("BadArguments", "Tab spans need tab notes.") }
            for index in indices { try score.checkIndex(note, index) }
        }
    }

    /// Tab ties support native hammer-on/pull-off text and explicit partial endpoints.
    public func tabTie(_ notes: TieNotes, text: String? = nil) throws -> TabTie {
        try tabEndpoints(notes)
        return try manage { factory.TabTie(notes, text: text) }
    }

    /// A partial slide needs an explicit direction; there are not two frets to compare.
    public func tabSlide(_ notes: TieNotes, direction: TieDirection? = nil) throws -> TabSlide {
        try tabEndpoints(notes)
        if direction == nil && (notes.firstNote == nil || notes.lastNote == nil) {
            throw VexError("BadArguments", "Partial tab slides need direction 1 or -1.")
        }
        return try manage { factory.TabSlide(notes, direction: direction) }
    }

    /// Connect owned staves without introducing another layout owner.
    public func connector(topStave: Stave, bottomStave: Stave, type: ConnectorType = .double) throws -> StaveConnector {
        try score.requireOwned(topStave)
        try score.requireOwned(bottomStave)
        return try manage { factory.StaveConnector(topStave: topStave, bottomStave: bottomStave, type: type) }
    }

    /// Multi-measure rests are standalone drawables; set their stave explicitly.
    public func multiMeasureRest(_ options: MultiMeasureRestRenderOptions) throws -> MultiMeasureRest {
        if options.numberOfMeasures < 1 {
            throw VexError("BadArguments", "A multi-measure rest needs a positive measure count.")
        }
        return try manage { factory.MultiMeasureRest(numberOfMeasures: options.numberOfMeasures, options: options) }
    }

    // MARK: - Notes and modifiers

    /// Apply the score clef and stem defaults; explicit native fields win.
    private func withNoteDefaults(
        clef: inout ClefName?, autoStem: inout Bool?, stemDirection: inout StemDirection?
    ) {
        let defaults = score.noteDefaults()
        if clef == nil { clef = defaults.clef }
        if autoStem == nil { autoStem = stemDirection != nil ? false : defaults.autoStem }
        if stemDirection == nil { stemDirection = defaults.stemDirection }
    }

    /// Typed notes inherit score clef/stem defaults; explicit native fields win.
    public func note(_ options: StaveNoteStruct) throws -> StaveNote {
        var options = options
        withNoteDefaults(clef: &options.clef, autoStem: &options.autoStem, stemDirection: &options.stemDirection)
        return try manage { factory.StaveNote(options) }
    }

    /// Construct a native Annotation; its options and setters remain available.
    public func annotation(
        text: String = "p", hJustify: AnnotationHorizontalJustify = .center,
        vJustify: AnnotationVerticalJustify = .bottom, font: FontInfo? = nil
    ) throws -> Annotation {
        try manage { factory.Annotation(text: text, hJustify: hJustify, vJustify: vJustify, font: font) }
    }

    /// Construct a native GhostNote; its options and setters remain available.
    public func ghostNote(_ noteStruct: NoteStruct) throws -> GhostNote {
        try manage { factory.GhostNote(noteStruct) }
    }

    /// Construct a native GhostNote from a duration string such as `"q"`.
    public func ghostNote(_ duration: String) throws -> GhostNote {
        let noteStruct = try NoteStruct(duration: duration)
        return try manage { factory.GhostNote(noteStruct) }
    }

    /// Construct a native GraceNote; explicit stems win over score defaults.
    public func graceNote(_ options: GraceNoteStruct) throws -> GraceNote {
        var options = options
        withNoteDefaults(clef: &options.clef, autoStem: &options.autoStem, stemDirection: &options.stemDirection)
        return try manage { factory.GraceNote(options) }
    }

    /// Construct a native Accidental from its code (for example `"#"` or `"++"`).
    public func accidental(type: String) throws -> Accidental {
        try manage { try factory.Accidental(parsing: type) }
    }

    /// Construct a native Articulation from an EasyScore alias, native code, or SMuFL glyph name.
    public func articulation(
        type: String = "staccato", position: ModifierPosition? = nil, betweenLines: Bool? = nil
    ) throws -> Articulation {
        let marks = try Articulation.parseEasyScore(type)
        guard marks.count == 1, let mark = marks.first else {
            throw VexError("BadArguments", "Create one articulation per helper call.")
        }
        return try manage {
            factory.Articulation(type: mark.type, position: position ?? mark.position, betweenLines: betweenLines)
        }
    }

    /// Construct a native Ornament; its options and setters remain available.
    public func ornament(
        _ type: String, position: ModifierPosition? = nil, upperAccidental: String? = nil,
        lowerAccidental: String? = nil, delayed: Bool? = nil
    ) throws -> Ornament {
        try manage {
            factory.Ornament(
                type, position: position, upperAccidental: upperAccidental,
                lowerAccidental: lowerAccidental, delayed: delayed
            )
        }
    }

    /// Construct a native Dot.
    public func dot() throws -> Dot { try manage { factory.Dot() } }

    /// Construct a native Parenthesis.
    public func parenthesis(_ position: ModifierPosition = .left) throws -> Parenthesis {
        try manage { factory.Parenthesis(position) }
    }

    /// Construct a native Stroke.
    public func stroke(_ type: StrokeType, allVoices: Bool = true) throws -> Stroke {
        try manage { factory.Stroke(type, allVoices: allVoices) }
    }

    /// Construct a native Tremolo.
    public func tremolo(_ num: Int) throws -> Tremolo { try manage { factory.Tremolo(num) } }

    /// Construct a native Vibrato.
    public func vibrato() throws -> Vibrato { try manage { factory.Vibrato() } }

    /// Construct a native ChordSymbol.
    public func chordSymbol(
        vJustify: ChordSymbolVerticalJustify = .top, hJustify: ChordSymbolHorizontalJustify = .center,
        fontFamily: String? = nil, fontSize: Double? = nil, fontWeight: String? = nil
    ) throws -> ChordSymbol {
        try manage {
            factory.ChordSymbol(
                vJustify: vJustify, hJustify: hJustify, fontFamily: fontFamily, fontSize: fontSize,
                fontWeight: fontWeight
            )
        }
    }

    /// Construct a native TextNote.
    public func textNote(_ noteStruct: TextNoteStruct) throws -> TextNote {
        try manage { factory.TextNote(noteStruct) }
    }

    /// Construct a native fingering (FretHandFinger).
    public func fingering(number: String = "0", position: ModifierPosition = .left) throws -> FretHandFinger {
        try manage { factory.Fingering(number: number, position: position) }
    }

    /// Construct a native StringNumber.
    public func stringNumber(number: String, position: ModifierPosition = .above, drawCircle: Bool = true) throws -> StringNumber {
        try manage { factory.StringNumber(number: number, position: position, drawCircle: drawCircle) }
    }

    /// Grace children are owned by one modifier and are removed from the standalone draw queue.
    public func graceNoteGroup(notes: [StemmableNote], slur: Bool = false) throws -> GraceNoteGroup {
        for note in notes { try score.requireOwned(note) }
        return try manage {
            try factory.groupNotes(notes) { factory.GraceNoteGroup(notes: notes, slur: slur) }
        }
    }

    /// Group inline notation or other subnotes before inserting the parent into a voice.
    public func noteSubGroup(notes: [Note]) throws -> NoteSubGroup {
        for note in notes { try score.requireOwned(note) }
        return try manage {
            try factory.groupNotes(notes) { factory.NoteSubGroup(notes: notes) }
        }
    }

    // MARK: - Relationships

    /// Ties validate ownership and chord-head indexes before construction.
    public func tie(
        from: Note? = nil, to: Note? = nil, firstIndexes: [Int] = [0], lastIndexes: [Int] = [0],
        text: String? = nil, direction: TieDirection? = nil
    ) throws -> StaveTie {
        try endpoints(from, to, partial: true)
        if firstIndexes.isEmpty || firstIndexes.count != lastIndexes.count {
            throw VexError("BadArguments", "Tie index lists must be nonempty and have the same length.")
        }
        for (note, indices) in [(from, firstIndexes), (to, lastIndexes)] {
            guard let note else { continue }
            try score.requireOwned(note)
            for index in indices { try score.checkIndex(note, index) }
        }
        let notes = TieNotes(firstNote: from, lastNote: to, firstIndexes: firstIndexes, lastIndexes: lastIndexes)
        return try manage { factory.StaveTie(notes: notes, text: text, direction: direction) }
    }

    /// Validate complete or explicitly partial spans before native constructors run.
    private func endpoints(_ from: Note?, _ to: Note?, partial: Bool = false) throws {
        if (from == nil && to == nil) || (!partial && (from == nil || to == nil)) {
            throw VexError("BadArguments", "Missing span endpoint.")
        }
        for note in [from, to].compactMap({ $0 }) { try score.requireOwned(note) }
    }

    /// Return a beam handle while preserving EasyScore's automatic/explicit stem policy.
    public func beam(
        notes: [StemmableNote], autoStem: Bool? = nil, secondaryBeamBreaks: [Int] = [],
        partialBeamDirections: [Int: PartialBeamDirection] = [:],
        feathered: FeatheredBeamDirection? = nil
    ) throws -> Beam {
        if notes.count < 2 || Set(notes.map { ObjectIdentifier($0) }).count != notes.count {
            throw VexError("BadArguments", "A beam needs at least two distinct notes.")
        }
        for note in notes {
            try score.requireOwned(note)
            if note.hasBeam() { throw VexError("BadArguments", "Note already belongs to a beam.") }
            if let quarter = Tables.durationToTicks("4"), note.getIntrinsicTicks() >= Double(quarter) {
                throw VexError("BadArguments", "Beamed notes must be shorter than a quarter note.")
            }
        }
        for index in secondaryBeamBreaks { try noteIndex(notes.count, index) }
        for index in partialBeamDirections.keys { try noteIndex(notes.count, index) }
        let autoStem = autoStem ?? score.resolveBeamStems(notes)
        return try manage {
            try factory.BeamThrowing(
                notes: notes, autoStem: autoStem, secondaryBeamBreaks: secondaryBeamBreaks,
                partialBeamDirections: partialBeamDirections, feathered: feathered
            )
        }
    }

    /// Reject out-of-range note indices before native mutation.
    private func noteIndex(_ length: Int, _ index: Int) throws {
        if index < 0 || index >= length { throw VexError("BadArguments", "Invalid beam note index.") }
    }

    /// Tuplets change rational timing before voice insertion. Nested tuplets retain native behavior.
    public func tuplet(notes: [Note], options: TupletOptions = TupletOptions()) throws -> Tuplet {
        if notes.isEmpty || Set(notes.map { ObjectIdentifier($0) }).count != notes.count {
            throw VexError("BadArguments", "A tuplet needs distinct notes.")
        }
        for note in notes {
            try score.requireOwned(note)
            if note.voice != nil {
                throw VexError("BadArguments", "Create tuplets before inserting notes into a voice.")
            }
        }
        for ratio in [options.numNotes ?? notes.count, options.notesOccupied ?? 2] where ratio <= 0 {
            throw VexError("BadArguments", "Tuplet ratios must be positive integers.")
        }
        return try manage { try factory.TupletThrowing(notes: notes, options: options) }
    }

    /// Native curves support explicit partial spans at stave boundaries.
    public func curve(from: Note? = nil, to: Note? = nil, options: CurveOptions = CurveOptions()) throws -> Curve {
        try endpoints(from, to, partial: true)
        return try manage { factory.Curve(from: from, to: to, options: options) }
    }

    /// Hairpins require two endpoints; native render offsets remain editable.
    public func hairpin(
        from: Note?, to: Note?, type: HairpinType, options: HairpinRenderOptions? = nil
    ) throws -> StaveHairpin {
        try endpoints(from, to)
        guard let from, let to else { throw VexError("BadArguments", "Missing span endpoint.") }
        return try manage { factory.StaveHairpin(from: from, to: to, type: type, options: options) }
    }

    /// Lines require two staff-note endpoints and matched chord-head indexes.
    public func line(
        from: Note?, to: Note?, firstIndexes: [Int], lastIndexes: [Int], text: String? = nil, font: FontInfo? = nil
    ) throws -> StaveLine {
        try endpoints(from, to)
        guard let first = from as? StaveNote, let last = to as? StaveNote else {
            throw VexError("BadArguments", "Lines require staff notes.")
        }
        if firstIndexes.isEmpty || firstIndexes.count != lastIndexes.count {
            throw VexError("BadArguments", "Line index lists must be nonempty and matched.")
        }
        for index in firstIndexes { try score.checkIndex(first, index) }
        for index in lastIndexes { try score.checkIndex(last, index) }
        let notes = StaveLineNotes(firstNote: first, firstIndexes: firstIndexes, lastNote: last, lastIndexes: lastIndexes)
        return try manage { factory.StaveLine(notes: notes, text: text, font: font) }
    }

    /// Text brackets have two complete endpoints; use explicit segments at row breaks.
    public func textBracket(
        from: Note?, to: Note?, text: String = "", superscript: String = "",
        position: TextBracketPosition = .top, line: Double? = nil, font: FontInfo? = nil
    ) throws -> TextBracket {
        try endpoints(from, to)
        guard let from, let to else { throw VexError("BadArguments", "Missing span endpoint.") }
        return try manage {
            factory.TextBracket(
                from: from, to: to, text: text, superscript: superscript, position: position, line: line, font: font
            )
        }
    }

    /// Vibrato brackets accept native partial endpoints.
    public func vibratoBracket(from: Note?, to: Note?, line: Double? = nil, code: Int? = nil) throws -> VibratoBracket {
        try endpoints(from, to, partial: true)
        return try manage { factory.VibratoBracket(from: from, to: to, line: line, code: code) }
    }

    /// Pedal points are explicit ordered staff-note events, including repeated depress/release points.
    public func pedalMarking(notes: [StaveNote], type: PedalMarkingType = .mixed) throws -> PedalMarking {
        if notes.isEmpty { throw VexError("BadArguments", "Pedal markings need notes.") }
        for note in notes { try score.requireOwned(note) }
        return try manage { factory.PedalMarking(notes: notes, type: type) }
    }

    /// Timed dynamics retain all native text-note fields.
    public func textDynamics(_ noteStruct: TextNoteStruct) throws -> TextDynamics {
        let text = noteStruct.text ?? "p"
        if !text.lowercased().allSatisfy({ "pmfsrz".contains($0) }) {
            throw VexError("BadArguments", "Unknown dynamics glyph.")
        }
        return try manage { factory.TextDynamics(noteStruct) }
    }

    /// Timed crescendo notes expose their native direction and height setters.
    public func crescendo(_ noteStruct: NoteStruct) throws -> Crescendo {
        try manage { factory.Crescendo(noteStruct) }
    }
}
