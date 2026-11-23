// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/notationspelling.ts` (VexFlow 5.7.0).
// Written pitch, chord and rhythm spelling for constructing a score or transposed part.

import Foundation

/// A chord's transposable pitches and its literal quality, extensions and alterations. (VexFlow 5.7.0)
public struct ChordHarmony: Equatable, Sendable {
    public var root: String
    public var quality: String?
    public var bass: String?

    public init(root: String, quality: String? = nil, bass: String? = nil) {
        self.root = root
        self.quality = quality
        self.bass = bass
    }
}

private let chordPitchPattern = try? NSRegularExpression(pattern: "^[A-Ga-g](?:#{1,2}|b{1,2}|\u{266F}{1,2}|\u{266D}{1,2})?$")

/// Read an octave-free pitch name. Keep the letter so enharmonic roots transpose differently.
private func chordPitch(_ name: String) throws -> String {
    let range = NSRange(name.startIndex..., in: name)
    guard let first = name.first, chordPitchPattern?.firstMatch(in: name, range: range) != nil else {
        throw VexError("BadArguments", "Expected a chord pitch such as G, Bb or C#.")
    }
    let rest = name.dropFirst().replacingOccurrences(of: "\u{266F}", with: "#").replacingOccurrences(of: "\u{266D}", with: "b")
    return first.uppercased() + rest
}

/// One printable segment. `tieNext` joins a pitched continuation across a requested boundary.
public struct RhythmSegment: Equatable, Sendable {
    public var start: Int
    public var duration: String
    public var dots: Int
    public var tieNext: Bool

    public init(start: Int, duration: String, dots: Int, tieNext: Bool) {
        self.start = start
        self.duration = duration
        self.dots = dots
        self.tieNext = tieNext
    }
}

/// JavaScript `Math.floor(a / b)` for a positive divisor.
private func floorDiv(_ a: Int, _ b: Int) -> Int {
    let q = a / b
    return (a % b != 0 && a < 0) ? q - 1 : q
}

private let writtenPitch = try? NSRegularExpression(pattern: "^([a-g])(bb|##|b|#|n)?/(-?\\d+)$", options: [.caseInsensitive])

public enum NotationSpelling {
    /// Transpose by both chromatic semitones and diatonic steps, e.g. +2/+1 for B-flat clarinet.
    public static func transpose(_ key: String, semitones: Int, steps: Int) throws -> String {
        let range = NSRange(key.startIndex..., in: key)
        guard let match = writtenPitch?.firstMatch(in: key, range: range),
              let letterRange = Range(match.range(at: 1), in: key),
              let octaveRange = Range(match.range(at: 3), in: key),
              let octave = Int(key[octaveRange]) else {
            throw VexError("BadArguments", "Expected a written pitch and integer transposition.")
        }
        let accidental = Range(match.range(at: 2), in: key).map { key[$0].lowercased() }
        let letters = Array("cdefgab")
        let naturals = [0, 2, 4, 5, 7, 9, 11]
        guard let index = letters.firstIndex(of: Character(key[letterRange].lowercased())) else {
            throw VexError("BadArguments", "Expected a written pitch and integer transposition.")
        }
        let target = octave * 7 + index + steps
        let letter = ((target % 7) + 7) % 7
        let targetOctave = floorDiv(target, 7)
        let signs = ["bb", "b", "", "#", "##"]
        let alteration = accidental.flatMap { $0 == "n" ? nil : signs.firstIndex(of: $0).map { $0 - 2 } } ?? 0
        let delta = octave * 12 + naturals[index] + alteration + semitones - (targetOctave * 12 + naturals[letter])
        if abs(delta) > 2 {
            throw VexError("BadArguments", "Spelling requires more than a double accidental.")
        }
        return String(letters[letter]) + signs[delta + 2] + "/" + String(targetOctave)
    }

    /// Return a new harmony. Only its root and optional slash bass participate in pitch spelling. (VexFlow 5.7.0)
    public static func transposeChord(_ harmony: ChordHarmony, semitones: Int, steps: Int) throws -> ChordHarmony {
        func pitch(_ name: String) throws -> String {
            // A reference octave lets the pitch helper account for crossings such as B to C-sharp.
            let written = try transpose(try chordPitch(name) + "/4", semitones: semitones, steps: steps)
                .split(separator: "/")[0]
            return written.prefix(1).uppercased() + written.dropFirst()
        }
        var result = harmony
        result.root = try pitch(harmony.root)
        if let bass = harmony.bass { result.bass = try pitch(bass) }
        return result
    }

    /// Print the spelled pitches with musical accidentals and copy the chord suffix verbatim. (VexFlow 5.7.0)
    public static func chordText(_ harmony: ChordHarmony) throws -> String {
        func print(_ name: String) throws -> String {
            try chordPitch(name).replacingOccurrences(of: "#", with: "\u{266F}").replacingOccurrences(of: "b", with: "\u{266D}")
        }
        let bass = try harmony.bass.map { "/" + (try print($0)) } ?? ""
        return try print(harmony.root) + (harmony.quality ?? "") + bass
    }

    /// Preserve the mode while spelling the transposed tonic. Reject unavailable standard signatures.
    public static func transposeKey(_ key: String, semitones: Int, steps: Int) throws -> String {
        _ = try Tables.keySignature(key)
        let minor = key.hasSuffix("m")
        let tonic = minor ? String(key.dropLast()) : key
        let transposed = try transpose(tonic + "/4", semitones: semitones, steps: steps)
        let pitch = transposed.split(separator: "/").first.map(String.init) ?? ""
        let result = pitch.prefix(1).uppercased() + pitch.dropFirst() + (minor ? "m" : "")
        _ = try Tables.keySignature(result)
        return result
    }

    /// Spell on a 1/64-note grid. Cuts are absolute barlines or group boundaries supplied by the caller.
    public static func rhythm(_ start: Int, _ length: Int, cuts: [Int] = [], rest: Bool = false) throws -> [RhythmSegment] {
        let (end, overflow) = start.addingReportingOverflow(length)
        if overflow || start < 0 || length <= 0 {
            throw VexError("BadArguments", "Expected integer positions in 64th notes and a positive length.")
        }
        let stops = Array(Set(cuts.filter { $0 > start && $0 < end })).sorted()
        var segments: [RhythmSegment] = []
        var position = start
        for stop in stops + [end] {
            while position < stop {
                let remaining = stop - position
                var unit = 64
                while unit > remaining { unit /= 2 }
                let dotted = unit >= 2 && unit * 3 / 2 <= remaining
                let next = position + (dotted ? unit * 3 / 2 : unit)
                segments.append(RhythmSegment(
                    start: position,
                    duration: String(64 / unit),
                    dots: dotted ? 1 : 0,
                    tieNext: !rest && next < end
                ))
                position = next
            }
        }
        return segments
    }
}

/// Accidental memory for a single staff and bar. A signature maps a letter to a written sign in every octave.
public final class WrittenAccidentalState {
    private var seen: [String: String] = [:]
    private let signature: [String: String]

    public init(signature: [String: String] = [:]) {
        self.signature = signature
    }

    /// Start a new bar in the same signature. Construct a new state on a signature change.
    public func reset() {
        seen.removeAll()
    }

    /// Return the sign to print. Cautionaries print on request even when the sign is already in force.
    public func sign(_ key: String, _ sign: String, cautionary: Bool = false) throws -> String? {
        let pitch = key.lowercased()
        let valid = pitch.range(of: "^[a-g]/-?[0-9]+$", options: .regularExpression) != nil
        if !valid || sign.isEmpty {
            throw VexError("BadArguments", "Expected a staff pitch and a written accidental.")
        }
        let letter = String(pitch.prefix(1))
        let previous = seen[pitch] ?? signature[letter] ?? "n"
        seen[pitch] = sign
        return cautionary || sign != previous ? sign : nil
    }
}
