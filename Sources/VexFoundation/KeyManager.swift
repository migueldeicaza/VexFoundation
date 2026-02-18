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

// MARK: - KeyManager

/// Manages diatonic keys, resolving accidentals for notes in a given key.
public class KeyManager {

    // MARK: - Properties

    public let music = Music()
    public var key: String
    public var keyParts: KeyParts!
    public var keyString: String = ""
    public var scale: [Int] = []
    public var scaleMap: [String: String] = [:]
    public var scaleMapByValue: [Int: String] = [:]
    public var originalScaleMapByValue: [Int: String] = [:]

    // MARK: - Init

    public init(_ key: String) {
        self.key = key
        reset()
    }

    // MARK: - Methods

    @discardableResult
    public func setKey(_ key: String) -> Self {
        self.key = key
        reset()
        return self
    }

    public func getKey() -> String { key }

    @discardableResult
    public func reset() -> Self {
        keyParts = music.getKeyParts(key)

        keyString = keyParts.root
        if let acc = keyParts.accidental { keyString += acc }

        guard let scaleType = Music.scaleTypes[keyParts.type] else {
            fatalError("[VexError] BadArguments: Unsupported key type: \(key)")
        }

        scale = music.getScaleTones(music.getNoteValue(keyString), intervals: scaleType)

        scaleMap = [:]
        scaleMapByValue = [:]
        originalScaleMapByValue = [:]

        let noteLocation = Music.rootIndices[keyParts.root]!

        for i in 0..<Music.roots.count {
            let index = (noteLocation + i) % Music.roots.count
            let rootName = Music.roots[index]
            let noteName = music.getRelativeNoteName(rootName, noteValue: scale[i])
            scaleMap[rootName] = noteName
            scaleMapByValue[scale[i]] = noteName
            originalScaleMapByValue[scale[i]] = noteName
        }

        return self
    }

    public func getAccidental(_ key: String) -> KeyManagerResult {
        let root = music.getKeyParts(key).root
        let parts = music.getNoteParts(scaleMap[root]!)

        return KeyManagerResult(
            note: scaleMap[root]!,
            accidental: parts.accidental
        )
    }

    public func selectNote(_ note: String) -> KeyManagerResult {
        let noteLower = note.lowercased()
        let parts = music.getNoteParts(noteLower)

        let scaleNote = scaleMap[parts.root]!
        let modparts = music.getNoteParts(scaleNote)

        if scaleNote == noteLower {
            return KeyManagerResult(
                note: scaleNote,
                accidental: parts.accidental,
                change: false
            )
        }

        if let valueNote = scaleMapByValue[music.getNoteValue(noteLower)] {
            return KeyManagerResult(
                note: valueNote,
                accidental: music.getNoteParts(valueNote).accidental,
                change: false
            )
        }

        if let originalValueNote = originalScaleMapByValue[music.getNoteValue(noteLower)] {
            scaleMap[modparts.root] = originalValueNote
            scaleMapByValue.removeValue(forKey: music.getNoteValue(scaleNote))
            scaleMapByValue[music.getNoteValue(noteLower)] = originalValueNote
            return KeyManagerResult(
                note: originalValueNote,
                accidental: music.getNoteParts(originalValueNote).accidental,
                change: true
            )
        }

        if modparts.root == noteLower {
            scaleMapByValue.removeValue(forKey: music.getNoteValue(scaleMap[parts.root]!))
            scaleMapByValue[music.getNoteValue(modparts.root)] = modparts.root
            scaleMap[modparts.root] = modparts.root
            return KeyManagerResult(
                note: modparts.root,
                accidental: nil,
                change: true
            )
        }

        // Last resort
        scaleMapByValue.removeValue(forKey: music.getNoteValue(scaleMap[parts.root]!))
        scaleMapByValue[music.getNoteValue(noteLower)] = noteLower

        scaleMap[modparts.root] = noteLower

        return KeyManagerResult(
            note: noteLower,
            accidental: parts.accidental,
            change: true
        )
    }
}
