// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Factory Options

/// Options for Factory initialization.
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

    // MARK: - Properties

    private var options: FactoryOptions
    private let runtimeContext: VexRuntimeContext
    private var context: RenderContext?
    private var currentStave: Stave?
    private var staves: [Stave] = []
    private var voices: [Voice] = []
    private var renderQ: [VexElement] = []
    private var systems: [System] = []

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
        renderQ = []
        systems = []
        staves = []
        voices = []
        currentStave = nil
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
        if options?.spacingBetweenLinesPx == nil {
            opts.spacingBetweenLinesPx = self.options.staveSpace
        }
        let stave = inRuntimeContext {
            VexFoundation.Stave(x: x, y: y, width: w, options: opts)
        }
        staves.append(stave)
        if let ctx = context { _ = stave.setContext(ctx) }
        currentStave = stave
        return stave
    }

    @discardableResult
    public func TabStave(
        x: Double = 0, y: Double = 0,
        width: Double? = nil,
        options: StaveOptions? = nil
    ) -> VexFoundation.TabStave {
        let w = width ?? (self.options.width - self.options.staveSpace)
        var opts = options ?? StaveOptions()
        if options?.spacingBetweenLinesPx == nil {
            opts.spacingBetweenLinesPx = self.options.staveSpace * 1.3
        }
        let stave = inRuntimeContext {
            VexFoundation.TabStave(x: x, y: y, width: w, options: opts)
        }
        staves.append(stave)
        if let ctx = context { _ = stave.setContext(ctx) }
        currentStave = stave
        return stave
    }

    // MARK: - Note Factory Methods

    @discardableResult
    public func StaveNote(_ noteStruct: StaveNoteStruct) -> VexFoundation.StaveNote {
        let note = inRuntimeContext { VexFoundation.StaveNote(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return note
    }

    @discardableResult
    public func GlyphNote(
        glyph: Glyph, noteStruct: NoteStruct,
        options: GlyphNoteOptions = GlyphNoteOptions()
    ) -> VexFoundation.GlyphNote {
        let note = inRuntimeContext {
            VexFoundation.GlyphNote(glyph: glyph, noteStruct: noteStruct, options: options)
        }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return note
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
        return note
    }

    @discardableResult
    public func GhostNote(_ noteStruct: NoteStruct) -> VexFoundation.GhostNote {
        let note = inRuntimeContext { VexFoundation.GhostNote(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return note
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
        return note
    }

    @discardableResult
    public func BarNote(type: BarlineType = .single) -> VexFoundation.BarNote {
        let note = inRuntimeContext { VexFoundation.BarNote(type: type) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return note
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
        return note
    }

    @discardableResult
    public func TimeSigNote(time: TimeSignatureSpec = .default) -> VexFoundation.TimeSigNote {
        let note = inRuntimeContext { VexFoundation.TimeSigNote(timeSpec: time) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return note
    }

    @discardableResult
    public func KeySigNote(
        key: String, cancelKey: String? = nil, alterKey: [String]? = nil
    ) -> VexFoundation.KeySigNote {
        let note = inRuntimeContext {
            VexFoundation.KeySigNote(keySpec: key, cancelKeySpec: cancelKey, alterKeySpec: alterKey)
        }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return note
    }

    @discardableResult
    public func TabNote(_ noteStruct: TabNoteStruct) -> VexFoundation.TabNote {
        let note = inRuntimeContext { VexFoundation.TabNote(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        renderQ.append(note)
        return note
    }

    @discardableResult
    public func GraceNote(_ noteStruct: GraceNoteStruct) -> VexFoundation.GraceNote {
        let note = inRuntimeContext { VexFoundation.GraceNote(noteStruct) }
        if let stave = currentStave { _ = note.setStave(stave) }
        if let ctx = context { _ = note.setContext(ctx) }
        return note
    }

    @discardableResult
    public func GraceNoteGroup(
        notes: [StemmableNote], slur: Bool = false
    ) -> VexFoundation.GraceNoteGroup {
        let group = inRuntimeContext {
            VexFoundation.GraceNoteGroup(graceNotes: notes, showSlur: slur)
        }
        if let ctx = context { _ = group.setContext(ctx) }
        return group
    }

    // MARK: - Modifier Factory Methods

    @discardableResult
    public func Accidental(type: AccidentalType) -> VexFoundation.Accidental {
        let accid = inRuntimeContext { VexFoundation.Accidental(type) }
        if let ctx = context { _ = accid.setContext(ctx) }
        return accid
    }

    /// String convenience API that throws on invalid accidental input.
    @discardableResult
    public func Accidental(parsing type: String) throws -> VexFoundation.Accidental {
        let accid = try inRuntimeContext { try VexFoundation.Accidental(parsing: type) }
        if let ctx = context { _ = accid.setContext(ctx) }
        return accid
    }

    /// String convenience API that returns nil on invalid accidental input.
    @discardableResult
    public func Accidental(parsingOrNil type: String) -> VexFoundation.Accidental? {
        let accid = inRuntimeContext { VexFoundation.Accidental(parsingOrNil: type) }
        guard let accid else { return nil }
        if let ctx = context { _ = accid.setContext(ctx) }
        return accid
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
        if let font { _ = annotation.setFont(font) }
        if let ctx = context { _ = annotation.setContext(ctx) }
        return annotation
    }

    @discardableResult
    public func ChordSymbol(
        vJustify: ChordSymbolVerticalJustify = .top,
        hJustify: ChordSymbolHorizontalJustify = .center,
        kerning: Bool = true,
        reportWidth: Bool = true
    ) -> VexFoundation.ChordSymbol {
        let cs = inRuntimeContext { VexFoundation.ChordSymbol() }
        _ = cs.setHorizontal(hJustify)
        _ = cs.setVertical(vJustify)
        _ = cs.setEnableKerning(kerning)
        _ = cs.setReportWidth(reportWidth)
        if let ctx = context { _ = cs.setContext(ctx) }
        return cs
    }

    @discardableResult
    public func Articulation(type: String = "a.") -> VexFoundation.Articulation {
        let artic = inRuntimeContext { VexFoundation.Articulation(type) }
        if let ctx = context { _ = artic.setContext(ctx) }
        return artic
    }

    @discardableResult
    public func Ornament(_ type: String) -> VexFoundation.Ornament {
        let ornament = inRuntimeContext { VexFoundation.Ornament(type) }
        if let ctx = context { _ = ornament.setContext(ctx) }
        return ornament
    }

    @discardableResult
    public func TextDynamics(_ noteStruct: TextNoteStruct) -> VexFoundation.TextDynamics {
        let td = inRuntimeContext { VexFoundation.TextDynamics(noteStruct) }
        if let stave = currentStave { _ = td.setStave(stave) }
        if let ctx = context { _ = td.setContext(ctx) }
        renderQ.append(td)
        return td
    }

    @discardableResult
    public func Fingering(number: String = "0", position: ModifierPosition = .left) -> FretHandFinger {
        let fingering = inRuntimeContext { FretHandFinger(number) }
        _ = fingering.setPosition(position)
        if let ctx = context { _ = fingering.setContext(ctx) }
        return fingering
    }

    @discardableResult
    public func StringNumber(number: String, position: ModifierPosition = .above,
                             drawCircle: Bool = true) -> VexFoundation.StringNumber {
        let sn = inRuntimeContext { VexFoundation.StringNumber(number) }
        _ = sn.setPosition(position)
        _ = sn.setDrawCircle(drawCircle)
        if let ctx = context { _ = sn.setContext(ctx) }
        return sn
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
        return mmr
    }

    // MARK: - Voice

    @discardableResult
    public func Voice(time: VoiceTime? = nil) -> VexFoundation.Voice {
        let voice = inRuntimeContext { VexFoundation.Voice(time: time) }
        voices.append(voice)
        return voice
    }

    @discardableResult
    public func Voice(timeSignature: TimeSignatureSpec) -> VexFoundation.Voice {
        let voice = inRuntimeContext { VexFoundation.Voice(timeSignature: timeSignature) }
        voices.append(voice)
        return voice
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
        return connector
    }

    public func Formatter(options: FormatterOptions = FormatterOptions()) -> VexFoundation.Formatter {
        inRuntimeContext { VexFoundation.Formatter(options: options) }
    }

    // MARK: - Tuplet, Beam

    @discardableResult
    public func Tuplet(notes: [Note] = [], options: TupletOptions = TupletOptions()) -> VexFoundation.Tuplet {
        let tuplet = inRuntimeContext { VexFoundation.Tuplet(notes: notes, options: options) }
        if let ctx = context { _ = tuplet.setContext(ctx) }
        renderQ.append(tuplet)
        return tuplet
    }

    @discardableResult
    public func Beam(
        notes: [StemmableNote],
        autoStem: Bool = false,
        secondaryBeamBreaks: [Int] = [],
        partialBeamDirections: [Int: PartialBeamDirection] = [:]
    ) -> VexFoundation.Beam {
        let beam = inRuntimeContext { VexFoundation.Beam(notes, autoStem: autoStem) }
        if let ctx = context { _ = beam.setContext(ctx) }
        _ = beam.breakSecondaryAt(secondaryBeamBreaks)
        for (noteIndex, direction) in partialBeamDirections {
            _ = beam.setPartialBeamSideAt(noteIndex, side: direction)
        }
        renderQ.append(beam)
        return beam
    }

    // MARK: - Curve, Tie, Line

    @discardableResult
    public func Curve(from: Note, to: Note, options: CurveOptions = CurveOptions()) -> VexFoundation.Curve {
        let curve = inRuntimeContext { VexFoundation.Curve(from: from, to: to, options: options) }
        if let ctx = context { _ = curve.setContext(ctx) }
        renderQ.append(curve)
        return curve
    }

    @discardableResult
    public func StaveTie(notes: TieNotes, text: String? = nil,
                         direction: TieDirection? = nil) -> VexFoundation.StaveTie {
        let tie = inRuntimeContext { VexFoundation.StaveTie(notes: notes, text: text) }
        if let direction { _ = tie.setDirection(direction) }
        if let ctx = context { _ = tie.setContext(ctx) }
        renderQ.append(tie)
        return tie
    }

    @discardableResult
    public func StaveLine(notes: StaveLineNotes, text: String? = nil,
                          font: FontInfo? = nil) -> VexFoundation.StaveLine {
        let line = inRuntimeContext { VexFoundation.StaveLine(notes: notes) }
        if let text { _ = line.setText(text) }
        if let font { _ = line.setFont(font) }
        if let ctx = context { _ = line.setContext(ctx) }
        renderQ.append(line)
        return line
    }

    @discardableResult
    public func VibratoBracket(
        from: Note?, to: Note?, line: Double? = nil, harsh: Bool? = nil
    ) -> VexFoundation.VibratoBracket {
        let vb = inRuntimeContext { VexFoundation.VibratoBracket(start: from, stop: to) }
        if let line { _ = vb.setLine(line) }
        if let harsh { _ = vb.setHarsh(harsh) }
        if let ctx = context { _ = vb.setContext(ctx) }
        renderQ.append(vb)
        return vb
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
        if let line { _ = tb.setLine(line) }
        if let font { _ = tb.setFont(font) }
        if let ctx = context { _ = tb.setContext(ctx) }
        renderQ.append(tb)
        return tb
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
        return system
    }

    // MARK: - EasyScore

    public func EasyScore(options: EasyScoreOptions = EasyScoreOptions()) -> VexFoundation.EasyScore {
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
        return pedal
    }

    // MARK: - NoteSubGroup

    @discardableResult
    public func NoteSubGroup(notes: [Note] = []) -> VexFoundation.NoteSubGroup {
        let group = inRuntimeContext { VexFoundation.NoteSubGroup(subNotes: notes) }
        if let ctx = context { _ = group.setContext(ctx) }
        return group
    }

    // MARK: - Draw

    /// Render the complete score.
    public func draw() throws {
        guard let ctx = context else {
            throw FactoryError.missingRenderContext
        }

        for system in systems {
            _ = system.setContext(ctx)
            system.format()
        }
        for stave in staves {
            _ = stave.setContext(ctx)
            try stave.draw()
        }
        for voice in voices {
            try voice.draw(context: ctx)
        }
        for element in renderQ {
            if !element.isRendered() {
                _ = element.setContext(ctx)
                try element.draw()
            }
        }
        for system in systems {
            _ = system.setContext(ctx)
            try system.draw()
        }
        reset()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Factory", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
