// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/publicationcue.ts` (VexFlow 5.8.0).
// Spell the pitches and signatures of a quoted source measure in a receiving part's written key.

import Foundation

/// Chromatic distance and letter-name displacement from the source to the receiving part. (VexFlow 5.8.0)
public struct CueTransposition: Sendable, Equatable {
    public var semitones: Int
    public var steps: Int

    public init(semitones: Int, steps: Int) {
        self.semitones = semitones
        self.steps = steps
    }
}

/// Transpose a written pitch while preserving its optional native notehead code.
private func pitch(_ key: String, _ interval: CueTransposition) throws -> String {
    let parts = key.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    let name = parts[0], octave = parts.count > 1 ? parts[1] : ""
    let written = try NotationSpelling.transpose(name + "/" + octave, semitones: interval.semitones, steps: interval.steps)
    return parts.count > 2 ? written + "/" + parts[2] : written
}

/// Keep the ordinary parser, duration inheritance and commit hooks for EasyScore strings. (VexFlow 5.8.0)
public final class CueBuilder: Builder {
    private let interval: CueTransposition

    public init(factory: Factory, interval: CueTransposition) {
        self.interval = interval
        super.init(factory: factory)
    }

    /// Transpose each pitch of the piece before the ordinary commit. Rests and ghost notes stay literal.
    /// A transposition error stops the parse, as the upstream exception does.
    override public func commitPiece(source: EasyScoreSourceSpan?) {
        if !["r", "g"].contains(piece.typeToken?.lowercased() ?? ""), commitError == nil {
            do {
                for (index, member) in piece.chord.enumerated() {
                    // The default octave is that of the ordinary builder.
                    let written = try pitch(member.key + (member.accid ?? "") + "/" + (member.octave ?? "4"), interval)
                    let parts = written.split(separator: "/").map(String.init)
                    let name = parts[0]
                    piece.chord[index].key = String(name.prefix(1))
                    piece.chord[index].accid = name.count > 1 ? String(name.dropFirst()) : nil
                    piece.chord[index].octave = parts[1]
                }
            } catch {
                commitError = error
            }
        }
        super.commitPiece(source: source)
    }
}

/// Transpose typed pitches, keeping the notehead code. Rests are copied literally.
private func writtenKeys(
    _ keys: NonEmptyArray<StaffKeySpec>, _ interval: CueTransposition
) throws -> NonEmptyArray<StaffKeySpec> {
    let written = try keys.map { try StaffKeySpec(parsing: try pitch($0.rawValue, interval)) }
    guard let result = NonEmptyArray(validating: written) else { return keys }
    return result
}

private func isRest(_ type: NoteType?, _ duration: NoteDurationSpec) -> Bool {
    type == .rest || duration.type == .rest
}

private func writtenNote(_ source: StaveNoteStruct, _ interval: CueTransposition) throws -> StaveNoteStruct {
    if isRest(source.type, source.duration) { return source }
    var note = source
    note.keys = try writtenKeys(source.keys, interval)
    if note.rawKeys != nil { note.rawKeys = note.keys.map { $0.rawValue } }
    return note
}

private func writtenGrace(_ source: GraceNoteStruct, _ interval: CueTransposition) throws -> GraceNoteStruct {
    if isRest(source.type, source.duration) { return source }
    var note = source
    note.keys = try writtenKeys(source.keys, interval)
    return note
}

/// Rebuild typed pitched events and key changes. Rest positions and durations are copied literally.
/// (VexFlow 5.8.0)
func writtenCue(_ staff: EasyScoreStaveSpec, _ interval: CueTransposition) throws -> EasyScoreStaveSpec {
    func signature(_ key: String) throws -> String {
        try NotationSpelling.transposeKey(key, semitones: interval.semitones, steps: interval.steps)
    }
    func event(_ item: EasyScoreContent) throws -> EasyScoreContent {
        switch item {
        case .notation:
            return item // CueBuilder handles each parsed pitch.
        case .tickable, .tab:
            throw invalidPage("A written cue transposes declarative pitched staff notes.")
        case .change(var change):
            if let key = change.key { change.key = try signature(key) }
            return .change(change)
        case .note(let note, let id, let stave, let grace):
            guard var grace else { return .note(try writtenNote(note, interval), id: id, stave: stave, grace: nil) }
            grace.notes = try grace.notes.map { source in
                var written = EasyScoreGracePitchSpec(try writtenGrace(source.note, interval), accidentals: source.accidentals)
                written.accidentals = try source.accidentals.map { mark in
                    guard mark.index >= 0 && mark.index < source.note.keys.count else {
                        throw invalidPage("Missing grace head for a cue accidental.")
                    }
                    let key = source.note.keys[mark.index]
                    let letter = String(key.rawValue.prefix(1))
                    let transposed = try pitch(letter + mark.type + "/" + String(key.octave), interval)
                    let name = transposed.split(separator: "/")[0]
                    var result = mark
                    result.type = name.count > 1 ? String(name.dropFirst()) : "n"
                    return result
                }
                return written
            }
            return .note(try writtenNote(note, interval), id: id, stave: stave, grace: grace)
        }
    }
    var result = staff
    result.key = try signature(staff.key ?? "C")
    result.measures = try staff.measures.map { measure in
        var written = measure
        written.key = try measure.key.map(signature)
        written.chords = try measure.chords.map { chord in
            guard let harmony = chord.harmony else { return chord }
            var mark = chord
            mark.harmony = try NotationSpelling.transposeChord(harmony, semitones: interval.semitones, steps: interval.steps)
            return mark
        }
        written.voices = try measure.voices.map { voice in
            var v = voice
            v.notes = try voice.notes.map(event)
            return v
        }
        return written
    }
    return result
}
