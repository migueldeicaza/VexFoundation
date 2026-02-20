// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Key Manager Result

public struct KeyManagerResult {
    public var note: String
    public var accidental: String?
    public var change: Bool

    public init(note: String, accidental: String? = nil, change: Bool = false) {
        self.note = note
        self.accidental = accidental
        self.change = change
    }
}

public enum KeyManagerError: Error, LocalizedError, Sendable {
    case unsupportedKeyType(String)
    case invalidKey(String)
    case invalidNote(String)
    case internalInvariant(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedKeyType(let key):
            return "Unsupported key type: \(key)"
        case .invalidKey(let key):
            return "Invalid key: \(key)"
        case .invalidNote(let note):
            return "Invalid note: \(note)"
        case .internalInvariant(let message):
            return "KeyManager invariant failed: \(message)"
        }
    }
}

// MARK: - KeyManager

/// Manages diatonic keys, resolving accidentals for notes in a given key.
public class KeyManager {

    // MARK: - Properties

    public let music: Music
    public private(set) var key: String
    public private(set) var keyParts: KeyParts
    public var keyString: String = ""
    public var scale: [Int] = []
    public var scaleMap: [String: String] = [:]
    public var scaleMapByValue: [Int: String] = [:]
    public var originalScaleMapByValue: [Int: String] = [:]

    // MARK: - Init

    public init(parsing key: String, music: Music = Music()) throws {
        self.music = music
        self.key = key
        self.keyParts = KeyParts(root: "c", accidental: nil, type: "M")
        try reset()
    }

    /// Failable string convenience initializer.
    public convenience init?(parsingOrNil key: String, music: Music = Music()) {
        try? self.init(parsing: key, music: music)
    }

    /// Backward-compatible failable convenience initializer.
    public convenience init?(_ key: String) {
        self.init(parsingOrNil: key)
    }

    // MARK: - Methods

    @discardableResult
    public func setKey(parsing key: String) throws -> Self {
        self.key = key
        try reset()
        return self
    }

    @discardableResult
    public func setKey(parsingOrNil key: String) -> Self? {
        try? setKey(parsing: key)
    }

    /// Backward-compatible failable convenience setter.
    @discardableResult
    public func setKey(_ key: String) -> Self? {
        setKey(parsingOrNil: key)
    }

    public func getKey() -> String { key }

    @discardableResult
    public func reset() throws -> Self {
        keyParts = try music.keyParts(parsing: key)

        keyString = keyParts.root
        if let acc = keyParts.accidental { keyString += acc }

        guard let scaleType = Music.scaleTypes[keyParts.type] else {
            throw KeyManagerError.unsupportedKeyType(key)
        }

        scale = music.getScaleTones(try music.noteValue(parsing: keyString), intervals: scaleType)

        scaleMap = [:]
        scaleMapByValue = [:]
        originalScaleMapByValue = [:]

        guard let noteLocation = Music.rootIndices[keyParts.root] else {
            throw KeyManagerError.invalidKey(key)
        }

        for i in 0..<Music.roots.count {
            let index = (noteLocation + i) % Music.roots.count
            let rootName = Music.roots[index]
            let noteName = try music.relativeNoteName(parsingRoot: rootName, noteValue: scale[i])
            scaleMap[rootName] = noteName
            scaleMapByValue[scale[i]] = noteName
            originalScaleMapByValue[scale[i]] = noteName
        }

        return self
    }

    public func getAccidental(parsing key: String) throws -> KeyManagerResult {
        let root = try music.keyParts(parsing: key).root
        guard let mapped = scaleMap[root] else {
            throw KeyManagerError.internalInvariant("Missing mapped scale note for root '\(root)'")
        }
        let parts = try music.noteParts(parsing: mapped)

        return KeyManagerResult(
            note: mapped,
            accidental: parts.accidental
        )
    }

    public func getAccidental(parsingOrNil key: String) -> KeyManagerResult? {
        try? getAccidental(parsing: key)
    }

    /// Backward-compatible failable convenience API.
    public func getAccidental(_ key: String) -> KeyManagerResult? {
        getAccidental(parsingOrNil: key)
    }

    public func selectNote(parsing note: String) throws -> KeyManagerResult {
        let noteLower = note.lowercased()
        let parts = try music.noteParts(parsing: noteLower)

        guard let scaleNote = scaleMap[parts.root] else {
            throw KeyManagerError.internalInvariant("Missing mapped scale note for root '\(parts.root)'")
        }
        let modparts = try music.noteParts(parsing: scaleNote)
        let noteValue = try music.noteValue(parsing: noteLower)

        if scaleNote == noteLower {
            return KeyManagerResult(
                note: scaleNote,
                accidental: parts.accidental,
                change: false
            )
        }

        if let valueNote = scaleMapByValue[noteValue] {
            return KeyManagerResult(
                note: valueNote,
                accidental: try music.noteParts(parsing: valueNote).accidental,
                change: false
            )
        }

        if let originalValueNote = originalScaleMapByValue[noteValue] {
            scaleMap[modparts.root] = originalValueNote
            scaleMapByValue.removeValue(forKey: try music.noteValue(parsing: scaleNote))
            scaleMapByValue[noteValue] = originalValueNote
            return KeyManagerResult(
                note: originalValueNote,
                accidental: try music.noteParts(parsing: originalValueNote).accidental,
                change: true
            )
        }

        if modparts.root == noteLower {
            guard let priorMapped = scaleMap[parts.root] else {
                throw KeyManagerError.internalInvariant("Missing prior mapped note for root '\(parts.root)'")
            }
            scaleMapByValue.removeValue(forKey: try music.noteValue(parsing: priorMapped))
            scaleMapByValue[try music.noteValue(parsing: modparts.root)] = modparts.root
            scaleMap[modparts.root] = modparts.root
            return KeyManagerResult(
                note: modparts.root,
                accidental: nil,
                change: true
            )
        }

        // Last resort
        guard let priorMapped = scaleMap[parts.root] else {
            throw KeyManagerError.internalInvariant("Missing prior mapped note for root '\(parts.root)'")
        }
        scaleMapByValue.removeValue(forKey: try music.noteValue(parsing: priorMapped))
        scaleMapByValue[noteValue] = noteLower

        scaleMap[modparts.root] = noteLower

        return KeyManagerResult(
            note: noteLower,
            accidental: parts.accidental,
            change: true
        )
    }

    public func selectNote(parsingOrNil note: String) -> KeyManagerResult? {
        try? selectNote(parsing: note)
    }

    /// Backward-compatible failable convenience API.
    public func selectNote(_ note: String) -> KeyManagerResult? {
        selectNote(parsingOrNil: note)
    }
}
