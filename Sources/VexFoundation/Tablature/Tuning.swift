// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

public enum TuningError: Error, LocalizedError, Equatable, Sendable {
    case invalidTuningString(String)
    case invalidTuningNote(String)
    case invalidStringNumber(requested: Int, available: Int)
    case invalidFretNumber(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidTuningString(let tuning):
            return "Invalid tuning string: \(tuning)"
        case .invalidTuningNote(let note):
            return "Invalid tuning note: \(note)"
        case .invalidStringNumber(let requested, let available):
            return "String number must be between 1 and \(available): \(requested)"
        case .invalidFretNumber(let fret):
            return "Fret number must be 0 or higher: \(fret)"
        }
    }
}

// MARK: - Tuning

/// Implements various types of tunings for tablature.
public class Tuning {

    // MARK: - Named Tunings

    public static let names: [String: String] = [
        "standard": "E/5,B/4,G/4,D/4,A/3,E/3",
        "dagdad": "D/5,A/4,G/4,D/4,A/3,D/3",
        "dropd": "E/5,B/4,G/4,D/4,A/3,D/3",
        "eb": "Eb/5,Bb/4,Gb/4,Db/4,Ab/3,Db/3",
        "standardBanjo": "D/5,B/4,G/4,D/4,G/5",
        "doubleCBanjo": "D/5,C/5,G/4,C/4,G/5",
        "doubleDBanjo": "E/5,D/5,A/4,D/4,A/5",
        "sawmillBanjo": "D/5,C/5,G/4,D/4,G/5",
    ]

    // MARK: - Properties

    public static let defaultTuning = "E/5,B/4,G/4,D/4,A/3,E/3,B/2,E/2"
    public var tuningValues: [Int] = []
    public private(set) var initError: TuningError?

    // MARK: - Init

    public init(_ tuningString: String = defaultTuning) {
        setTuning(tuningString)
    }

    public convenience init(validating tuningString: String = defaultTuning) throws {
        self.init(tuningString)
        if let initError {
            throw initError
        }
    }

    public convenience init?(parsingOrNil tuningString: String = defaultTuning) {
        guard (try? Tuning(validating: tuningString)) != nil else { return nil }
        self.init(tuningString)
    }

    // MARK: - Methods

    public func noteToIntegerThrowing(_ noteString: String) throws -> Int {
        guard
            let keyProps = try? Tables.keyProperties(noteString),
            let intValue = keyProps.intValue
        else {
            throw TuningError.invalidTuningNote(noteString)
        }
        return intValue
    }

    public func noteToInteger(_ noteString: String) -> Int? {
        try? noteToIntegerThrowing(noteString)
    }

    @discardableResult
    public func setTuningThrowing(_ tuningString: String) throws -> Self {
        let resolved = Tuning.names[tuningString] ?? tuningString
        let keys = resolved
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !keys.isEmpty else {
            throw TuningError.invalidTuningString(tuningString)
        }

        var parsedValues: [Int] = []
        parsedValues.reserveCapacity(keys.count)
        for key in keys {
            parsedValues.append(try noteToIntegerThrowing(key))
        }

        tuningValues = parsedValues
        initError = nil
        return self
    }

    public func setTuning(_ tuningString: String) {
        do {
            _ = try setTuningThrowing(tuningString)
        } catch let error as TuningError {
            initError = error
            tuningValues = []
        } catch {
            initError = .invalidTuningString(tuningString)
            tuningValues = []
        }
    }

    @discardableResult
    public func setTuningOrNil(_ tuningString: String) -> Self? {
        try? setTuningThrowing(tuningString)
    }

    public func getValueForStringThrowing(_ stringNum: Int) throws -> Int {
        guard stringNum >= 1 && stringNum <= tuningValues.count else {
            throw TuningError.invalidStringNumber(requested: stringNum, available: tuningValues.count)
        }
        return tuningValues[stringNum - 1]
    }

    public func getValueForString(_ stringNum: Int) -> Int {
        (try? getValueForStringThrowing(stringNum)) ?? -1
    }

    public func getValueForStringOrNil(_ stringNum: Int) -> Int? {
        try? getValueForStringThrowing(stringNum)
    }

    public func getValueForFretThrowing(_ fretNum: Int, stringNum: Int) throws -> Int {
        let stringValue = try getValueForStringThrowing(stringNum)
        guard fretNum >= 0 else {
            throw TuningError.invalidFretNumber(fretNum)
        }
        return stringValue + fretNum
    }

    public func getValueForFret(_ fretNum: Int, stringNum: Int) -> Int {
        (try? getValueForFretThrowing(fretNum, stringNum: stringNum)) ?? -1
    }

    public func getValueForFretOrNil(_ fretNum: Int, stringNum: Int) -> Int? {
        try? getValueForFretThrowing(fretNum, stringNum: stringNum)
    }

    public func getNoteForFretThrowing(_ fretNum: Int, stringNum: Int) throws -> String {
        let noteValue = try getValueForFretThrowing(fretNum, stringNum: stringNum)
        let octave = noteValue / 12
        let value = ((noteValue % 12) + 12) % 12
        let note = try Tables.integerToNoteThrowing(value)
        return "\(note)/\(octave)"
    }

    public func getNoteForFret(_ fretNum: Int, stringNum: Int) -> String {
        (try? getNoteForFretThrowing(fretNum, stringNum: stringNum)) ?? ""
    }

    public func getNoteForFretOrNil(_ fretNum: Int, stringNum: Int) -> String? {
        try? getNoteForFretThrowing(fretNum, stringNum: stringNum)
    }
}
