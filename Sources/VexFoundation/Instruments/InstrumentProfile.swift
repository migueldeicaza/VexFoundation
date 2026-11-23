// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/instrumentprofile.ts` (VexFlow 5.4.0).
// Instrument mappings resolve named musical events into ordinary VF5 note descriptions.

import Foundation

/// A written position uses VexFlow note lines (1 = bottom line, 5 = top on a five-line staff).
public struct PercussionInstrument: Equatable, Sendable {
    public enum Head: String, Sendable {
        case normal
        case cross
        case circleCross = "circle-cross"
        case triangle
    }

    public enum Stem: String, Sendable {
        case up, down
    }

    public var id: String
    public var label: String
    public var line: Double
    public var head: Head?
    public var stem: Stem

    public init(id: String, label: String, line: Double, head: Head? = nil, stem: Stem) {
        self.id = id
        self.label = label
        self.line = line
        self.head = head
        self.stem = stem
    }
}

/// A custom kit and its legend share the same named entries. No playback pitches are inferred.
public final class PercussionMap {
    public static let kit: [PercussionInstrument] = [
        PercussionInstrument(id: "kick", label: "Bass drum", line: 1.5, stem: .down),
        PercussionInstrument(id: "snare", label: "Snare drum", line: 3.5, stem: .up),
        PercussionInstrument(id: "hat", label: "Closed hi-hat", line: 5.5, head: .cross, stem: .up),
    ]
    public let instruments: [PercussionInstrument]

    public init(_ entries: [PercussionInstrument] = PercussionMap.kit) throws {
        if Set(entries.map(\.id)).count != entries.count {
            throw VexError("BadArguments", "Duplicate percussion ID.")
        }
        for entry in entries {
            let doubled = entry.line * 2
            if entry.id.isEmpty || entry.label.isEmpty || !doubled.isFinite || doubled.rounded() != doubled
                || abs(doubled) > 9_007_199_254_740_991 {
                throw VexError("BadArguments", "Invalid percussion entry.")
            }
        }
        instruments = entries
    }

    /// The first instrument supplies the default stem. Callers can override it for another voice.
    public func note(_ ids: [String], duration: String, stem: PercussionInstrument.Stem? = nil) throws -> StaveNoteStruct {
        if ids.isEmpty { throw VexError("BadArguments", "A percussion attack needs an instrument.") }
        let entries = try ids.map { id -> PercussionInstrument in
            guard let entry = instruments.first(where: { $0.id == id }) else {
                throw VexError("BadArguments", "Unknown percussion instrument: " + id)
            }
            return entry
        }
        let letters = Array("cdefgab")
        let keys = entries.map { entry -> String in
            let step = Int(28 + 2 * entry.line)
            let octave = step >= 0 ? step / 7 : -((-step + 6) / 7)
            let key = String(letters[((step % 7) + 7) % 7]) + "/" + String(octave)
            let shape: String
            switch entry.head {
            case .cross: shape = "X"
            case .circleCross: shape = "CX"
            case .triangle: shape = "TU"
            default: shape = ""
            }
            return shape.isEmpty ? key : key + "/" + shape
        }
        var result = try StaveNoteStruct(
            parsingKeys: keys,
            duration: duration,
            stemDirection: (stem ?? entries[0].stem) == .up ? .up : .down,
            clef: .percussion
        )
        result.notation = entries.enumerated().map { index, entry in
            NotationIdentity(kind: .unpitched, id: entry.id, label: entry.label, index: index)
        }
        return result
    }
}

/// One played string: a fret, or a dead (muted) strike with a written display pitch.
public enum FrettedPosition: Equatable, Sendable {
    case fret(str: Int, fret: Int)
    case dead(str: Int, displayKey: String)

    public var str: Int {
        switch self {
        case .fret(let str, _), .dead(let str, _): return str
        }
    }
}

/// Standard and tablature descriptions of the same attack.
public struct FrettedAttack {
    public var note: StaveNoteStruct
    public var tab: TabNoteStruct
}

/// One stroke of an expanded rasgueado. `offset` is an exact whole-note fraction from its start.
public struct RasgueadoAttack {
    public var offset: Fraction
    public var note: StaveNoteStruct
    public var tab: TabNoteStruct
}

/// Paired notation uses written open-string pitches and fret numbers relative to the capo.
public final class FrettedInstrument {
    private let tuning: Tuning
    public let capo: Int

    public init(_ tuning: String = "standard", capo: Int = 0) throws {
        if capo < 0 { throw VexError("BadArguments", "Invalid capo fret.") }
        self.capo = capo
        self.tuning = try Tuning(validating: tuning)
    }

    /// Expand an ordered rasgueado into ordinary paired attacks. Offsets are exact whole-note fractions
    /// from its start.
    public func rasgueado(
        _ positions: [FrettedPosition],
        _ strokes: [(stroke: GuitarStroke, duration: String)]
    ) throws -> [RasgueadoAttack] {
        if strokes.isEmpty { throw VexError("BadArguments", "A rasgueado needs at least one stroke.") }
        let clock = Fraction(0, 1)
        return try strokes.map { stroke, duration in
            let event = try attack(positions, duration: duration)
            let mark = strokeIdentity(stroke)
            let offset = clock.clone().simplify()
            _ = clock.add(try Tables.durationToTicksThrowing(duration), Tables.RESOLUTION)
            var note = event.note
            var tab = event.tab
            note.notation = event.note.notation + [mark]
            tab.notation = note.notation
            return RasgueadoAttack(offset: offset, note: note, tab: tab)
        }
    }

    /// Attach a bend envelope to one played string. Both views retain its semantics and TAB draws the contour.
    public func bentAttack(_ positions: [FrettedPosition], duration: String, _ spec: TimedStringBend) throws -> FrettedAttack {
        let event = try attack(positions, duration: duration)
        let bend = try copyBend(spec)
        guard let index = positions.firstIndex(where: { $0.str == bend.string }) else {
            throw VexError("BadArguments", "The bent string must occur in the chord.")
        }
        let label = "String \(bend.string), bend " + formatJSNumber(bend.semitones)
            + (bend.semitones == 1 ? " semitone by " : " semitones by ")
            + "\(bend.rise.0)/\(bend.rise.1)"
            + (bend.hold.map { ", hold to \($0.0)/\($0.1)" } ?? "")
            + (bend.release.map { ", release to pitch by \($0.0)/\($0.1)" } ?? "")
        let mark = NotationIdentity(kind: .technique, id: "string-bend", label: label, bend: bend, index: index)
        var note = event.note
        var tab = event.tab
        note.notation = event.note.notation + [mark]
        tab.notation = note.notation
        return FrettedAttack(note: note, tab: tab)
    }

    /// Build independent standard and tab descriptions for the same attack.
    public func attack(_ positions: [FrettedPosition], duration: String) throws -> FrettedAttack {
        if positions.isEmpty || Set(positions.map(\.str)).count != positions.count {
            throw VexError("BadArguments", "A fretted attack needs distinct strings.")
        }
        let keys = try positions.map { position -> String in
            switch position {
            case .dead(let str, let displayKey):
                _ = try tuning.getValueForStringThrowing(str)
                if displayKey.range(of: "^[a-g][bn#]*/[0-9]+$", options: [.regularExpression, .caseInsensitive]) == nil {
                    throw VexError("BadArguments", "A dead string needs a written display pitch.")
                }
                return displayKey + "/X"
            case .fret(let str, let fret):
                if fret < 0 { throw VexError("BadArguments", "Invalid string or fret.") }
                return try tuning.getNoteForFretThrowing(fret, stringNum: str, capo: capo)
            }
        }
        let notation = positions.enumerated().map { index, position -> NotationIdentity in
            switch position {
            case .dead(let str, _):
                return NotationIdentity(
                    kind: .unpitched, id: "string-\(str)", label: "Muted strike on string \(str)", index: index
                )
            case .fret(let str, let fret):
                return NotationIdentity(
                    kind: .tuning, id: "string-\(str)", label: "String \(str), fret \(fret), capo \(capo)", index: index
                )
            }
        }
        var note = try StaveNoteStruct(parsingKeys: keys, duration: duration)
        note.notation = notation
        var tab = try TabNoteStruct(
            positions: positions.map { position in
                switch position {
                case .dead(let str, _): return TabNotePosition(str: str, fret: "X")
                case .fret(let str, let fret): return TabNotePosition(str: str, fret: fret)
                }
            },
            duration: duration
        )
        tab.notation = notation
        return FrettedAttack(note: note, tab: tab)
    }
}
