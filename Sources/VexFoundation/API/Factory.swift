// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Mohit Cheppudira
//
// Port of `src/factory.ts` (VexFlow 5.2.0).
//
// Local changes (see docs/local-deviations.md):
// - Every object is created inside the factory runtime context.
// - `formatSystems()` formats the systems before `draw()` (commit 1af03ba).
// - There is no DOM: `newFromElementId` and `initRenderer` are not ported.
//   Set a context with `setContext(_:)`.

import Foundation

// MARK: - Factory Options

/// Options for Factory initialization. `staveSpace` is upstream
/// `stave.space`; `width` and `height` are upstream `renderer.width/height`.
public struct FactoryOptions {
    public var staveSpace: Double = 10
    public var width: Double = 500
    public var height: Double = 200

    public init(staveSpace: Double = 10, width: Double = 500, height: Double = 200) {
        self.staveSpace = staveSpace
        self.width = width
        self.height = height
    }
}

/// Explicit drawing role for a native extension adopted into a Factory. (VexFlow 5.2.0)
public enum FactoryElementRole: String, Sendable {
    case note
    case modifier
    case staveModifier
    case drawable
}

public enum FactoryError: Error, LocalizedError, Equatable, Sendable {
    case missingRenderContext

    public var errorDescription: String? {
        switch self {
        case .missingRenderContext:
            return "Factory requires a RenderContext to draw."
        }
    }
}

// MARK: - Factory

/// High-level API for creating VexFlow objects.
/// Provides factory methods for notes, staves, modifiers, and other music elements.
public final class Factory {

    /// To enable logging for this class. Set `Factory.DEBUG` to `true`.
    nonisolated(unsafe) public static var DEBUG: Bool = false

    // MARK: - Properties

    private var options: FactoryOptions
    private let runtimeContext: VexRuntimeContext
    private var context: RenderContext?
    private var currentStave: Stave?
    private var staves: [Stave] = []
    private var voices: [Voice] = []
    private var renderQ: [VexElement] = []
    private var systems: [System] = []
    private var sheets: [Sheet] = []
    private var retained = false
    /// Foreground defaults (score colors). They survive `reset()`, like renderer options.
    private var scoreStyle = ElementStyle()
    /// Elements created by nested construction scopes (see `transaction(_:)`). (VexFlow 5.2.0)
    private var constructionScopes: [[VexElement]] = []
    /// Undo actions of note groups created by nested construction scopes.
    private var groupScopes: [[() -> Void]] = []

    // MARK: - Ownership (VexFlow 5.2.0)

    /// A grouped note draws only through its modifier, never through a main voice or queue.
    public static func getGroup(_ note: Note) -> Modifier? { note.factoryGroup }

    /// Identify the Factory that created an element, without changing its draw role.
    public static func getOwner(_ element: VexElement) -> Factory? { element.factoryOwner }

    /// Record ownership of a new element. Elements owned by another Factory are rejected.
    @discardableResult
    func ownThrowing<T: VexElement>(_ element: T) throws -> T {
        if let owner = element.factoryOwner {
            if owner === self { return element }
            throw VexError("BadArguments", "Element belongs to another Factory.")
        }
        element.factoryOwner = self
        for i in constructionScopes.indices { constructionScopes[i].append(element) }
        return element
    }

    /// Record ownership of an element that this Factory just constructed.
    @discardableResult
    private func own<T: VexElement>(_ element: T) -> T {
        (try? ownThrowing(element)) ?? element
    }

    /// Adopt a native extension without guessing its drawing role. Attachment and layout remain explicit.
    /// Repeating adoption cannot enqueue an element twice. Ownership survives draw/reset.
    @discardableResult
    public func adopt<T: VexElement>(_ element: T, role: FactoryElementRole) throws -> T {
        let valid: Bool
        switch role {
        case .note: valid = element is VexFoundation.Note
        case .modifier: valid = element is VexFoundation.Modifier
        case .staveModifier: valid = element is VexFoundation.StaveModifier
        case .drawable:
            valid = !(element is VexFoundation.Note) && !(element is VexFoundation.Modifier)
                && !(element is VexFoundation.Voice) && !(element is VexFoundation.Stave)
                && !(element is VexFoundation.StaveModifier) && !(element is VexFoundation.System)
        }
        if !valid { throw VexError("BadArguments", "Invalid adopted element role: \(role.rawValue)") }
        if let note = element as? VexFoundation.Note, note.factoryGroup != nil {
            throw VexError("BadArguments", "A grouped note cannot be queued independently.")
        }
        try ownThrowing(element)
        if (role == .note || role == .drawable) && !renderQ.contains(where: { $0 === element }) {
            renderQ.append(element)
        }
        return element
    }

    /// Stage synchronous construction. Failed operations preserve existing queues and registry entries.
    public func transaction<T>(_ build: () throws -> T) throws -> T {
        let snapshot = (
            staves: staves, voices: voices, renderQ: renderQ, systems: systems, sheets: sheets,
            stave: currentStave, retained: retained
        )
        constructionScopes.append([])
        groupScopes.append([])
        return try withoutActuallyEscaping(build) { build in try transactionBody(build, snapshot) }
    }

    private func transactionBody<T>(
        _ build: @escaping () throws -> T,
        _ snapshot: (staves: [VexFoundation.Stave], voices: [VexFoundation.Voice], renderQ: [VexElement],
                     systems: [VexFoundation.System], sheets: [VexFoundation.Sheet], stave: VexFoundation.Stave?,
                     retained: Bool)
    ) throws -> T {
        let run: () throws -> T = {
            do {
                let result = try build()
                self.constructionScopes.removeLast()
                self.groupScopes.removeLast()
                return result
            } catch {
                let created = self.constructionScopes.removeLast()
                let grouped = self.groupScopes.removeLast()
                self.staves = snapshot.staves
                self.voices = snapshot.voices
                self.renderQ = snapshot.renderQ
                self.systems = snapshot.systems
                self.sheets = snapshot.sheets
                self.currentStave = snapshot.stave
                self.retained = snapshot.retained
                for element in created where element.factoryOwner === self { element.factoryOwner = nil }
                for restore in grouped.reversed() { restore() }
                throw error
            }
        }
        if let registry = runtimeContext.getDefaultRegistry() {
            return try registry.transaction(run)
        }
        return try run()
    }

    /// Transfer unvoiced notes to one modifier. Validation happens before native voice assignment.
    public func groupNotes<T: VexFoundation.Modifier>(_ notes: [VexFoundation.Note], _ construct: () throws -> T) throws -> T {
        if notes.isEmpty || Set(notes.map { ObjectIdentifier($0) }).count != notes.count {
            throw VexError("BadArguments", "A note group needs distinct notes.")
        }
        for note in notes {
            if let owner = note.factoryOwner, owner !== self {
                throw VexError("BadArguments", "Group note belongs to another Factory.")
            }
            if note.factoryGroup != nil { throw VexError("BadArguments", "Note already belongs to a group.") }
            if note.voice != nil { throw VexError("BadArguments", "A voiced note cannot be moved into a group.") }
        }
        let ignored = notes.map { $0.shouldIgnoreTicks() }
        let restore = {
            for (index, note) in notes.enumerated() {
                note.factoryGroup = nil
                note.clearVoice()
                note.ignoreTicks = ignored[index]
            }
        }
        let group: T
        do {
            let constructed = try construct()
            if let ctx = context { _ = constructed.setContext(ctx) }
            group = try ownThrowing(constructed)
        } catch {
            restore()
            throw error
        }
        for i in groupScopes.indices { groupScopes[i].append(restore) }
        for note in notes {
            own(note)
            note.factoryGroup = group
        }
        renderQ.removeAll { element in notes.contains { $0 === element } }
        return group
    }

    /// The elements queued for drawing (upstream `renderQ`).
    public func getRenderQueue() -> [VexElement] { renderQ }

    /// The systems created by this Factory.
    public func getSystems() -> [VexFoundation.System] { systems }

    /// The sheets created by this Factory.
    public func getSheets() -> [VexFoundation.Sheet] { sheets }

    // MARK: - Init

    public init(
        options: FactoryOptions = FactoryOptions(),
        runtimeContext: VexRuntimeContext = VexRuntime.getCurrentContext()
    ) {
        self.options = options
        self.runtimeContext = runtimeContext
    }

    // MARK: - Reset

    public func reset() {
        sheets = []
        retained = false
        renderQ = []
        systems = []
        staves = []
        voices = []
        currentStave = nil
        systemsFormatted = false
    }

    // MARK: - Context

    public func getRuntimeContext() -> VexRuntimeContext { runtimeContext }

    public func getContext() -> RenderContext? { context }

    @discardableResult
    public func setContext(_ context: RenderContext) -> Self {
        self.context = context
        return self
    }

    // MARK: - Stave Access

    public func getStave() -> Stave? { currentStave }

    public func getVoices() -> [Voice] { voices }

    private func inRuntimeContext<T>(_ body: () -> T) -> T {
        VexRuntime.withContext(runtimeContext, body)
    }

    private func inRuntimeContext<T>(_ body: () throws -> T) rethrows -> T {
        try VexRuntime.withContext(runtimeContext, body)
    }

    // MARK: - Stave Factory Methods

    @discardableResult
    public func Stave(
        x: Double = 0, y: Double = 0,
        width: Double? = nil,
        options: StaveOptions? = nil
    ) -> Stave {
        let w = width ?? (self.options.width - self.options.staveSpace)
        var opts = options ?? StaveOptions()
        if options == nil || !(options?.spacingBetweenLinesPxWasSpecified ?? false) {
            opts.spacingBetweenLinesPx = self.options.staveSpace
        }
        let stave = inRuntimeContext {
            VexFoundation.Stave(x: x, y: y, width: w, options: opts)
        }
        staves.append(stave)
        if let ctx = context { _ = stave.setContext(ctx) }
        currentStave = stave
        return own(stave)
    }

    @discardableResult
    public func TabStave(
        x: Double = 0, y: Double = 0,
        width: Double? = nil,
        options: StaveOptions? = nil
    ) -> VexFoundation.TabStave {
        let w = width ?? (self.options.width - self.options.staveSpace)
        var opts = options ?? StaveOptions(numLines: 6)
        // Swift materializes StaveOptions eagerly, so preserve upstream TabStave
        // behavior by only applying the factory default when spacing was omitted.
        if options == nil || !(options?.spacingBetweenLinesPxWasSpecified ?? false) {
            opts.spacingBetweenLinesPx = self.options.staveSpace * 1.3
        }
        let stave = inRuntimeContext {
            VexFoundation.TabStave(x: x, y: y, width: w, options: opts)
        }
        staves.append(stave)
        if let ctx = context { _ = stave.setContext(ctx) }
        currentStave = stave
        return own(stave)
    }

    // MARK: - Note Factory Methods

    @discardableResult
    public func StaveNote(_ noteStruct: StaveNoteStruct) -> VexFoundation.StaveNote {
        let note = inRuntimeContext { VexFoundation.StaveNote(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func GlyphNote(
        glyph: String, noteStruct: NoteStruct,
        options: GlyphNoteOptions = GlyphNoteOptions()
    ) -> VexFoundation.GlyphNote {
        let note = inRuntimeContext {
            VexFoundation.GlyphNote(glyph: glyph, noteStruct: noteStruct, options: options)
        }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func RepeatNote(type: String, noteStruct: NoteStruct? = nil,
                           options: GlyphNoteOptions? = nil) -> VexFoundation.RepeatNote {
        let note = inRuntimeContext {
            VexFoundation.RepeatNote(type: type, noteStruct: noteStruct, options: options)
        }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func GhostNote(_ noteStruct: NoteStruct) -> VexFoundation.GhostNote {
        let note = inRuntimeContext { VexFoundation.GhostNote(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func GhostNote(duration: NoteValue, dots: Int = 0) -> VexFoundation.GhostNote {
        var ns = NoteStruct(duration: NoteDurationSpec(uncheckedValue: duration))
        ns.dots = dots
        return GhostNote(ns)
    }

    @discardableResult
    public func GhostNote(duration: String, dots: Int = 0) throws -> VexFoundation.GhostNote {
        var ns = try NoteStruct(duration: duration)
        ns.dots = dots
        return GhostNote(ns)
    }

    @discardableResult
    public func GhostNote(parsingDuration duration: String, dots: Int = 0) -> VexFoundation.GhostNote? {
        guard var ns = NoteStruct(parsingDuration: duration) else { return nil }
        ns.dots = dots
        return GhostNote(ns)
    }

    @discardableResult
    public func TextNote(_ noteStruct: TextNoteStruct) -> VexFoundation.TextNote {
        let note = inRuntimeContext { VexFoundation.TextNote(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func BarNote(type: BarlineType = .single) -> VexFoundation.BarNote {
        let note = inRuntimeContext { VexFoundation.BarNote(type: type) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func ClefNote(
        type: ClefName = .treble,
        size: ClefSize = .default,
        annotation: ClefAnnotation? = nil
    ) -> VexFoundation.ClefNote {
        let note = inRuntimeContext {
            VexFoundation.ClefNote(type: type, size: size, annotation: annotation)
        }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func TimeSigNote(time: TimeSignatureSpec = .default) -> VexFoundation.TimeSigNote {
        let note = inRuntimeContext { VexFoundation.TimeSigNote(timeSpec: time) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func KeySigNote(
        key: String, cancelKey: String? = nil, alterKey: [String]? = nil, clef: ClefName? = nil
    ) -> VexFoundation.KeySigNote {
        let note = inRuntimeContext {
            VexFoundation.KeySigNote(keySpec: key, cancelKeySpec: cancelKey, alterKeySpec: alterKey, clef: clef)
        }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func TabNote(_ noteStruct: TabNoteStruct, drawStem: Bool = false) -> VexFoundation.TabNote {
        let note = inRuntimeContext { VexFoundation.TabNote(noteStruct, drawStem: drawStem) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return own(note)
    }

    @discardableResult
    public func GraceNote(_ noteStruct: GraceNoteStruct) -> VexFoundation.GraceNote {
        let note = inRuntimeContext { VexFoundation.GraceNote(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        return own(note)
    }

    @discardableResult
    public func GraceNoteGroup(
        notes: [StemmableNote], slur: Bool = false
    ) -> VexFoundation.GraceNoteGroup {
        let group = inRuntimeContext {
            VexFoundation.GraceNoteGroup(graceNotes: notes, showSlur: slur)
        }
        if let ctx = context { _ = group.setContext(ctx) }
        return own(group)
    }

    // MARK: - Modifier Factory Methods

    @discardableResult
    public func Accidental(type: AccidentalType) -> VexFoundation.Accidental {
        let accid = inRuntimeContext { VexFoundation.Accidental(type) }
        if let ctx = context { _ = accid.setContext(ctx) }
        return own(accid)
    }

    /// String convenience API that throws on invalid accidental input.
    @discardableResult
    public func Accidental(parsing type: String) throws -> VexFoundation.Accidental {
        let accid = try inRuntimeContext { try VexFoundation.Accidental(parsing: type) }
        if let ctx = context { _ = accid.setContext(ctx) }
        return own(accid)
    }

    /// String convenience API that returns nil on invalid accidental input.
    @discardableResult
    public func Accidental(parsingOrNil type: String) -> VexFoundation.Accidental? {
        let accid = inRuntimeContext { VexFoundation.Accidental(parsingOrNil: type) }
        guard let accid else { return nil }
        if let ctx = context { _ = accid.setContext(ctx) }
        return own(accid)
    }

    @discardableResult
    public func Annotation(
        text: String = "p",
        hJustify: AnnotationHorizontalJustify = .center,
        vJustify: AnnotationVerticalJustify = .bottom,
        font: FontInfo? = nil
    ) -> VexFoundation.Annotation {
        let annotation = inRuntimeContext { VexFoundation.Annotation(text) }
        _ = annotation.setJustification(hJustify)
        _ = annotation.setVerticalJustification(vJustify)
        annotation.setFont(font)
        if let ctx = context { _ = annotation.setContext(ctx) }
        return own(annotation)
    }

    @discardableResult
    public func ChordSymbol(
        vJustify: ChordSymbolVerticalJustify = .top,
        hJustify: ChordSymbolHorizontalJustify = .center,
        fontFamily: String? = nil,
        fontSize: Double? = nil,
        fontWeight: String? = nil
    ) -> VexFoundation.ChordSymbol {
        let chordSymbol = inRuntimeContext { VexFoundation.ChordSymbol() }
        _ = chordSymbol.setHorizontal(hJustify)
        _ = chordSymbol.setVertical(vJustify)
        // There is a default font based on the engraving font. Set the font
        // only if it is specified, else use the default.
        if let fontFamily, let fontSize {
            let size = "\(formatJSNumber(fontSize))pt"
            if let fontWeight {
                chordSymbol.setFont(family: fontFamily, size: size, weight: fontWeight)
            } else {
                chordSymbol.setFont(family: fontFamily, size: size, weight: "")
            }
        } else if let fontSize {
            chordSymbol.setFontSize(fontSize)
        }
        if let ctx = context { _ = chordSymbol.setContext(ctx) }
        return own(chordSymbol)
    }

    @discardableResult
    public func Articulation(
        type: String = "a.",
        position: ModifierPosition? = nil,
        betweenLines: Bool? = nil
    ) -> VexFoundation.Articulation {
        let articulation = inRuntimeContext { VexFoundation.Articulation(type) }
        if let position { _ = articulation.setPosition(position) }
        if let betweenLines { _ = articulation.setBetweenLines(betweenLines) }
        if let ctx = context { _ = articulation.setContext(ctx) }
        return own(articulation)
    }

    @discardableResult
    public func Ornament(
        _ type: String,
        position: ModifierPosition? = nil,
        upperAccidental: String? = nil,
        lowerAccidental: String? = nil,
        delayed: Bool? = nil
    ) -> VexFoundation.Ornament {
        let ornament = inRuntimeContext { VexFoundation.Ornament(type) }
        if let position {
            _ = ornament.setPosition(position)
        }
        if let upperAccidental, !upperAccidental.isEmpty {
            _ = ornament.setUpperAccidental(upperAccidental)
        }
        if let lowerAccidental, !lowerAccidental.isEmpty {
            _ = ornament.setLowerAccidental(lowerAccidental)
        }
        if let delayed {
            _ = ornament.setDelayed(delayed)
        }
        if let ctx = context { _ = ornament.setContext(ctx) }
        return own(ornament)
    }

    @discardableResult
    public func TextDynamics(_ noteStruct: TextNoteStruct) -> VexFoundation.TextDynamics {
        let td = inRuntimeContext { VexFoundation.TextDynamics(noteStruct) }
        if let stave = currentStave { _ = td.setStave(stave) }
        if let ctx = context { _ = td.setContext(ctx) }
        renderQ.append(td)
        return own(td)
    }

    @discardableResult
    public func Fingering(number: String = "0", position: ModifierPosition = .left) -> FretHandFinger {
        let fingering = inRuntimeContext { FretHandFinger(number) }
        _ = fingering.setPosition(position)
        if let ctx = context { _ = fingering.setContext(ctx) }
        return own(fingering)
    }

    @discardableResult
    public func StringNumber(number: String, position: ModifierPosition = .above,
                             drawCircle: Bool = true) -> VexFoundation.StringNumber {
        let sn = inRuntimeContext { VexFoundation.StringNumber(number) }
        _ = sn.setPosition(position)
        if let ctx = context { _ = sn.setContext(ctx) }
        _ = sn.setDrawCircle(drawCircle)
        return own(sn)
    }

    // MARK: - Context Factory Methods

    public func TickContext() -> VexFoundation.TickContext {
        inRuntimeContext { VexFoundation.TickContext() }
    }

    public func ModifierContext() -> VexFoundation.ModifierContext {
        inRuntimeContext { VexFoundation.ModifierContext() }
    }

    // MARK: - Multi-Measure Rest

    @discardableResult
    public func MultiMeasureRest(
        numberOfMeasures: Int,
        options: MultiMeasureRestRenderOptions
    ) -> VexFoundation.MultiMeasureRest {
        let mmr = inRuntimeContext {
            VexFoundation.MultiMeasureRest(numberOfMeasures: numberOfMeasures, options: options)
        }
        if let ctx = context { _ = mmr.setContext(ctx) }
        renderQ.append(mmr)
        return own(mmr)
    }

    // MARK: - Voice

    @discardableResult
    public func Voice(time: VoiceTime? = nil) -> VexFoundation.Voice {
        let voice = inRuntimeContext { VexFoundation.Voice(time: time) }
        voices.append(voice)
        return own(voice)
    }

    @discardableResult
    public func Voice(timeSignature: TimeSignatureSpec) -> VexFoundation.Voice {
        (try? VoiceThrowing(timeSignature: timeSignature)) ?? Voice()
    }

    @discardableResult
    public func VoiceThrowing(timeSignature: TimeSignatureSpec) throws -> VexFoundation.Voice {
        let voice = try inRuntimeContext { try VexFoundation.Voice(validatingTimeSignature: timeSignature) }
        voices.append(voice)
        return own(voice)
    }

    // MARK: - Connector, Formatter

    @discardableResult
    public func StaveConnector(
        topStave: VexFoundation.Stave,
        bottomStave: VexFoundation.Stave,
        type: ConnectorType = .double
    ) -> VexFoundation.StaveConnector {
        let connector = inRuntimeContext {
            VexFoundation.StaveConnector(topStave: topStave, bottomStave: bottomStave)
        }
        _ = connector.setType(type)
        if let ctx = context { _ = connector.setContext(ctx) }
        renderQ.append(connector)
        return own(connector)
    }

    public func Formatter(options: FormatterOptions = FormatterOptions()) -> VexFoundation.Formatter {
        inRuntimeContext { VexFoundation.Formatter(options: options) }
    }

    // MARK: - Tuplet, Beam

    @discardableResult
    public func Tuplet(notes: [Note] = [], options: TupletOptions = TupletOptions()) -> VexFoundation.Tuplet? {
        try? TupletThrowing(notes: notes, options: options)
    }

    @discardableResult
    public func TupletThrowing(notes: [Note] = [], options: TupletOptions = TupletOptions()) throws -> VexFoundation.Tuplet {
        let tuplet = try inRuntimeContext { try VexFoundation.Tuplet(notes: notes, options: options) }
        if let ctx = context { _ = tuplet.setContext(ctx) }
        renderQ.append(tuplet)
        return own(tuplet)
    }

    @discardableResult
    public func Beam(
        notes: [StemmableNote],
        autoStem: Bool = false,
        secondaryBeamBreaks: [Int] = [],
        partialBeamDirections: [Int: PartialBeamDirection] = [:]
    ) -> VexFoundation.Beam? {
        try? BeamThrowing(
            notes: notes,
            autoStem: autoStem,
            secondaryBeamBreaks: secondaryBeamBreaks,
            partialBeamDirections: partialBeamDirections
        )
    }

    @discardableResult
    public func BeamThrowing(
        notes: [StemmableNote],
        autoStem: Bool = false,
        secondaryBeamBreaks: [Int] = [],
        partialBeamDirections: [Int: PartialBeamDirection] = [:]
    ) throws -> VexFoundation.Beam {
        let beam = try inRuntimeContext { try VexFoundation.Beam(notes, autoStem: autoStem) }
        if let ctx = context { _ = beam.setContext(ctx) }
        _ = beam.breakSecondaryAt(secondaryBeamBreaks)
        for (noteIndex, direction) in partialBeamDirections {
            _ = beam.setPartialBeamSideAt(noteIndex, side: direction)
        }
        renderQ.append(beam)
        return own(beam)
    }

    // MARK: - Curve, Tie, Line

    @discardableResult
    public func Curve(from: Note?, to: Note?, options: CurveOptions = CurveOptions()) -> VexFoundation.Curve {
        let curve = inRuntimeContext { VexFoundation.Curve(from: from, to: to, options: options) }
        if let ctx = context { _ = curve.setContext(ctx) }
        renderQ.append(curve)
        return own(curve)
    }

    @discardableResult
    public func StaveTie(notes: TieNotes, text: String? = nil,
                         direction: TieDirection? = nil) -> VexFoundation.StaveTie {
        let tie = inRuntimeContext { VexFoundation.StaveTie(notes: notes, text: text) }
        if let direction { _ = tie.setDirection(direction) }
        if let ctx = context { _ = tie.setContext(ctx) }
        renderQ.append(tie)
        return own(tie)
    }

    @discardableResult
    public func StaveLine(notes: StaveLineNotes, text: String? = nil,
                          font: FontInfo? = nil) -> VexFoundation.StaveLine {
        let line = inRuntimeContext { VexFoundation.StaveLine(notes: notes) }
        if let text { _ = line.setText(text) }
        if let font { _ = line.setFont(font) }
        if let ctx = context { _ = line.setContext(ctx) }
        renderQ.append(line)
        return own(line)
    }

    @discardableResult
    public func VibratoBracket(
        from: Note?, to: Note?, line: Double? = nil, code: Int? = nil
    ) -> VexFoundation.VibratoBracket {
        let vb = inRuntimeContext { VexFoundation.VibratoBracket(start: from, stop: to) }
        // 5.2.0: an explicit 0 is applied (`!== undefined`).
        if let line { _ = vb.setLine(line) }
        if let code { _ = vb.setVibratoCode(code) }
        if let ctx = context { _ = vb.setContext(ctx) }
        renderQ.append(vb)
        return own(vb)
    }

    @discardableResult
    public func TextBracket(
        from: Note, to: Note, text: String = "",
        superscript: String = "", position: TextBracketPosition = .top,
        line: Double? = nil, font: FontInfo? = nil
    ) -> VexFoundation.TextBracket {
        let tb = inRuntimeContext {
            VexFoundation.TextBracket(
                start: from, stop: to, text: text,
                superscript: superscript, position: position
            )
        }
        // 5.2.0: an explicit 0 is applied (`!== undefined`).
        if let line { _ = tb.setLine(line) }
        if let font { _ = tb.setFont(font) }
        if let ctx = context { _ = tb.setContext(ctx) }
        renderQ.append(tb)
        return own(tb)
    }

    // MARK: - System

    @discardableResult
    public func System(options: SystemOptions = SystemOptions()) -> VexFoundation.System {
        var opts = options
        opts.factory = self
        let resolvedRuntimeContext = opts.runtimeContext ?? runtimeContext
        opts.runtimeContext = resolvedRuntimeContext
        let system = inRuntimeContext {
            VexFoundation.System(factory: self, runtimeContext: resolvedRuntimeContext, options: opts)
        }
        if let ctx = context { _ = system.setContext(ctx) }
        systems.append(system)
        return own(system)
    }

    // MARK: - Score style and Sheet (VexFlow 5.1.0)

    /// Set score colors (`fillStyle`, `strokeStyle`). Explicit element styles take precedence.
    @discardableResult
    public func setStyle(_ style: ElementStyle) -> Self {
        scoreStyle = ElementStyle(fillStyle: style.fillStyle, strokeStyle: style.strokeStyle)
        return self
    }

    /// The score colors set with `setStyle(_:)`.
    public func getStyle() -> ElementStyle { scoreStyle }

    /// Create an optional continuous sheet from measure-sized Systems.
    @discardableResult
    public func Sheet(options: SheetOptions = SheetOptions()) throws -> VexFoundation.Sheet {
        let sheet = try VexFoundation.Sheet(factory: self, options: options)
        sheets.append(sheet)
        return sheet
    }

    // MARK: - EasyScore

    public func EasyScore(options: EasyScoreOptions = EasyScoreOptions()) -> VexFoundation.EasyScore {
        // Upstream copies the options (`{ ...options, factory: this }`); Swift options are a value type.
        var opts = options
        opts.factory = self
        let resolvedRuntimeContext = opts.runtimeContext ?? runtimeContext
        let builder = opts.builder ?? Builder(factory: self)
        opts.runtimeContext = resolvedRuntimeContext
        opts.builder = builder
        return inRuntimeContext {
            VexFoundation.EasyScore(
                factory: self,
                runtimeContext: resolvedRuntimeContext,
                builder: builder,
                options: opts
            )
        }
    }

    // MARK: - Pedal Marking

    @discardableResult
    public func PedalMarking(
        notes: [VexFoundation.StaveNote] = [],
        type: PedalMarkingType = .mixed
    ) -> VexFoundation.PedalMarking {
        let pedal = inRuntimeContext { VexFoundation.PedalMarking(notes: notes) }
        _ = pedal.setType(type)
        if let ctx = context { _ = pedal.setContext(ctx) }
        renderQ.append(pedal)
        return own(pedal)
    }

    // MARK: - NoteSubGroup

    @discardableResult
    public func NoteSubGroup(notes: [Note] = []) -> VexFoundation.NoteSubGroup {
        let group = inRuntimeContext { VexFoundation.NoteSubGroup(subNotes: notes) }
        if let ctx = context { _ = group.setContext(ctx) }
        return own(group)
    }

    // MARK: - Native constructors with explicit drawing roles (VexFlow 5.2.0)

    private func adoptNew<T: VexElement>(_ element: T, role: FactoryElementRole) -> T {
        if let ctx = context { _ = element.setContext(ctx) }
        // A new element has no owner and a valid role, so adoption cannot fail.
        return (try? adopt(element, role: role)) ?? element
    }

    /// Construct a native Bend with an explicit drawing role.
    @discardableResult
    public func Bend(_ phrase: [BendPhrase]) -> VexFoundation.Bend {
        adoptNew(inRuntimeContext { VexFoundation.Bend(phrase) }, role: .modifier)
    }

    /// Construct a native Clef with an explicit drawing role.
    @discardableResult
    public func Clef(
        _ type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil
    ) -> VexFoundation.Clef {
        adoptNew(inRuntimeContext { VexFoundation.Clef(type: type, size: size, annotation: annotation) }, role: .staveModifier)
    }

    /// Construct a native KeySignature with an explicit drawing role.
    @discardableResult
    public func KeySignature(
        _ keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil
    ) -> VexFoundation.KeySignature {
        adoptNew(inRuntimeContext {
            VexFoundation.KeySignature(keySpec: keySpec, cancelKeySpec: cancelKeySpec, alterKeySpec: alterKeySpec)
        }, role: .staveModifier)
    }

    /// Construct a native TimeSignature with an explicit drawing role.
    @discardableResult
    public func TimeSignature(
        _ timeSpec: TimeSignatureSpec = .default, customPadding: Double = 15
    ) -> VexFoundation.TimeSignature {
        adoptNew(inRuntimeContext {
            VexFoundation.TimeSignature(timeSpec: timeSpec, customPadding: customPadding)
        }, role: .staveModifier)
    }

    /// Construct a native Barline with an explicit drawing role.
    @discardableResult
    public func Barline(_ type: BarlineType) -> VexFoundation.Barline {
        adoptNew(inRuntimeContext { VexFoundation.Barline(type) }, role: .staveModifier)
    }

    /// Construct a native Repetition with an explicit drawing role.
    @discardableResult
    public func Repetition(_ type: RepetitionType, x: Double, yShift: Double) -> VexFoundation.Repetition {
        adoptNew(inRuntimeContext { VexFoundation.Repetition(type: type, x: x, yShift: yShift) }, role: .staveModifier)
    }

    /// Construct a native Volta with an explicit drawing role.
    @discardableResult
    public func Volta(_ type: VoltaType, number: String, x: Double, yShift: Double) -> VexFoundation.Volta {
        adoptNew(inRuntimeContext {
            VexFoundation.Volta(type: type, number: number, x: x, yShift: yShift)
        }, role: .staveModifier)
    }

    /// Construct a native StaveSection with an explicit drawing role.
    @discardableResult
    public func StaveSection(
        _ section: String, x: Double = 0, shiftY: Double = 0, drawRect: Bool = true
    ) -> VexFoundation.StaveSection {
        adoptNew(inRuntimeContext {
            VexFoundation.StaveSection(section: section, x: x, shiftY: shiftY, drawRect: drawRect)
        }, role: .staveModifier)
    }

    /// Construct a native StaveTempo with an explicit drawing role.
    @discardableResult
    public func StaveTempo(_ tempo: StaveTempoOptions, x: Double, shiftY: Double) -> VexFoundation.StaveTempo {
        adoptNew(inRuntimeContext {
            VexFoundation.StaveTempo(tempo: tempo, x: x, shiftY: shiftY)
        }, role: .staveModifier)
    }

    /// Construct a native StaveText with an explicit drawing role.
    @discardableResult
    public func StaveText(
        _ text: String, position: StaveModifierPosition, shiftX: Double = 0, shiftY: Double = 0,
        justification: StaveTextJustification = .center
    ) -> VexFoundation.StaveText {
        adoptNew(inRuntimeContext {
            VexFoundation.StaveText(
                text: text, position: position, shiftX: shiftX, shiftY: shiftY, justification: justification
            )
        }, role: .staveModifier)
    }

    /// Construct a native TabTie with an explicit drawing role.
    @discardableResult
    public func TabTie(_ notes: TieNotes, text: String? = nil) -> VexFoundation.TabTie {
        adoptNew(inRuntimeContext { VexFoundation.TabTie(notes: notes, text: text) }, role: .drawable)
    }

    /// Construct a native TabSlide with an explicit drawing role.
    @discardableResult
    public func TabSlide(_ notes: TieNotes, direction: TieDirection? = nil) -> VexFoundation.TabSlide {
        adoptNew(inRuntimeContext { VexFoundation.TabSlide(notes: notes, direction: direction) }, role: .drawable)
    }

    /// Grace tab children draw through a GraceNoteGroup, never as standalone tickables.
    @discardableResult
    public func GraceTabNote(_ noteStruct: TabNoteStruct) -> VexFoundation.GraceTabNote {
        let note = inRuntimeContext { VexFoundation.GraceTabNote(noteStruct) }
        if let ctx = context { _ = note.setContext(ctx) }
        return own(note)
    }

    /// Construct a native Dot for attachment.
    @discardableResult
    public func Dot() -> VexFoundation.Dot {
        adoptNew(inRuntimeContext { VexFoundation.Dot() }, role: .modifier)
    }

    /// Construct a native Parenthesis for attachment.
    @discardableResult
    public func Parenthesis(_ position: ModifierPosition = .left) -> VexFoundation.Parenthesis {
        adoptNew(inRuntimeContext { VexFoundation.Parenthesis(position: position) }, role: .modifier)
    }

    /// Construct a native Stroke for attachment.
    @discardableResult
    public func Stroke(_ type: StrokeType, allVoices: Bool = true) -> VexFoundation.Stroke {
        adoptNew(inRuntimeContext { VexFoundation.Stroke(type: type, allVoices: allVoices) }, role: .modifier)
    }

    /// Construct a native Tremolo for attachment.
    @discardableResult
    public func Tremolo(_ num: Int) -> VexFoundation.Tremolo {
        adoptNew(inRuntimeContext { VexFoundation.Tremolo(num) }, role: .modifier)
    }

    /// Construct a native Vibrato for attachment.
    @discardableResult
    public func Vibrato() -> VexFoundation.Vibrato {
        adoptNew(inRuntimeContext { VexFoundation.Vibrato() }, role: .modifier)
    }

    /// Timed crescendo note; span hairpins have a separate constructor.
    @discardableResult
    public func Crescendo(_ noteStruct: NoteStruct) -> VexFoundation.Crescendo {
        let note = inRuntimeContext { VexFoundation.Crescendo(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        return adoptNew(note, role: .note)
    }

    /// Stave-bound hairpin. The native renderer requires both endpoints.
    @discardableResult
    public func StaveHairpin(
        from: VexFoundation.Note, to: VexFoundation.Note, type: HairpinType,
        options: HairpinRenderOptions? = nil
    ) -> VexFoundation.StaveHairpin {
        let hairpin = inRuntimeContext { VexFoundation.StaveHairpin(firstNote: from, lastNote: to, type: type) }
        if let options { _ = hairpin.setRenderOptions(options) }
        return adoptNew(hairpin, role: .drawable)
    }

    // MARK: - Format & Draw

    private var systemsFormatted = false

    /// Format all systems without drawing.
    /// Call this before `draw()` when you need to inspect or modify
    /// formatted elements (e.g. applying dimmed styles) prior to rendering.
    public func formatSystems() {
        guard let ctx = context else { return }
        for system in systems {
            system.setContext(ctx).format()
        }
        systemsFormatted = true
    }

    /// Render the score.
    ///
    /// With `retain: true`, the score is kept after drawing, so it can be drawn again
    /// (for example after `Sheet.setWidth(_:)` or `setStyle(_:)`). (VexFlow 5.1.0)
    public func draw(retain: Bool = false) throws {
        guard let ctx = context else {
            throw FactoryError.missingRenderContext
        }

        for sheet in sheets {
            try sheet.format()
        }
        let managed = Set(sheets.flatMap { $0.getSystems() }.map { ObjectIdentifier($0) })
        // Local: skip the format pass when `formatSystems()` already ran.
        if !systemsFormatted {
            for system in systems where !managed.contains(ObjectIdentifier(system)) {
                system.setContext(ctx).format()
            }
        }
        let defaults = ctx.getDefaultStyle()
        ctx.save()
        ctx.setDefaultStyle(scoreStyle)
        if let fill = scoreStyle.fillStyle { ctx.setFillStyle(fill) }
        if let stroke = scoreStyle.strokeStyle { ctx.setStrokeStyle(stroke) }
        // Clear draw flags so retained scores redraw beams and other queued elements.
        if retained {
            renderQ.forEach { $0.setRendered(false) }
        }
        do {
            defer {
                ctx.setDefaultStyle(defaults)
                ctx.restore()
            }
            for stave in staves {
                try stave.setContext(ctx).drawWithStyle()
            }
            for voice in voices {
                try voice.setContext(ctx).drawWithStyle()
            }
            for element in renderQ {
                if !element.isRendered() {
                    try element.setContext(ctx).drawWithStyle()
                }
            }
            for system in systems {
                try system.setContext(ctx).drawWithStyle()
            }
        }
        retained = retain
        if retain {
            systemsFormatted = false
        } else {
            reset()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Factory", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C5/q, D5/8, E5, F5/h")
        _ = score.beam(Array(notes[1..<3]))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble).addKeySignature("D").addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
