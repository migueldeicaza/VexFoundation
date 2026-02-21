// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Commit Hook

/// Hook called after each note element is committed during parsing.
public typealias CommitHook = (
    _ options: [String: String],
    _ note: StemmableNote,
    _ builder: Builder
) -> Void

// MARK: - Note Piece

/// A single note within a chord or standalone.
public struct NotePiece {
    public var key: String
    public var accid: String?
    public var octave: String?
}

// MARK: - Piece

/// A parsed note piece with duration, dots, type, and options.
public class Piece {
    public var chord: [NotePiece] = []
    public var duration: NoteDurationSpec
    public var dots: Int = 0
    public var type: NoteType?
    public var options: [String: String] = [:]

    public init(duration: NoteDurationSpec) {
        self.duration = duration
    }
}

// MARK: - Builder Elements

/// Elements produced by the Builder.
public struct BuilderElements {
    public var notes: [StemmableNote] = []
    public var accidentals: [[Accidental?]] = []
}

public enum EasyScoreBuilderError: Error, LocalizedError, Equatable, Sendable {
    case invalidDuration(String)
    case invalidType(String)
    case invalidClef(String)
    case invalidStemDirection(String)
    case invalidStaveNoteKeys([String])

    public var errorDescription: String? {
        switch self {
        case .invalidDuration(let raw):
            return "Invalid note duration: \(raw)"
        case .invalidType(let raw):
            return "Invalid note type: \(raw)"
        case .invalidClef(let raw):
            return "Invalid clef: \(raw)"
        case .invalidStemDirection(let raw):
            return "Invalid stem direction: \(raw)"
        case .invalidStaveNoteKeys(let keys):
            return "Invalid stave note keys: \(keys)"
        }
    }
}

public enum EasyScoreParseError: Error, LocalizedError, Sendable {
    case parseFailed(line: String, errorPos: Int?, builderError: EasyScoreBuilderError?)

    public var errorDescription: String? {
        switch self {
        case .parseFailed(let line, let errorPos, let builderError):
            let semantic = builderError?.localizedDescription ?? "none"
            let pos = errorPos.map(String.init) ?? "nil"
            return "EasyScore parse failed for line '\(line)' (errorPos: \(pos), semantic: \(semantic))"
        }
    }
}

public enum EasyScoreInitError: Error, LocalizedError, Equatable, Sendable {
    case missingFactory

    public var errorDescription: String? {
        switch self {
        case .missingFactory:
            return "EasyScore requires a factory."
        }
    }
}

// MARK: - EasyScore Grammar

/// The grammar for parsing EasyScore notation strings.
public final class EasyScoreGrammar: Grammar {
    public var builder: Builder

    public init(builder: Builder) {
        self.builder = builder
    }

    public func begin() -> RuleFunction { LINE }

    func LINE() -> Rule {
        Rule(expect: [PIECE, PIECES, EOL])
    }
    func PIECE() -> Rule {
        Rule(expect: [CHORDORNOTE, PARAMS], run: { [weak self] _ in
            self?.builder.commitPiece()
        })
    }
    func PIECES() -> Rule {
        Rule(expect: [COMMA, PIECE], zeroOrMore: true)
    }
    func PARAMS() -> Rule {
        Rule(expect: [DURATION, TYPE, DOTS, OPTS])
    }
    func CHORDORNOTE() -> Rule {
        Rule(expect: [CHORD, SINGLENOTE], or: true)
    }
    func CHORD() -> Rule {
        Rule(expect: [LPAREN, NOTES, RPAREN], run: { [weak self] matches in
            if matches.count > 1 {
                self?.builder.addChord(matches[1])
            }
        })
    }
    func NOTES() -> Rule {
        Rule(expect: [NOTE], oneOrMore: true)
    }
    func NOTE() -> Rule {
        Rule(expect: [NOTENAME, ACCIDENTAL, OCTAVE])
    }
    func SINGLENOTE() -> Rule {
        Rule(expect: [NOTENAME, ACCIDENTAL, OCTAVE], run: { [weak self] matches in
            let name = matches.count > 0 ? (matches[0].stringValue ?? "") : ""
            let accid = matches.count > 1 ? matches[1].stringValue : nil
            let octave = matches.count > 2 ? matches[2].stringValue : nil
            self?.builder.addSingleNote(key: name, accid: accid, octave: octave)
        })
    }
    func ACCIDENTAL() -> Rule {
        Rule(expect: [MICROTONES, ACCIDENTALS], maybe: true, or: true)
    }
    func DOTS() -> Rule {
        Rule(expect: [DOT], zeroOrMore: true, run: { [weak self] matches in
            self?.builder.setNoteDots(matches)
        })
    }
    func TYPE() -> Rule {
        Rule(expect: [SLASH, MAYBESLASH, TYPES], maybe: true, run: { [weak self] matches in
            if matches.count > 2 {
                self?.builder.setNoteType(matches[2].stringValue)
            }
        })
    }
    func DURATION() -> Rule {
        Rule(expect: [SLASH, DURATIONS], maybe: true, run: { [weak self] matches in
            if matches.count > 1 {
                self?.builder.setNoteDuration(matches[1].stringValue)
            }
        })
    }
    func OPTS() -> Rule {
        Rule(expect: [LBRACKET, KEYVAL, KEYVALS, RBRACKET], maybe: true)
    }
    func KEYVALS() -> Rule {
        Rule(expect: [COMMA, KEYVAL], zeroOrMore: true)
    }
    func KEYVAL() -> Rule {
        Rule(expect: [KEY, EQUALS, VAL], run: { [weak self] matches in
            if matches.count >= 3 {
                let key = matches[0].stringValue ?? ""
                let raw = matches[2].stringValue ?? ""
                // Strip surrounding quotes
                let value: String
                if raw.count >= 2 &&
                   ((raw.hasPrefix("'") && raw.hasSuffix("'")) ||
                    (raw.hasPrefix("\"") && raw.hasSuffix("\""))) {
                    value = String(raw.dropFirst().dropLast())
                } else {
                    value = raw
                }
                self?.builder.addNoteOption(key: key, value: value)
            }
        })
    }
    func VAL() -> Rule {
        Rule(expect: [SVAL, DVAL], or: true)
    }

    // Lexer tokens
    func KEY() -> Rule { Rule(token: "[a-zA-Z][a-zA-Z0-9]*") }
    func DVAL() -> Rule { Rule(token: "[\"'][^\"']*[\"']") }
    func SVAL() -> Rule { Rule(token: "['][^']*[']") }
    func NOTENAME() -> Rule { Rule(token: "[a-gA-G]") }
    func OCTAVE() -> Rule { Rule(token: "[0-9]+") }
    func ACCIDENTALS() -> Rule { Rule(token: "bb|b|##|#|n") }
    func MICROTONES() -> Rule { Rule(token: "bbs|bss|bs|db|d|\\+\\+-|\\+-|\\+\\+|\\+|k|o") }
    func DURATIONS() -> Rule { Rule(token: "[0-9whq]+") }
    func TYPES() -> Rule { Rule(token: "[rRsSmMhHgG]") }
    func LPAREN() -> Rule { Rule(token: "[(]") }
    func RPAREN() -> Rule { Rule(token: "[)]") }
    func COMMA() -> Rule { Rule(token: "[,]") }
    func DOT() -> Rule { Rule(token: "[.]") }
    func SLASH() -> Rule { Rule(token: "[/]") }
    func MAYBESLASH() -> Rule { Rule(token: "[/]?") }
    func EQUALS() -> Rule { Rule(token: "[=]") }
    func LBRACKET() -> Rule { Rule(token: "\\[") }
    func RBRACKET() -> Rule { Rule(token: "\\]") }
    func EOL() -> Rule { Rule(token: "$") }
}

// MARK: - Builder

/// Builds VexFlow objects from parsed note data.
public final class Builder {
    public var factory: Factory
    public var elements: BuilderElements = BuilderElements()
    public var options: [String: String] = [:]
    public var piece: Piece
    public var commitHooks: [CommitHook] = []
    public var rollingDuration: NoteDurationSpec = .eighth
    public private(set) var lastError: EasyScoreBuilderError?

    public init(factory: Factory) {
        self.factory = factory
        self.piece = Piece(duration: .eighth)
        reset()
    }

    public func reset(options: [String: String]? = nil) {
        self.options = [
            "stem": "auto",
            "clef": "treble",
        ]
        if let options {
            for (k, v) in options {
                self.options[k] = v
            }
        }
        elements = BuilderElements()
        rollingDuration = .eighth
        lastError = nil
        resetPiece()
    }

    public func getFactory() -> Factory { factory }
    public func getElements() -> BuilderElements { elements }

    public func addCommitHook(_ hook: @escaping CommitHook) {
        commitHooks.append(hook)
    }

    public func resetPiece() {
        piece = Piece(duration: rollingDuration)
    }

    public func setNoteDots(_ dots: [Match]) {
        piece.dots = dots.count
    }

    public func setNoteDuration(_ duration: String?) {
        if let duration {
            guard let parsed = try? NoteDurationSpec(parsing: duration) else {
                setError(.invalidDuration(duration))
                return
            }
            rollingDuration = parsed
        }
        piece.duration = rollingDuration
    }

    public func setNoteType(_ type: String?) {
        if let type {
            guard let parsed = NoteType(parsing: type) else {
                setError(.invalidType(type))
                return
            }
            piece.type = parsed
        }
    }

    public func addNoteOption(key: String, value: String) {
        piece.options[key] = value
    }

    public func addNote(key: String, accid: String? = nil, octave: String? = nil) {
        piece.chord.append(NotePiece(key: key, accid: accid, octave: octave))
    }

    public func addSingleNote(key: String, accid: String? = nil, octave: String? = nil) {
        addNote(key: key, accid: accid, octave: octave)
    }

    public func addChord(_ match: Match) {
        if let note = notePiece(from: match) {
            addNote(key: note.key, accid: note.accid, octave: note.octave)
            return
        }

        switch match {
        case .array(let items):
            for item in items {
                addChord(item)
            }
        case .string(let s):
            addSingleNote(key: s)
        case .null:
            break
        }
    }

    private func notePiece(from match: Match) -> NotePiece? {
        guard case .array(let parts) = match else { return nil }
        guard let key = parts.first?.stringValue,
              key.count == 1,
              let keyChar = key.first,
              "abcdefgABCDEFG".contains(keyChar)
        else {
            return nil
        }

        let accid = parts.count > 1 ? parts[1].stringValue : nil
        let octave = parts.count > 2 ? parts[2].stringValue : nil
        return NotePiece(key: key, accid: accid, octave: octave)
    }

    public func commitPiece() {
        guard lastError == nil else {
            resetPiece()
            return
        }

        let mergedOptions = options.merging(piece.options) { _, new in new }
        let stem = (mergedOptions["stem"] ?? "auto").lowercased()
        let clefString = (mergedOptions["clef"] ?? ClefName.treble.rawValue).lowercased()
        guard let clef = ClefName(parsing: clefString) else {
            setError(.invalidClef(clefString))
            resetPiece()
            return
        }
        let chord = piece.chord
        let duration = piece.duration
        let dots = piece.dots
        let type = piece.type

        // Build keys for StaveNote
        let standardAccidentals = Music.accidentals
        let keys = chord.map { notePiece -> String in
            let accidStr = standardAccidentals.contains(notePiece.accid ?? "") ? (notePiece.accid ?? "") : ""
            return "\(notePiece.key)\(accidStr)/\(notePiece.octave ?? "4")"
        }

        let autoStem = stem == "auto"
        let explicitStemDirection: StemDirection?
        if autoStem {
            explicitStemDirection = nil
        } else if let parsed = StemDirection(parsing: stem) {
            explicitStemDirection = parsed
        } else {
            setError(.invalidStemDirection(stem))
            resetPiece()
            return
        }

        // Build note
        let note: StemmableNote
        if type == .ghost {
            note = factory.GhostNote(duration: duration.value, dots: dots)
        } else {
            guard let noteStruct = StaveNoteStruct(
                parsingKeysOrNil: keys,
                duration: duration,
                dots: dots,
                type: type,
                autoStem: autoStem,
                clef: clef
            ) else {
                setError(.invalidStaveNoteKeys(keys))
                resetPiece()
                return
            }
            note = factory.StaveNote(noteStruct)
        }
        if let explicitStemDirection {
            _ = note.setStemDirection(explicitStemDirection)
        }

        // Attach accidentals
        var accidentals: [Accidental?] = []
        for (index, notePiece) in chord.enumerated() {
            if let accid = notePiece.accid,
               let accidental = factory.Accidental(parsingOrNil: accid) {
                _ = note.addModifier(accidental, index: index)
                accidentals.append(accidental)
            } else {
                accidentals.append(nil)
            }
        }

        // Attach dots
        for _ in 0..<dots {
            Dot.buildAndAttach([note], all: true)
        }

        // Run commit hooks
        for hook in commitHooks {
            hook(mergedOptions, note, self)
        }

        elements.notes.append(note)
        elements.accidentals.append(accidentals)
        resetPiece()
    }

    private func setError(_ error: EasyScoreBuilderError) {
        if lastError == nil {
            lastError = error
        }
    }
}

// MARK: - EasyScore Options

/// Options for EasyScore initialization.
public struct EasyScoreOptions {
    public var factory: Factory?
    public var runtimeContext: VexRuntimeContext?
    public var builder: Builder?
    public var commitHooks: [CommitHook]?
    public var throwOnError: Bool = false

    public init(factory: Factory? = nil, runtimeContext: VexRuntimeContext? = nil, builder: Builder? = nil,
                commitHooks: [CommitHook]? = nil, throwOnError: Bool = false) {
        self.factory = factory
        self.runtimeContext = runtimeContext
        self.builder = builder
        self.commitHooks = commitHooks
        self.throwOnError = throwOnError
    }
}

// MARK: - EasyScore Defaults

/// Defaults for EasyScore parsing.
public struct EasyScoreDefaults {
    public var clef: ClefName = .treble
    public var time: TimeSignatureSpec = .default
    public var stem: String = "auto"

    public init(clef: ClefName = .treble, time: TimeSignatureSpec = .default, stem: String = "auto") {
        self.clef = clef
        self.time = time
        self.stem = stem
    }
}

// MARK: - EasyScore Commit Hooks

/// Hook to set element id from options.
private func setIdHook(options: [String: String], note: StemmableNote, builder: Builder) {
    guard let id = options["id"] else { return }
    _ = note.setAttribute("id", id)
}

/// Hook to set element class from options.
private func setClassHook(options: [String: String], note: StemmableNote, builder: Builder) {
    guard let classStr = options["class"] else { return }
    for className in classStr.split(separator: ",") {
        _ = note.addClass(className.trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - Match Extension

extension Match {
    /// Extract the string value from a Match, returning nil for null.
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .null: return nil
        case .array: return nil
        }
    }
}

// MARK: - EasyScore

/// Parser-based convenience API for creating VexFlow objects from notation strings.
///
/// Usage:
/// ```
/// let factory = Factory()
/// let score = factory.EasyScore()
/// let notes = score.notes("C4/q, D4, E4, F4")
/// ```
public final class EasyScore {

    public var defaults = EasyScoreDefaults()
    public var options: EasyScoreOptions
    public let runtimeContext: VexRuntimeContext
    public var factory: Factory
    public var builder: Builder
    public var grammar: EasyScoreGrammar
    public var parser: Parser
    public private(set) var lastParseError: EasyScoreBuilderError?

    public convenience init(options: EasyScoreOptions = EasyScoreOptions()) throws {
        guard let factory = options.factory else {
            throw EasyScoreInitError.missingFactory
        }
        let runtimeContext = options.runtimeContext ?? factory.getRuntimeContext()
        let builder = options.builder ?? Builder(factory: factory)
        self.init(factory: factory, runtimeContext: runtimeContext, builder: builder, options: options)
    }

    init(factory: Factory, runtimeContext: VexRuntimeContext, builder: Builder, options: EasyScoreOptions) {
        builder.factory = factory

        self.options = options
        self.options.factory = factory
        self.options.runtimeContext = runtimeContext
        self.options.builder = builder
        self.runtimeContext = runtimeContext
        self.factory = factory
        self.builder = builder
        self.grammar = EasyScoreGrammar(builder: builder)
        self.parser = Parser(grammar: grammar)

        // Default commit hooks
        let hooks: [CommitHook] = options.commitHooks ?? [
            setIdHook,
            setClassHook,
            Articulation.easyScoreHook,
            FretHandFinger.easyScoreHook,
        ]
        for hook in hooks {
            addCommitHook(hook)
        }
    }

    /// Set score defaults (clef, time, stem).
    @discardableResult
    public func set(defaults: EasyScoreDefaults) -> Self {
        self.defaults = defaults
        return self
    }

    /// Set the rendering context.
    @discardableResult
    public func setContext(_ context: RenderContext) -> Self {
        _ = factory.setContext(context)
        return self
    }

    /// Parse a notation string and return the result.
    public func parse(_ line: String, options: [String: String] = [:]) -> ParseResult {
        VexRuntime.withContext(runtimeContext) {
            builder.reset(options: options)
            var result = parser.parse(line)
            self.lastParseError = builder.lastError
            if builder.lastError != nil {
                result.success = false
            }
            return result
        }
    }

    /// Parse and throw on failure (lex/syntax or semantic builder failures).
    public func parseThrowing(_ line: String, options: [String: String] = [:]) throws -> ParseResult {
        let result = parse(line, options: options)
        if result.success {
            return result
        }
        throw EasyScoreParseError.parseFailed(line: line, errorPos: result.errorPos, builderError: lastParseError)
    }

    /// Create beamed notes.
    @discardableResult
    public func beam(
        _ notes: [StemmableNote],
        autoStem: Bool = false,
        secondaryBeamBreaks: [Int] = [],
        partialBeamDirections: [Int: PartialBeamDirection] = [:]
    ) -> [StemmableNote] {
        (try? beamThrowing(
            notes,
            autoStem: autoStem,
            secondaryBeamBreaks: secondaryBeamBreaks,
            partialBeamDirections: partialBeamDirections
        )) ?? notes
    }

    @discardableResult
    public func beamThrowing(
        _ notes: [StemmableNote],
        autoStem: Bool = false,
        secondaryBeamBreaks: [Int] = [],
        partialBeamDirections: [Int: PartialBeamDirection] = [:]
    ) throws -> [StemmableNote] {
        try VexRuntime.withContext(runtimeContext) {
            _ = try factory.BeamThrowing(
                notes: notes, autoStem: autoStem,
                secondaryBeamBreaks: secondaryBeamBreaks,
                partialBeamDirections: partialBeamDirections
            )
            return notes
        }
    }

    /// Create a tuplet from notes.
    @discardableResult
    public func tuplet(_ notes: [StemmableNote],
                       options: TupletOptions = TupletOptions()) -> [StemmableNote] {
        (try? tupletThrowing(notes, options: options)) ?? notes
    }

    @discardableResult
    public func tupletThrowing(_ notes: [StemmableNote],
                               options: TupletOptions = TupletOptions()) throws -> [StemmableNote] {
        try VexRuntime.withContext(runtimeContext) {
            _ = try factory.TupletThrowing(notes: notes.map { $0 as Note }, options: options)
            return notes
        }
    }

    /// Parse a notation string and return the notes.
    public func notes(_ line: String, options: [String: String] = [:]) -> [StemmableNote] {
        VexRuntime.withContext(runtimeContext) {
            var mergedOptions = ["clef": defaults.clef.rawValue, "stem": defaults.stem]
            for (k, v) in options { mergedOptions[k] = v }
            _ = parse(line, options: mergedOptions)
            return builder.getElements().notes
        }
    }

    /// Parse notes and throw if parsing fails.
    public func notesThrowing(_ line: String, options: [String: String] = [:]) throws -> [StemmableNote] {
        try VexRuntime.withContext(runtimeContext) {
            var mergedOptions = ["clef": defaults.clef.rawValue, "stem": defaults.stem]
            for (k, v) in options { mergedOptions[k] = v }
            _ = try parseThrowing(line, options: mergedOptions)
            return builder.getElements().notes
        }
    }

    /// Create a voice with the given notes.
    public func voice(_ notes: [Note], time: TimeSignatureSpec? = nil) -> Voice {
        (try? voiceThrowing(notes, time: time)) ?? factory.Voice()
    }

    public func voiceThrowing(_ notes: [Note], time: TimeSignatureSpec? = nil) throws -> Voice {
        try VexRuntime.withContext(runtimeContext) {
            let t = time ?? defaults.time
            let voice = try factory.VoiceThrowing(timeSignature: t)
            _ = try voice.addTickablesThrowing(notes)
            return voice
        }
    }

    /// Add a commit hook.
    public func addCommitHook(_ hook: @escaping CommitHook) {
        builder.addCommitHook(hook)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("EasyScore", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C#5/8, D5, E5, F5, G5, A5, B5, C6")
        _ = score.beam(Array(notes[0..<4]))
        _ = score.beam(Array(notes[4..<8]))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble).addKeySignature("G").addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
