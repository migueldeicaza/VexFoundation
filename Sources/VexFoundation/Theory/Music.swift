// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Music Types

public struct NoteAccidental: Sendable {
    public var note: Int
    public var accidental: Int

    public init(note: Int, accidental: Int) {
        self.note = note
        self.accidental = accidental
    }
}

public struct NoteParts {
    public var root: String
    public var accidental: String?

    public init(root: String, accidental: String? = nil) {
        self.root = root
        self.accidental = accidental
    }
}

public struct KeyParts {
    public var root: String
    public var accidental: String?
    public var type: String

    public init(root: String, accidental: String? = nil, type: String = "M") {
        self.root = root
        self.accidental = accidental
        self.type = type
    }
}

public struct MusicKey: Sendable {
    public var rootIndex: Int
    public var intVal: Int

    public init(rootIndex: Int, intVal: Int) {
        self.rootIndex = rootIndex
        self.intVal = intVal
    }
}

public enum MusicError: Error, LocalizedError, Sendable {
    case invalidNoteName(String)
    case invalidKey(String)
    case invalidIntervalName(String)
    case invalidNoteValue(Int)
    case invalidIntervalValue(Int)
    case invalidDirection(Int)
    case notesNotRelated(root: String, noteValue: Int)
    case unsupportedKeyType(String)

    public var errorDescription: String? {
        switch self {
        case .invalidNoteName(let note):
            return "Invalid note name: \(note)"
        case .invalidKey(let key):
            return "Invalid key: \(key)"
        case .invalidIntervalName(let interval):
            return "Invalid interval name: \(interval)"
        case .invalidNoteValue(let value):
            return "Invalid note value: \(value)"
        case .invalidIntervalValue(let value):
            return "Invalid interval value: \(value)"
        case .invalidDirection(let direction):
            return "Invalid direction: \(direction)"
        case .notesNotRelated(let root, let noteValue):
            return "Notes not related: \(root), \(noteValue)"
        case .unsupportedKeyType(let key):
            return "Unsupported key type: \(key)"
        }
    }
}

// MARK: - Music

/// Music theory routines: note values, intervals, scales, and key management.
public class Music {

    // MARK: - Static Constants

    public static var NUM_TONES: Int { canonicalNotes.count }

    public static let roots: [String] = ["c", "d", "e", "f", "g", "a", "b"]

    public static let rootValues: [Int] = [0, 2, 4, 5, 7, 9, 11]

    public static let rootIndices: [String: Int] = [
        "c": 0, "d": 1, "e": 2, "f": 3, "g": 4, "a": 5, "b": 6,
    ]

    public static let canonicalNotes: [String] = [
        "c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b",
    ]

    public static let diatonicIntervals: [String] = [
        "unison", "m2", "M2", "m3", "M3", "p4", "dim5", "p5", "m6", "M6", "b7", "M7", "octave",
    ]

    public static let diatonicAccidentals: [String: NoteAccidental] = [
        "unison": NoteAccidental(note: 0, accidental: 0),
        "m2": NoteAccidental(note: 1, accidental: -1),
        "M2": NoteAccidental(note: 1, accidental: 0),
        "m3": NoteAccidental(note: 2, accidental: -1),
        "M3": NoteAccidental(note: 2, accidental: 0),
        "p4": NoteAccidental(note: 3, accidental: 0),
        "dim5": NoteAccidental(note: 4, accidental: -1),
        "p5": NoteAccidental(note: 4, accidental: 0),
        "m6": NoteAccidental(note: 5, accidental: -1),
        "M6": NoteAccidental(note: 5, accidental: 0),
        "b7": NoteAccidental(note: 6, accidental: -1),
        "M7": NoteAccidental(note: 6, accidental: 0),
        "octave": NoteAccidental(note: 7, accidental: 0),
    ]

    public static let intervals: [String: Int] = [
        "u": 0, "unison": 0,
        "m2": 1, "b2": 1, "min2": 1, "S": 1, "H": 1,
        "2": 2, "M2": 2, "maj2": 2, "T": 2, "W": 2,
        "m3": 3, "b3": 3, "min3": 3,
        "M3": 4, "3": 4, "maj3": 4,
        "4": 5, "p4": 5,
        "#4": 6, "b5": 6, "aug4": 6, "dim5": 6,
        "5": 7, "p5": 7,
        "#5": 8, "b6": 8, "aug5": 8,
        "6": 9, "M6": 9, "maj6": 9,
        "b7": 10, "m7": 10, "min7": 10, "dom7": 10,
        "M7": 11, "maj7": 11,
        "8": 12, "octave": 12,
    ]

    public static let scales: [String: [Int]] = [
        "major": [2, 2, 1, 2, 2, 2, 1],
        "minor": [2, 1, 2, 2, 1, 2, 2],
        "ionian": [2, 2, 1, 2, 2, 2, 1],
        "dorian": [2, 1, 2, 2, 2, 1, 2],
        "phyrgian": [1, 2, 2, 2, 1, 2, 2],
        "lydian": [2, 2, 2, 1, 2, 2, 1],
        "mixolydian": [2, 2, 1, 2, 2, 1, 2],
        "aeolian": [2, 1, 2, 2, 1, 2, 2],
        "locrian": [1, 2, 2, 1, 2, 2, 2],
    ]

    public static var scaleTypes: [String: [Int]] {
        [
            "M": scales["major"]!,
            "m": scales["minor"]!,
        ]
    }

    public static let accidentals: [String] = ["bb", "b", "n", "#", "##"]

    public static let noteValues: [String: MusicKey] = [
        "c": MusicKey(rootIndex: 0, intVal: 0),
        "cn": MusicKey(rootIndex: 0, intVal: 0),
        "c#": MusicKey(rootIndex: 0, intVal: 1),
        "c##": MusicKey(rootIndex: 0, intVal: 2),
        "cb": MusicKey(rootIndex: 0, intVal: 11),
        "cbb": MusicKey(rootIndex: 0, intVal: 10),
        "d": MusicKey(rootIndex: 1, intVal: 2),
        "dn": MusicKey(rootIndex: 1, intVal: 2),
        "d#": MusicKey(rootIndex: 1, intVal: 3),
        "d##": MusicKey(rootIndex: 1, intVal: 4),
        "db": MusicKey(rootIndex: 1, intVal: 1),
        "dbb": MusicKey(rootIndex: 1, intVal: 0),
        "e": MusicKey(rootIndex: 2, intVal: 4),
        "en": MusicKey(rootIndex: 2, intVal: 4),
        "e#": MusicKey(rootIndex: 2, intVal: 5),
        "e##": MusicKey(rootIndex: 2, intVal: 6),
        "eb": MusicKey(rootIndex: 2, intVal: 3),
        "ebb": MusicKey(rootIndex: 2, intVal: 2),
        "f": MusicKey(rootIndex: 3, intVal: 5),
        "fn": MusicKey(rootIndex: 3, intVal: 5),
        "f#": MusicKey(rootIndex: 3, intVal: 6),
        "f##": MusicKey(rootIndex: 3, intVal: 7),
        "fb": MusicKey(rootIndex: 3, intVal: 4),
        "fbb": MusicKey(rootIndex: 3, intVal: 3),
        "g": MusicKey(rootIndex: 4, intVal: 7),
        "gn": MusicKey(rootIndex: 4, intVal: 7),
        "g#": MusicKey(rootIndex: 4, intVal: 8),
        "g##": MusicKey(rootIndex: 4, intVal: 9),
        "gb": MusicKey(rootIndex: 4, intVal: 6),
        "gbb": MusicKey(rootIndex: 4, intVal: 5),
        "a": MusicKey(rootIndex: 5, intVal: 9),
        "an": MusicKey(rootIndex: 5, intVal: 9),
        "a#": MusicKey(rootIndex: 5, intVal: 10),
        "a##": MusicKey(rootIndex: 5, intVal: 11),
        "ab": MusicKey(rootIndex: 5, intVal: 8),
        "abb": MusicKey(rootIndex: 5, intVal: 7),
        "b": MusicKey(rootIndex: 6, intVal: 11),
        "bn": MusicKey(rootIndex: 6, intVal: 11),
        "b#": MusicKey(rootIndex: 6, intVal: 0),
        "b##": MusicKey(rootIndex: 6, intVal: 1),
        "bb": MusicKey(rootIndex: 6, intVal: 10),
        "bbb": MusicKey(rootIndex: 6, intVal: 9),
    ]

    // MARK: - Init

    public init() {}

    // MARK: - Validation

    public func isValidNoteValue(_ note: Int) -> Bool {
        note >= 0 && note < Music.canonicalNotes.count
    }

    public func isValidIntervalValue(_ interval: Int) -> Bool {
        interval >= 0 && interval < Music.diatonicIntervals.count
    }

    // MARK: - Note Parts

    public func getNoteParts(_ noteString: String) -> NoteParts {
        guard let parsed = try? noteParts(parsing: noteString) else {
            fatalError("[VexError] BadArguments: Invalid note name: \(noteString)")
        }
        return parsed
    }

    public func noteParts(parsing noteString: String) throws -> NoteParts {
        let note = noteString.lowercased()
        guard note.count >= 1 && note.count <= 3 else {
            throw MusicError.invalidNoteName(noteString)
        }

        let pattern = #"^([cdefgab])(b|bb|n|#|##)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: note, range: NSRange(note.startIndex..., in: note)) else {
            throw MusicError.invalidNoteName(noteString)
        }

        let root = String(note[Range(match.range(at: 1), in: note)!])
        let accidental: String?
        if let accRange = Range(match.range(at: 2), in: note) {
            accidental = String(note[accRange])
        } else {
            accidental = nil
        }

        return NoteParts(root: root, accidental: accidental)
    }

    public func noteParts(parsingOrNil noteString: String) -> NoteParts? {
        try? noteParts(parsing: noteString)
    }

    // MARK: - Key Parts

    public func getKeyParts(_ keyString: String) -> KeyParts {
        guard let parsed = try? keyParts(parsing: keyString) else {
            fatalError("[VexError] BadArguments: Invalid key: \(keyString)")
        }
        return parsed
    }

    public func keyParts(parsing keyString: String) throws -> KeyParts {
        let key = keyString.lowercased()
        guard !key.isEmpty else {
            throw MusicError.invalidKey(keyString)
        }

        let pattern = #"^([cdefgab])(b|#)?(mel|harm|m|M)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) else {
            throw MusicError.invalidKey(keyString)
        }

        let root = String(key[Range(match.range(at: 1), in: key)!])
        let accidental: String?
        if let accRange = Range(match.range(at: 2), in: key) {
            accidental = String(key[accRange])
        } else {
            accidental = nil
        }
        let type: String
        if let typeRange = Range(match.range(at: 3), in: key) {
            type = String(key[typeRange])
        } else {
            type = "M"
        }

        return KeyParts(root: root, accidental: accidental, type: type)
    }

    public func keyParts(parsingOrNil keyString: String) -> KeyParts? {
        try? keyParts(parsing: keyString)
    }

    // MARK: - Note/Interval Values

    public func getNoteValue(_ noteString: String) -> Int {
        guard let parsed = try? noteValue(parsing: noteString) else {
            fatalError("[VexError] BadArguments: Invalid note name: \(noteString)")
        }
        return parsed
    }

    public func noteValue(parsing noteString: String) throws -> Int {
        guard let value = Music.noteValues[noteString.lowercased()] else {
            throw MusicError.invalidNoteName(noteString)
        }
        return value.intVal
    }

    public func noteValue(parsingOrNil noteString: String) -> Int? {
        try? noteValue(parsing: noteString)
    }

    public func getIntervalValue(_ intervalString: String) -> Int {
        guard let parsed = try? intervalValue(parsing: intervalString) else {
            fatalError("[VexError] BadArguments: Invalid interval name: \(intervalString)")
        }
        return parsed
    }

    public func intervalValue(parsing intervalString: String) throws -> Int {
        guard let value = Music.intervals[intervalString] else {
            throw MusicError.invalidIntervalName(intervalString)
        }
        return value
    }

    public func intervalValue(parsingOrNil intervalString: String) -> Int? {
        try? intervalValue(parsing: intervalString)
    }

    // MARK: - Canonical Names

    public func getCanonicalNoteName(_ noteValue: Int) -> String {
        guard isValidNoteValue(noteValue) else {
            fatalError("[VexError] BadArguments: Invalid note value: \(noteValue)")
        }
        return Music.canonicalNotes[noteValue]
    }

    public func getCanonicalIntervalName(_ intervalValue: Int) -> String {
        guard isValidIntervalValue(intervalValue) else {
            fatalError("[VexError] BadArguments: Invalid interval value: \(intervalValue)")
        }
        return Music.diatonicIntervals[intervalValue]
    }

    // MARK: - Relative Notes

    public func getRelativeNoteValue(_ noteValue: Int, intervalValue: Int, direction: Int = 1) -> Int {
        guard direction == 1 || direction == -1 else {
            fatalError("[VexError] BadArguments: Invalid direction: \(direction)")
        }
        var sum = (noteValue + direction * intervalValue) % Music.NUM_TONES
        if sum < 0 { sum += Music.NUM_TONES }
        return sum
    }

    public func getRelativeNoteName(_ root: String, noteValue: Int) -> String {
        guard let parsed = try? relativeNoteName(parsingRoot: root, noteValue: noteValue) else {
            fatalError("[VexError] BadArguments: Notes not related: \(root), \(noteValue))")
        }
        return parsed
    }

    public func relativeNoteName(parsingRoot root: String, noteValue: Int) throws -> String {
        let parts = try noteParts(parsing: root)
        let rootValue = try self.noteValue(parsing: parts.root)
        var interval = noteValue - rootValue

        if abs(interval) > Music.NUM_TONES - 3 {
            var multiplier = 1
            if interval > 0 { multiplier = -1 }
            let reverseInterval = ((noteValue + 1 + (rootValue + 1)) % Music.NUM_TONES) * multiplier
            if abs(reverseInterval) > 2 {
                throw MusicError.notesNotRelated(root: root, noteValue: noteValue)
            } else {
                interval = reverseInterval
            }
        }

        if abs(interval) > 2 {
            throw MusicError.notesNotRelated(root: root, noteValue: noteValue)
        }

        var relativeNoteName = parts.root
        if interval > 0 {
            for _ in 1...interval {
                relativeNoteName += "#"
            }
        } else if interval < 0 {
            for _ in interval..<0 {
                relativeNoteName += "b"
            }
        }

        return relativeNoteName
    }

    public func relativeNoteName(parsingRootOrNil root: String, noteValue: Int) -> String? {
        try? relativeNoteName(parsingRoot: root, noteValue: noteValue)
    }

    // MARK: - Scale Tones

    public func getScaleTones(_ key: Int, intervals: [Int]) -> [Int] {
        var tones = [key]
        var nextNote = key
        for i in 0..<intervals.count {
            nextNote = getRelativeNoteValue(nextNote, intervalValue: intervals[i])
            if nextNote != key { tones.append(nextNote) }
        }
        return tones
    }

    // MARK: - Interval Between Notes

    public func getIntervalBetween(_ note1: Int, _ note2: Int, direction: Int = 1) -> Int {
        guard direction == 1 || direction == -1 else {
            fatalError("[VexError] BadArguments: Invalid direction: \(direction)")
        }
        guard isValidNoteValue(note1) && isValidNoteValue(note2) else {
            fatalError("[VexError] BadArguments: Invalid notes: \(note1), \(note2)")
        }
        var difference = direction == 1 ? note2 - note1 : note1 - note2
        if difference < 0 { difference += Music.NUM_TONES }
        return difference
    }

    // MARK: - Scale Map

    public func createScaleMap(_ keySignature: String) -> [String: String] {
        guard let parsed = try? createScaleMap(parsing: keySignature) else {
            fatalError("[VexError] BadArguments: Unsupported key type: \(keySignature)")
        }
        return parsed
    }

    public func createScaleMap(parsing keySignature: String) throws -> [String: String] {
        let keySigParts = try keyParts(parsing: keySignature)
        guard let scaleName = Music.scaleTypes[keySigParts.type] else {
            throw MusicError.unsupportedKeyType(keySignature)
        }

        var keySigString = keySigParts.root
        if let acc = keySigParts.accidental { keySigString += acc }

        let scale = getScaleTones(try noteValue(parsing: keySigString), intervals: scaleName)
        guard let noteLocation = Music.rootIndices[keySigParts.root] else {
            throw MusicError.invalidKey(keySignature)
        }

        var scaleMap: [String: String] = [:]
        for i in 0..<Music.roots.count {
            let index = (noteLocation + i) % Music.roots.count
            let rootName = Music.roots[index]
            var noteName = try relativeNoteName(parsingRoot: rootName, noteValue: scale[i])
            if noteName.count == 1 {
                noteName += "n"
            }
            scaleMap[rootName] = noteName
        }

        return scaleMap
    }

    public func createScaleMap(parsingOrNil keySignature: String) -> [String: String]? {
        try? createScaleMap(parsing: keySignature)
    }
}
