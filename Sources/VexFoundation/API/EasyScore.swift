// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/easyscore.ts` (VexFlow 5.2.0).
// Compose native notation through EasyScore, with pure diagnostics and staged strict construction.
//
// Swift notes:
// - Builder options are `[String: String]`. Typed upstream options (`octaveShift`, `durationOverride`, ...)
//   are written as strings (`"1"`, `"1/2"`).
// - Source offsets count `Character`s (upstream counts UTF-16 code units; the same for ASCII input).
// - The throwing variants (`notesThrowing`, `parseThrowing`, ...) report the upstream exceptions. The
//   non-throwing variants keep the 5.1.0 Swift behavior and record the error.

import Foundation

// MARK: - Commit Hook

/// Hook called after each note element is committed during parsing.
/// A hook can throw to reject the note (VexFlow 5.2.0).
public typealias CommitHook = (
    _ options: [String: String],
    _ note: StemmableNote,
    _ builder: Builder
) throws -> Void

// MARK: - Note Piece

/// A single note within a chord or standalone.
public struct NotePiece: Equatable {
    public var key: String
    public var accid: String?
    public var octave: String?
}

// MARK: - Source ranges and diagnostics (VexFlow 5.2.0)

/// Zero-based, end-exclusive source range.
public struct EasyScoreSourceSpan: Equatable, Sendable {
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

/// Editor-friendly error. Line and column are one-based.
public struct EasyScoreDiagnostic: Equatable, Sendable {
    public var code: String
    public var message: String
    public var start: Int
    public var end: Int
    public var line: Int
    public var column: Int
    public var measure: Int?
}

/// The same diagnostics are available to callers that prefer exceptions.
public struct EasyScoreError: Error, LocalizedError, CustomStringConvertible {
    public let diagnostics: [EasyScoreDiagnostic]

    public init(_ diagnostics: [EasyScoreDiagnostic]) {
        self.diagnostics = diagnostics
    }

    public var description: String {
        diagnostics.map { "\($0.message) (\($0.line):\($0.column))" }.joined(separator: "; ")
    }

    public var errorDescription: String? { description }
}

/// Convert a source range into the common diagnostic shape.
private func diagnostic(_ line: String, _ code: String, _ message: String, _ source: EasyScoreSourceSpan) -> EasyScoreDiagnostic {
    let prefix = Array(line.prefix(max(0, source.start)))
    let lineNumber = prefix.filter { $0 == "\n" }.count + 1
    let lastNewline = prefix.lastIndex(of: "\n") ?? -1
    return EasyScoreDiagnostic(
        code: code, message: message, start: source.start, end: source.end,
        line: lineNumber, column: source.start - lastNewline, measure: nil
    )
}

/// The message of an error, for diagnostics.
private func errorMessage(_ error: Error) -> String {
    if let error = error as? VexError { return error.message.isEmpty ? error.code : error.message }
    if let error = error as? LocalizedError, let description = error.errorDescription { return description }
    return String(describing: error)
}

// MARK: - Piece

/// A parsed note piece with duration, dots, type, and options.
public class Piece {
    /// Range of this piece in the most recently parsed input. (VexFlow 5.2.0)
    public var source: EasyScoreSourceSpan?
    public var chord: [NotePiece] = []
    public var duration: NoteDurationSpec
    /// The duration as written (upstream `piece.duration`, for example `"h"`).
    public var durationToken: String?
    public var dots: Int = 0
    public var type: NoteType?
    /// The type as written (upstream `piece.type`, for example `"r"`).
    public var typeToken: String?
    public var options: [String: String] = [:]

    public init(duration: NoteDurationSpec, durationToken: String? = nil) {
        self.duration = duration
        self.durationToken = durationToken
    }
}

/// Parsed notation contains data only; no VexFlow elements or render context. (VexFlow 5.2.0)
public struct EasyScoreParsedPiece: Equatable {
    public var source: EasyScoreSourceSpan
    public var chord: [NotePiece]
    /// The duration as written, for example `"q"`.
    public var duration: String
    public var dots: Int
    public var type: String?
    public var options: [String: String]
}

public struct EasyScoreParseResult {
    public var success: Bool
    public var pieces: [EasyScoreParsedPiece]
    public var diagnostics: [EasyScoreDiagnostic]
}

/// Pure extension validation runs before any Factory construction or commit hook.
public struct EasyScoreValidationContext {
    public let piece: EasyScoreParsedPiece
    public let options: [String: String]
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
        Rule(expect: [CHORDORNOTE, PARAMS], runState: { [weak self] state in
            self?.builder.commitPiece(source: EasyScoreSourceSpan(start: state.start, end: state.end))
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
open class Builder {
    public var factory: Factory
    public var elements: BuilderElements = BuilderElements()
    public var options: [String: String] = [:]
    public var piece: Piece
    public var commitHooks: [CommitHook] = []
    public var rollingDuration: NoteDurationSpec = .eighth
    /// The rolling duration as written (upstream `rollingDuration`, default `"8"`).
    public var rollingDurationToken: String? = "8"
    public private(set) var lastError: EasyScoreBuilderError?
    /// The error thrown by a commit hook or note constructor. Later pieces are skipped,
    /// as upstream stops parsing at the exception. (VexFlow 5.2.0)
    public internal(set) var commitError: Error?
    /// EasyScore observes completed pieces after application hooks have run. (VexFlow 5.2.0)
    var onNote: ((StemmableNote, EasyScoreSourceSpan?) throws -> Void)?

    public init(factory: Factory) {
        self.factory = factory
        self.piece = Piece(duration: .eighth)
        reset()
    }

    open func reset(options: [String: String]? = nil) {
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
        rollingDurationToken = "8"
        lastError = nil
        commitError = nil
        // Initial duration for notes that omit one (VexFlow 5.1.0 `BuilderOptions.duration`).
        if let duration = options?["duration"] {
            rollingDurationToken = Note.durationToken(of: duration)
            if let parsed = try? NoteDurationSpec(parsing: duration) {
                rollingDuration = parsed
            } else {
                rollingDurationToken = duration
                lastError = .invalidDuration(duration)
            }
        }
        resetPiece()
    }

    public func getFactory() -> Factory { factory }
    public func getElements() -> BuilderElements { elements }

    public func addCommitHook(_ hook: @escaping CommitHook) {
        commitHooks.append(hook)
    }

    public func resetPiece() {
        piece = Piece(duration: rollingDuration, durationToken: rollingDurationToken)
    }

    public func setNoteDots(_ dots: [Match]) {
        piece.dots = dots.count
    }

    public func setNoteDuration(_ duration: String?) {
        if let duration {
            guard let parsed = try? NoteDurationSpec(parsing: duration) else {
                // Keep the token as written, so diagnostics can report it.
                rollingDurationToken = duration
                piece.durationToken = duration
                setError(.invalidDuration(duration))
                return
            }
            rollingDuration = parsed
            rollingDurationToken = Note.durationToken(of: duration)
        }
        piece.duration = rollingDuration
        piece.durationToken = rollingDurationToken
    }

    public func setNoteType(_ type: String?) {
        if let type {
            piece.typeToken = type
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

    /// Commit the current piece without a source range.
    public func commitPiece() {
        commitPiece(source: nil)
    }

    /// Commit the current piece. `source` is its range in the parsed input. (VexFlow 5.2.0)
    open func commitPiece(source: EasyScoreSourceSpan?) {
        piece.source = source
        guard lastError == nil, commitError == nil else {
            resetPiece()
            return
        }
        do {
            try buildPiece(source)
        } catch {
            commitError = error
        }
        resetPiece()
    }

    private func buildPiece(_ source: EasyScoreSourceSpan?) throws {
        let mergedOptions = options.merging(piece.options) { _, new in new }
        let stem = (mergedOptions["stem"] ?? "auto").lowercased()
        let clefString = (mergedOptions["clef"] ?? ClefName.treble.rawValue).lowercased()
        guard let clef = ClefName(parsing: clefString) else {
            setError(.invalidClef(clefString))
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

        // Native note options (VexFlow 5.2.0). Unparsable values are ignored, as the strict
        // EasyScore validation rejects them before construction.
        let octaveShift = mergedOptions["octaveShift"].flatMap { Double($0) }.map { Int($0) }
        let strokePx = mergedOptions["strokePx"].flatMap { Double($0) }
        let line = mergedOptions["line"].flatMap { Double($0) }
        let alignCenter = mergedOptions["alignCenter"] == "true"
        let durationOverride = mergedOptions["durationOverride"].flatMap(parseEasyScoreFraction)

        let autoStem = stem == "auto"
        let explicitStemDirection: StemDirection?
        if autoStem {
            explicitStemDirection = nil
        } else if let parsed = StemDirection(parsing: stem) {
            explicitStemDirection = parsed
        } else {
            setError(.invalidStemDirection(stem))
            return
        }

        // Build note
        let note: StemmableNote
        if type == .ghost {
            var noteStruct = NoteStruct(duration: duration)
            noteStruct.dots = dots
            noteStruct.line = line
            noteStruct.alignCenter = alignCenter
            noteStruct.durationOverride = durationOverride
            noteStruct.durationToken = piece.durationToken
            note = factory.GhostNote(noteStruct)
        } else {
            guard var noteStruct = StaveNoteStruct(
                parsingKeysOrNil: keys,
                duration: duration,
                dots: dots,
                type: type,
                autoStem: autoStem,
                clef: clef
            ) else {
                setError(.invalidStaveNoteKeys(keys))
                return
            }
            noteStruct.durationToken = piece.durationToken
            noteStruct.octaveShift = octaveShift
            noteStruct.strokePx = strokePx
            noteStruct.line = line
            noteStruct.alignCenter = alignCenter
            noteStruct.durationOverride = durationOverride
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
            try hook(mergedOptions, note, self)
        }

        try onNote?(note, source)
        elements.notes.append(note)
        elements.accidentals.append(accidentals)
    }

    func setError(_ error: EasyScoreBuilderError) {
        if lastError == nil {
            lastError = error
        }
    }

    /// Capture the builder state that a failed strict operation restores.
    func snapshot() -> () -> Void {
        let saved = (elements, options, piece, rollingDuration, rollingDurationToken, lastError, commitError)
        return { [weak self] in
            guard let self else { return }
            (self.elements, self.options, self.piece, self.rollingDuration, self.rollingDurationToken,
             self.lastError, self.commitError) = saved
        }
    }
}

/// Parse `"n/d"` or `"n"` into a Fraction.
private func parseEasyScoreFraction(_ raw: String) -> Fraction? {
    let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == 1 || parts.count == 2, let numerator = Int(parts[0]) else { return nil }
    let denominator = parts.count == 2 ? Int(parts[1]) : 1
    guard let denominator, denominator != 0 else { return nil }
    return Fraction(numerator, denominator)
}

/// Collect pieces without calling Factory constructors or commit hooks.
private final class NotationBuilder: Builder {
    var pieces: [EasyScoreParsedPiece] = []

    override func commitPiece(source: EasyScoreSourceSpan?) {
        pieces.append(EasyScoreParsedPiece(
            source: source ?? EasyScoreSourceSpan(start: 0, end: 0),
            chord: piece.chord,
            duration: piece.durationToken ?? piece.duration.value.rawValue,
            dots: piece.dots,
            type: piece.typeToken,
            options: piece.options
        ))
        resetPiece()
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
    /// Reject unknown built-in options. Enabled by `create()`; legacy factories keep their extension
    /// behavior. (VexFlow 5.2.0)
    public var strictOptions: Bool = false
    /// Extra option names consumed by application commit hooks in strict mode. (VexFlow 5.2.0)
    public var extensions: [String] = []
    /// Throw to return a source diagnostic. Must not mutate input or application state. (VexFlow 5.2.0)
    public var validate: ((EasyScoreValidationContext) throws -> Void)?

    public init(factory: Factory? = nil, runtimeContext: VexRuntimeContext? = nil, builder: Builder? = nil,
                commitHooks: [CommitHook]? = nil, throwOnError: Bool = false, strictOptions: Bool = false,
                extensions: [String] = [], validate: ((EasyScoreValidationContext) throws -> Void)? = nil) {
        self.factory = factory
        self.runtimeContext = runtimeContext
        self.builder = builder
        self.commitHooks = commitHooks
        self.throwOnError = throwOnError
        self.strictOptions = strictOptions
        self.extensions = extensions
        self.validate = validate
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

/// Voice settings are applied before inserting notes, including strictness and resolution. (VexFlow 5.2.0)
public struct EasyScoreVoiceOptions {
    /// `nil` uses the score default time.
    public var time: VoiceTime?
    public var mode: VoiceMode
    public var softmaxFactor: Double?

    public init(time: VoiceTime? = nil, mode: VoiceMode = .strict, softmaxFactor: Double? = nil) {
        self.time = time
        self.mode = mode
        self.softmaxFactor = softmaxFactor
    }

    /// Use a meter, for example `.meter(7, 8)`.
    public init(timeSignature: TimeSignatureSpec, mode: VoiceMode = .strict, softmaxFactor: Double? = nil) throws {
        self.init(time: try VoiceTime(timeSignature: timeSignature), mode: mode, softmaxFactor: softmaxFactor)
    }
}

/// An item of `EasyScore.sequence(_:)`. (VexFlow 5.2.0)
public enum EasyScoreSequenceItem {
    case notation(String)
    case note(StaveNoteStruct)
    case tickable(Tickable)
}

// MARK: - EasyScore Commit Hooks

/// Hook to set element id from options.
private func setIdHook(options: [String: String], note: StemmableNote, builder: Builder) throws {
    guard let id = options["id"] else { return }
    _ = try note.setAttributeThrowing("id", id)
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
/// let score = EasyScore.create()
/// let notes = try score.notesThrowing("C4/q, D4, E4, F4")
/// ```
public final class EasyScore {

    /// To enable logging for this class. Set `EasyScore.DEBUG` to `true`.
    nonisolated(unsafe) public static var DEBUG: Bool = false

    public var defaults = EasyScoreDefaults()
    public var options: EasyScoreOptions
    public let runtimeContext: VexRuntimeContext
    public var factory: Factory
    public var builder: Builder
    public var grammar: EasyScoreGrammar
    public var parser: Parser
    public private(set) var lastParseError: EasyScoreBuilderError?
    /// The last error recorded by a non-throwing method. (VexFlow 5.2.0)
    public private(set) var lastError: Error?

    private let references = EasyScoreReferences()
    /// The complete measure input, when `parse()` is constructing a trimmed measure.
    private var sourceContext: (input: String, offset: Int, measure: Int)?
    /// True when the default hooks (with `Articulation.easyScoreHook`) are installed.
    private let usesArticulationHook: Bool

    /// Typed constructors return native objects and share the score's transaction boundary. (VexFlow 5.2.0)
    public var make: EasyScoreElements { EasyScoreElements(score: self) }

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
        self.usesArticulationHook = options.commitHooks == nil

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

    /// Create a strict EasyScore with its own Factory (`throwOnError` and `strictOptions` are set).
    /// (VexFlow 5.2.0)
    public static func create(
        options: FactoryOptions = FactoryOptions(),
        scoreOptions: EasyScoreOptions = EasyScoreOptions(),
        runtimeContext: VexRuntimeContext = VexRuntime.getCurrentContext()
    ) -> EasyScore {
        var scoreOptions = scoreOptions
        scoreOptions.throwOnError = true
        scoreOptions.strictOptions = true
        return Factory(options: options, runtimeContext: runtimeContext).EasyScore(options: scoreOptions)
    }

    // MARK: - References (VexFlow 5.2.0)

    /// Inspect notation provenance without installing a global Registry. Useful for visual tooling.
    public static func getSource(_ element: VexElement) -> EasyScoreSource? {
        EasyScoreReferences.sourceOf(element)
    }

    /// Look up a native object in this score. Missing IDs return nil.
    public func getElement(_ id: String) -> VexElement? {
        references.get(id)
    }

    /// Resolve a named note for typed relationship APIs. Missing IDs and non-notes throw.
    public func getNote(_ id: String) throws -> Note {
        guard let note = getElement(id) as? Note else {
            throw VexError("BadArguments", "No note with ID: \(id)")
        }
        return note
    }

    /// Return a copy of a generated element's source, or nil for native objects.
    public func getSource(_ element: VexElement) -> EasyScoreSource? {
        references.getSource(element)
    }

    /// Explicitly join a native extension to this score's ownership and drawing lifecycle.
    @discardableResult
    public func adopt<T: VexElement>(_ element: T, role: FactoryElementRole) throws -> T {
        try transaction { try self.references.add(try self.factory.adopt(element, role: role)) }
    }

    /// Stage local references together with Factory queues and ambient registry entries.
    func transaction<T>(_ build: () throws -> T) throws -> T {
        try VexRuntime.withContext(runtimeContext) {
            try references.transaction { try factory.transaction(build) }
        }
    }

    /// Construct inside the transaction and record the result in the score references.
    func manage<T: VexElement>(_ construct: () throws -> T) throws -> T {
        try transaction { try self.references.add(try construct()) }
    }

    /// Clef and stem defaults for typed notes.
    func noteDefaults() -> (clef: ClefName, autoStem: Bool, stemDirection: StemDirection) {
        (defaults.clef, defaults.stem.lowercased() == "auto", defaults.stem.lowercased() == "down" ? .down : .up)
    }

    // MARK: - Attachment (VexFlow 5.2.0)

    /// Attach a modifier once. Native custom modifiers are welcome; foreign Factory objects are rejected.
    @discardableResult
    public func attach<T: Note>(_ note: T, _ modifier: Modifier, index: Int = 0) throws -> T {
        try requireOwned(note)
        try checkIndex(note, index)
        if let owner = Factory.getOwner(modifier), owner !== factory {
            throw VexError("BadArguments", "Modifier belongs to another Factory.")
        }
        if let attached = modifier.note {
            if attached === note && modifier.getIndex() == index && note.getModifiers().contains(where: { $0 === modifier }) {
                return note
            }
            throw VexError("BadArguments", "Modifier is already attached. Create a separate modifier.")
        }
        return try transaction {
            try self.adopt(modifier, role: .modifier)
            _ = note.addModifier(modifier, index: index)
            return note
        }
    }

    /// Attach staff notation once; the stave owns its drawing lifecycle.
    @discardableResult
    public func attachToStave<T: Stave>(_ stave: T, _ modifier: StaveModifier, position: StaveModifierPosition? = nil) throws -> T {
        try requireOwned(stave)
        if let owner = Factory.getOwner(modifier), owner !== factory {
            throw VexError("BadArguments", "Modifier belongs to another Factory.")
        }
        if let attachedStave = modifier.getStave() {
            if attachedStave === stave && stave.getModifiers().contains(where: { $0 === modifier })
                && (position == nil || position == modifier.getPosition()) {
                return stave
            }
            throw VexError("BadArguments", "Stave modifier is already attached.")
        }
        return try transaction {
            try self.adopt(modifier, role: .staveModifier)
            _ = stave.addModifier(modifier, position: position)
            return stave
        }
    }

    // MARK: - Construction scopes (VexFlow 5.2.0)

    /// Apply temporary defaults to synchronous managed construction; restore them on success or failure.
    public func withDefaults<T>(
        clef: ClefName? = nil, time: TimeSignatureSpec? = nil, stem: String? = nil,
        _ construct: (EasyScore) throws -> T
    ) throws -> T {
        let previous = defaults
        defer { defaults = previous }
        set(clef: clef, time: time, stem: stem)
        return try build(construct)
    }

    /// Construct aligned measures and resolve forward references before layout or drawing.
    public func compose(_ spec: EasyScoreCompositionSpec) throws -> EasyScoreComposition {
        try VexRuntime.withContext(runtimeContext) { try easyScoreCompose(self, spec) }
    }

    /// Build a normal System; its staff API and formatter options stay available.
    public func system(_ options: SystemOptions = SystemOptions()) throws -> System {
        try transaction { try self.references.add(self.factory.System(options: options)) }
    }

    /// Create a native responsive Sheet. Its systems remain managed by this Factory.
    public func sheet(_ options: SheetOptions = SheetOptions()) throws -> Sheet {
        try transaction { try self.factory.Sheet(options: options) }
    }

    /// Stage a group of synchronous construction calls. Failed groups release their new objects and IDs.
    /// Existing-object setters and application side effects remain the caller's responsibility.
    public func build<T>(_ construct: (EasyScore) throws -> T) throws -> T {
        let restore = builder.snapshot()
        do {
            return try transaction { try construct(self) }
        } catch {
            restore()
            throw error
        }
    }

    /// Apply the Factory foreground defaults without changing global metrics or fonts.
    @discardableResult
    public func setStyle(_ style: ElementStyle) -> Self {
        factory.setStyle(style)
        return self
    }

    /// Delegate drawing and the opt-in retained lifecycle to Factory.
    public func draw(retain: Bool = false) throws {
        try VexRuntime.withContext(runtimeContext) { try factory.draw(retain: retain) }
    }

    /// Release queued notation and the builder's last result.
    @discardableResult
    public func reset() -> Self {
        factory.reset()
        builder.reset()
        references.clear()
        return self
    }

    /// Endpoints and voice notes must share this score's Factory.
    func requireOwned(_ element: VexElement) throws {
        if Factory.getOwner(element) !== factory {
            throw VexError("BadArguments", "Note belongs to another Factory or was constructed outside this Factory.")
        }
    }

    /// Reject invalid chord-head references before attaching or queuing notation.
    func checkIndex(_ note: Note, _ index: Int) throws {
        let count = (note as? TabNote)?.getPositions().count ?? max(1, note.getKeys().count)
        if index < 0 || index >= count {
            throw VexError("BadArguments", "Invalid chord index: \(index)")
        }
    }

    // MARK: - Defaults and options

    /// Set score defaults (clef, time, stem).
    @discardableResult
    public func set(defaults: EasyScoreDefaults) -> Self {
        self.defaults = defaults
        return self
    }

    /// Change some score defaults and keep the others (upstream `set({ ... })`). (VexFlow 5.2.0)
    @discardableResult
    public func set(clef: ClefName? = nil, time: TimeSignatureSpec? = nil, stem: String? = nil) -> Self {
        if let clef { defaults.clef = clef }
        if let time { defaults.time = time }
        if let stem { defaults.stem = stem }
        return self
    }

    /// Set the rendering context.
    @discardableResult
    public func setContext(_ context: RenderContext) -> Self {
        _ = factory.setContext(context)
        return self
    }

    // MARK: - Parsing

    /// Parse and validate without touching this builder, its hooks, Factory queues, or registries. (VexFlow 5.2.0)
    public func parseNotation(_ line: String, options: [String: String] = [:]) -> EasyScoreParseResult {
        VexRuntime.withContext(runtimeContext) {
            let builder = NotationBuilder(factory: factory)
            var merged = ["clef": defaults.clef.rawValue, "stem": defaults.stem]
            for (k, v) in options { merged[k] = v }
            builder.reset(options: merged)
            let result = Parser(grammar: EasyScoreGrammar(builder: builder)).parse(line)
            if !result.success {
                let start = max(0, result.furthestErrorPos ?? result.errorPos ?? 0)
                return EasyScoreParseResult(success: false, pieces: [], diagnostics: [
                    diagnostic(line, "SyntaxError", "Invalid EasyScore notation", EasyScoreSourceSpan(
                        start: start, end: min(line.count, start + 1)
                    )),
                ])
            }
            var diagnostics: [EasyScoreDiagnostic] = []
            for piece in builder.pieces {
                do {
                    let pieceOptions = builder.options.merging(piece.options) { _, new in new }
                    try validatePiece(piece, pieceOptions)
                    // Validation sees copies (value types), so extensions cannot rewrite the parser's output.
                    try self.options.validate?(EasyScoreValidationContext(piece: piece, options: pieceOptions))
                } catch {
                    diagnostics.append(diagnostic(line, "InvalidNotation", errorMessage(error), piece.source))
                }
            }
            return EasyScoreParseResult(
                success: diagnostics.isEmpty, pieces: diagnostics.isEmpty ? builder.pieces : [], diagnostics: diagnostics
            )
        }
    }

    /// Validate built-in fields before allocating notes. Extension values are left to application hooks.
    private func validatePiece(_ piece: EasyScoreParsedPiece, _ options: [String: String]) throws {
        if Tables.durationToTicks(piece.duration) == nil || (try? NoteDurationSpec(parsing: piece.duration)) == nil {
            throw VexError("BadArguments", "Invalid note duration: \(piece.duration)")
        }
        let stem = (options["stem"] ?? "auto").lowercased()
        if !["auto", "up", "down"].contains(stem) {
            throw VexError("BadArguments", "Invalid stem: \(options["stem"] ?? "")")
        }
        if ClefName(parsing: (options["clef"] ?? "treble").lowercased()) == nil {
            throw VexError("BadArguments", "Invalid clef: \(options["clef"] ?? "")")
        }
        for name in ["octaveShift", "strokePx", "line"] {
            if let value = options[name], !(Double(value)?.isFinite ?? false) {
                throw VexError("BadArguments", "Invalid numeric option: \(name)")
            }
        }
        if let alignCenter = options["alignCenter"], alignCenter != "true" && alignCenter != "false" {
            throw VexError("BadArguments", "alignCenter must be true or false.")
        }
        if let raw = options["durationOverride"] {
            guard let fraction = parseEasyScoreFraction(raw), fraction.value().isFinite, fraction.value() > 0 else {
                throw VexError("BadArguments", "durationOverride must be a positive finite Fraction.")
            }
        }
        if let articulations = options["articulations"], !articulations.isEmpty, usesArticulationHook {
            _ = try Articulation.parseEasyScore(articulations)
        }
        if self.options.strictOptions {
            let known = Set([
                "stem", "clef", "duration", "id", "class", "articulations", "fingerings", "octaveShift",
                "strokePx", "line", "alignCenter", "durationOverride",
            ] + self.options.extensions)
            for name in options.keys.sorted() where !known.contains(name) {
                throw VexError("BadArguments", "Unknown EasyScore option: \(name)")
            }
        }
    }

    /// Parse a notation string and return the result. Strict scores (`throwOnError`) record a failure
    /// in `lastError` and return an unsuccessful result; use `parseThrowing` for the diagnostics.
    public func parse(_ line: String, options: [String: String] = [:]) -> ParseResult {
        do {
            return try parseSourced(line, options: options)
        } catch {
            lastError = error
            return ParseResult(success: false)
        }
    }

    /// Parse and throw on failure. Strict scores throw `EasyScoreError` with diagnostics.
    public func parseThrowing(_ line: String, options: [String: String] = [:]) throws -> ParseResult {
        let result = try parseSourced(line, options: options)
        if result.success {
            return result
        }
        if let error = builder.commitError { throw error }
        throw EasyScoreParseError.parseFailed(line: line, errorPos: result.errorPos, builderError: lastParseError)
    }

    /// Observe source ranges only during this parse, including legacy partial results.
    private func parseSourced(_ line: String, options: [String: String]) throws -> ParseResult {
        let previous = builder.onNote
        let context = sourceContext
        builder.onNote = { [unowned self] note, span in
            try previous?(note, span)
            let source = span.map { span in
                EasyScoreSource(
                    input: context?.input ?? line,
                    start: span.start + (context?.offset ?? 0),
                    end: span.end + (context?.offset ?? 0),
                    measure: context?.measure
                )
            }
            try self.references.add(note, source: source)
            for modifier in note.getModifiers() { try self.references.add(modifier, source: source) }
        }
        defer { builder.onNote = previous }
        return try VexRuntime.withContext(runtimeContext) { try parseInput(line, options: options) }
    }

    /// Strict construction is transactional; the legacy non-throwing parser retains partial output.
    private func parseInput(_ line: String, options: [String: String]) throws -> ParseResult {
        if !self.options.throwOnError {
            builder.reset(options: options)
            var result = parser.parse(line)
            lastParseError = builder.lastError
            if builder.lastError != nil || builder.commitError != nil {
                result.success = false
            }
            if let error = builder.commitError { lastError = error }
            return result
        }
        // parse() retains Builder's defaults; notes() supplies EasyScore's defaults explicitly.
        var preflightOptions = ["clef": "treble", "stem": "auto"]
        for (k, v) in options { preflightOptions[k] = v }
        let parsed = parseNotation(line, options: preflightOptions)
        if !parsed.success { throw EasyScoreError(parsed.diagnostics) }
        let restore = builder.snapshot()
        do {
            return try transaction {
                self.builder.reset(options: options)
                let result = self.parser.parse(line)
                self.lastParseError = self.builder.lastError
                if let error = self.builder.commitError { throw error }
                if !result.success || self.builder.lastError != nil {
                    throw VexError("BadArguments", "Error parsing line: \(line)")
                }
                return result
            }
        } catch {
            let index = builder.elements.notes.count
            let source = index < parsed.pieces.count
                ? parsed.pieces[index].source
                : EasyScoreSourceSpan(start: 0, end: line.count)
            restore()
            throw EasyScoreError([diagnostic(line, "ConstructionError", errorMessage(error), source)])
        }
    }

    // MARK: - Beams and tuplets

    /// Create beamed notes. `autoStem: nil` resolves automatic stems for the whole group while respecting
    /// explicit stems; `true` overrides explicit directions; `false` preserves all directions. (VexFlow 5.2.0)
    @discardableResult
    public func beam(
        _ notes: [StemmableNote],
        autoStem: Bool? = nil,
        secondaryBeamBreaks: [Int] = [],
        partialBeamDirections: [Int: PartialBeamDirection] = [:]
    ) -> [StemmableNote] {
        do {
            return try beamThrowing(
                notes,
                autoStem: autoStem,
                secondaryBeamBreaks: secondaryBeamBreaks,
                partialBeamDirections: partialBeamDirections
            )
        } catch {
            lastError = error
            return notes
        }
    }

    @discardableResult
    public func beamThrowing(
        _ notes: [StemmableNote],
        autoStem: Bool? = nil,
        secondaryBeamBreaks: [Int] = [],
        partialBeamDirections: [Int: PartialBeamDirection] = [:]
    ) throws -> [StemmableNote] {
        try VexRuntime.withContext(runtimeContext) {
            if options.strictOptions {
                _ = try make.beam(
                    notes: notes, autoStem: autoStem, secondaryBeamBreaks: secondaryBeamBreaks,
                    partialBeamDirections: partialBeamDirections
                )
            } else {
                let autoStem = autoStem ?? resolveBeamStems(notes)
                _ = try transaction {
                    try self.references.add(try self.factory.BeamThrowing(
                        notes: notes, autoStem: autoStem,
                        secondaryBeamBreaks: secondaryBeamBreaks,
                        partialBeamDirections: partialBeamDirections
                    ))
                }
            }
            return notes
        }
    }

    /// Generate and own native beam groups without changing rhythmic duration. (VexFlow 5.2.0)
    @discardableResult
    public func autoBeam(_ notes: [StemmableNote], options: EasyScoreAutoBeamOptions = EasyScoreAutoBeamOptions()) throws -> [Beam] {
        try VexRuntime.withContext(runtimeContext) { try easyScoreAutoBeam(self, notes, options) }
    }

    /// Explicit pitched stems constrain the group; conflicting explicit stems remain mixed.
    func resolveBeamStems(_ notes: [StemmableNote]) -> Bool {
        var directions: [StemDirection] = []
        for note in notes where !note.isRest() && !note.isAutoStem() {
            let direction = note.getStemDirection()
            if !directions.contains(direction) { directions.append(direction) }
        }
        // With no explicit direction, Beam chooses from the complete group's pitches.
        if directions.isEmpty { return true }
        if directions.count == 1 {
            for note in notes where note.isAutoStem() {
                _ = note.setStemDirection(directions[0], autoStem: true)
            }
        }
        return false
    }

    /// Create a tuplet from notes.
    @discardableResult
    public func tuplet(_ notes: [StemmableNote],
                       options: TupletOptions = TupletOptions()) -> [StemmableNote] {
        do {
            return try tupletThrowing(notes, options: options)
        } catch {
            lastError = error
            return notes
        }
    }

    @discardableResult
    public func tupletThrowing(_ notes: [StemmableNote],
                               options: TupletOptions = TupletOptions()) throws -> [StemmableNote] {
        try VexRuntime.withContext(runtimeContext) {
            if self.options.strictOptions {
                _ = try make.tuplet(notes: notes, options: options)
            } else {
                _ = try transaction {
                    try self.references.add(try self.factory.TupletThrowing(notes: notes.map { $0 as Note }, options: options))
                }
            }
            return notes
        }
    }

    // MARK: - Notes

    private func notesOptions(_ options: [String: String]) -> [String: String] {
        var merged = ["clef": defaults.clef.rawValue, "stem": defaults.stem]
        for (k, v) in options { merged[k] = v }
        return merged
    }

    /// Parse a notation string and return the notes.
    public func notes(_ line: String, options: [String: String] = [:]) -> [StemmableNote] {
        _ = parse(line, options: notesOptions(options))
        return builder.getElements().notes
    }

    /// Parse notes and throw if parsing fails.
    public func notesThrowing(_ line: String, options: [String: String] = [:]) throws -> [StemmableNote] {
        _ = try parseThrowing(line, options: notesOptions(options))
        return builder.getElements().notes
    }

    /// Mix notation fragments, full native note structs, and already-owned native tickables. (VexFlow 5.2.0)
    public func sequence(_ items: [EasyScoreSequenceItem], options: [String: String] = [:]) throws -> [Tickable] {
        try build { score in
            try items.flatMap { item -> [Tickable] in
                switch item {
                case .notation(let text):
                    return try score.notesThrowing(text, options: options)
                case .tickable(let tickable):
                    try score.requireOwned(tickable)
                    if let note = tickable as? Note, Factory.getGroup(note) != nil {
                        throw VexError("BadArguments", "Grouped notes cannot be sequence entries.")
                    }
                    return [tickable]
                case .note(let noteStruct):
                    return [try score.make.note(noteStruct)]
                }
            }
        }
    }

    /// Parse bar-separated measures. Durations carry across bars; `notes()` is unchanged.
    /// A bar may have adjacent commas. Quoted option values may contain literal bars.
    /// Empty measures and invalid notation throw `EasyScoreError`, rather than returning partial music.
    /// Pass `options["duration"]` to set the initial duration. (VexFlow 5.2.0)
    public func measures(_ line: String, options: [String: String] = [:]) throws -> [[StemmableNote]] {
        try VexRuntime.withContext(runtimeContext) {
            let measures = try splitMeasures(line)
            // Validate every measure before constructing any of them. A transaction also covers
            // hook/constructor failures.
            var duration = options["duration"]
            for (index, measure) in measures.enumerated() {
                var measureOptions = options
                measureOptions["duration"] = duration
                let parsed = parseNotation(measure.text, options: measureOptions)
                if !parsed.success {
                    throw EasyScoreError(parsed.diagnostics.map { d in
                        var shifted = diagnostic(line, d.code, d.message, EasyScoreSourceSpan(
                            start: measure.offset + d.start, end: measure.offset + d.end
                        ))
                        shifted.measure = index + 1
                        return shifted
                    })
                }
                duration = parsed.pieces.last?.duration
            }
            let restore = builder.snapshot()
            do {
                return try transaction {
                    duration = options["duration"]
                    var result: [[StemmableNote]] = []
                    for (index, measure) in measures.enumerated() {
                        let previous = self.sourceContext
                        self.sourceContext = (line, measure.offset, index + 1)
                        defer { self.sourceContext = previous }
                        do {
                            var measureOptions = self.notesOptions(options)
                            measureOptions["duration"] = duration
                            let parsed = try self.parseSourced(measure.text, options: measureOptions)
                            if !parsed.success {
                                throw self.builder.commitError
                                    ?? VexError("BadArguments", "Invalid EasyScore measure: \(measure.text)")
                            }
                            duration = self.builder.rollingDurationToken
                            result.append(self.builder.getElements().notes)
                        } catch {
                            let diagnostics = (error as? EasyScoreError)?.diagnostics ?? [
                                diagnostic(measure.text, "ConstructionError", errorMessage(error), EasyScoreSourceSpan(
                                    start: 0, end: measure.text.count
                                )),
                            ]
                            throw EasyScoreError(diagnostics.map { d in
                                var shifted = diagnostic(line, d.code, d.message, EasyScoreSourceSpan(
                                    start: measure.offset + d.start, end: measure.offset + d.end
                                ))
                                shifted.measure = index + 1
                                return shifted
                            })
                        }
                    }
                    return result
                }
            } catch {
                restore()
                throw error
            }
        }
    }

    /// Split only unquoted bars and retain each trimmed measure's original source offset.
    private func splitMeasures(_ line: String) throws -> [(text: String, offset: Int)] {
        let chars = Array(line)
        var parts: [[Character]] = []
        var starts = [0]
        var start = 0
        var quote: Character?
        for (i, char) in chars.enumerated() {
            if let q = quote {
                if char == q { quote = nil }
            } else if char == "\"" || char == "'" {
                quote = char
            } else if char == "|" {
                parts.append(Array(chars[start..<i]))
                start = i + 1
                starts.append(start)
            }
        }
        parts.append(Array(chars[start...]))
        return try parts.enumerated().map { index, part -> (text: String, offset: Int) in
            // Trim whitespace, then a leading comma (after the first bar) and a trailing comma (before the last).
            var lower = 0, upper = part.count
            while lower < upper && part[lower].isWhitespace { lower += 1 }
            while upper > lower && part[upper - 1].isWhitespace { upper -= 1 }
            if index > 0 && lower < upper && part[lower] == "," {
                lower += 1
                while lower < upper && part[lower].isWhitespace { lower += 1 }
            }
            if index < parts.count - 1 && upper > lower && part[upper - 1] == "," {
                upper -= 1
                while upper > lower && part[upper - 1].isWhitespace { upper -= 1 }
            }
            if lower >= upper {
                var empty = diagnostic(line, "EmptyMeasure", "Empty EasyScore measure. Use an explicit rest.",
                                       EasyScoreSourceSpan(start: starts[index], end: starts[index] + part.count))
                empty.measure = index + 1
                throw EasyScoreError([empty])
            }
            return (String(part[lower..<upper]), starts[index] + lower)
        }
    }

    // MARK: - Voices

    /// Create a voice with the given notes.
    public func voice(_ notes: [Note], time: TimeSignatureSpec? = nil) -> Voice {
        do {
            return try voiceThrowing(notes, time: time)
        } catch {
            lastError = error
            return factory.Voice()
        }
    }

    public func voiceThrowing(_ notes: [Note], time: TimeSignatureSpec? = nil) throws -> Voice {
        try voiceThrowing(notes, options: EasyScoreVoiceOptions(time: VoiceTime(timeSignature: time ?? defaults.time)))
    }

    /// Configure time, mode, and spacing before inserting tickables. (VexFlow 5.2.0)
    public func voice(_ notes: [Tickable], options: EasyScoreVoiceOptions) -> Voice {
        do {
            return try voiceThrowing(notes, options: options)
        } catch {
            lastError = error
            return factory.Voice()
        }
    }

    /// Configure time, mode, and spacing before inserting tickables. Overflow throws before the
    /// notes change voice. (VexFlow 5.2.0)
    public func voiceThrowing(_ notes: [Tickable], options: EasyScoreVoiceOptions) throws -> Voice {
        if let factor = options.softmaxFactor, !factor.isFinite || factor <= 0 {
            throw VexError("BadArguments", "softmaxFactor must be positive and finite.")
        }
        if self.options.strictOptions {
            for note in notes { try requireOwned(note) }
        }
        if notes.contains(where: { ($0 as? Note).flatMap(Factory.getGroup) != nil }) {
            throw VexError("BadArguments", "Grouped notes cannot be inserted into a main voice.")
        }
        let time = try options.time ?? VoiceTime(timeSignature: defaults.time)
        try Voice.validate(time)
        return try transaction {
            let voice = self.factory.Voice(time: time)
            _ = voice.setMode(options.mode)
            if let factor = options.softmaxFactor { _ = voice.setSoftmaxFactor(factor) }
            // Check overflow before addTickables() changes the notes' voice assignments.
            let ticks = notes.reduce(Fraction(0, 1)) { total, note in
                note.shouldIgnoreTicks() ? total : total.add(note.getTicks())
            }
            if options.mode != .soft && ticks.greaterThan(voice.getTotalTicks()) {
                throw VexError("BadArguments", "Too many ticks for this voice.")
            }
            return try self.references.add(try voice.addTickablesThrowing(notes))
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
