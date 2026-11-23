// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tuning.ts` (VexFlow 5.0.0).

import Foundation

public enum TuningError: Error, LocalizedError, Equatable, Sendable {
    case invalidTuningString(String)
    case invalidTuningNote(String)
    case invalidStringNumber(requested: Int, available: Int)
    case invalidFretNumber(Int)
    /// A nut list whose length differs from the strings, or a negative nut fret. (VexFlow 5.9.0)
    case invalidNutFrets([Int])
    /// A negative capo. (VexFlow 5.9.0)
    case invalidCapo(Int)
    /// A stopped fret below a short string's nut. (VexFlow 5.9.0)
    case fretBelowNut(fret: Int, nut: Int)

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
        case .invalidNutFrets:
            return "Expected a nonnegative integer nut fret for each string."
        case .invalidCapo:
            return "Expected a nonnegative fret and capo."
        case .fretBelowNut(let fret, let nut):
            return "Fret \(fret) is below the nut at fret \(nut)."
        }
    }
}

// MARK: - Tuning

/// Maps physical frets to written pitches using each string's open pitch and nut position.
/// Strings are ordered by their one-based TAB numbers, starting with string 1.
public class Tuning {

    // MARK: - Named Tunings

    public static let names: [String: String] = [
        "standard": "E/5,B/4,G/4,D/4,A/3,E/3",
        "dagdad": "D/5,A/4,G/4,D/4,A/3,D/3",
        "dropd": "E/5,B/4,G/4,D/4,A/3,D/3",
        "eb": "Eb/5,Bb/4,Gb/4,Db/4,Ab/3,Eb/3",
        "standardBanjo": "D/5,B/4,G/4,D/4,G/5",
        // 4.x branch (3c5209d0), not in upstream 5.x.
        "doubleCBanjo": "D/5,C/5,G/4,C/4,G/5",
        "doubleDBanjo": "E/5,D/5,A/4,D/4,A/5",
        "sawmillBanjo": "D/5,C/5,G/4,D/4,G/5",
    ]

    // MARK: - Properties

    public static let defaultTuning = "E/5,B/4,G/4,D/4,A/3,E/3,B/2,E/2"
    public var tuningValues: [Int] = []
    /// The nut fret of each string; empty for full-length strings. (VexFlow 5.9.0)
    public private(set) var nutFrets: [Int] = []
    public private(set) var initError: TuningError?

    // MARK: - Init

    public init(_ tuningString: String = defaultTuning) {
        setTuning(tuningString)
    }

    /// Use a preset or comma-separated written pitches with a nut fret for each string. (VexFlow 5.9.0)
    public init(_ tuningString: String, nutFrets: [Int]?) {
        setTuning(tuningString, nutFrets: nutFrets)
    }

    public convenience init(validating tuningString: String = defaultTuning, nutFrets: [Int]? = nil) throws {
        self.init(tuningString, nutFrets: nutFrets)
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

    /// Replace pitches and nut positions together. A custom tuning defaults to full-length strings.
    /// `standardBanjo` defaults to a short fifth string with its nut at fret 5. (VexFlow 5.9.0)
    @discardableResult
    public func setTuningThrowing(_ tuningString: String, nutFrets: [Int]? = nil) throws -> Self {
        var nutFrets = nutFrets
        if tuningString == "standardBanjo" && nutFrets == nil { nutFrets = [0, 0, 0, 0, 5] }
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
        if let nutFrets, nutFrets.count != parsedValues.count || nutFrets.contains(where: { $0 < 0 }) {
            throw TuningError.invalidNutFrets(nutFrets)
        }

        tuningValues = parsedValues
        self.nutFrets = nutFrets ?? []
        initError = nil
        return self
    }

    public func setTuning(_ tuningString: String, nutFrets: [Int]? = nil) {
        do {
            _ = try setTuningThrowing(tuningString, nutFrets: nutFrets)
        } catch let error as TuningError {
            initError = error
            tuningValues = []
            self.nutFrets = []
        } catch {
            initError = .invalidTuningString(tuningString)
            tuningValues = []
            self.nutFrets = []
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

    /// A displayed zero rings the open string. Numbered frets are measured from the capo or the neck origin.
    /// A capo below a short string's nut leaves its open pitch unchanged. (VexFlow 5.9.0)
    public func getValueForFretThrowing(_ fretNum: Int, stringNum: Int, capo: Int = 0) throws -> Int {
        let stringValue = try getValueForStringThrowing(stringNum)
        let nut = stringNum - 1 < nutFrets.count ? nutFrets[stringNum - 1] : 0
        guard fretNum >= 0 else {
            throw TuningError.invalidFretNumber(fretNum)
        }
        guard capo >= 0 else {
            throw TuningError.invalidCapo(capo)
        }
        let physical = fretNum == 0 ? max(nut, capo) : capo + fretNum
        if physical < nut {
            throw TuningError.fretBelowNut(fret: physical, nut: nut)
        }
        return stringValue + physical - nut
    }

    public func getValueForFret(_ fretNum: Int, stringNum: Int, capo: Int = 0) -> Int {
        (try? getValueForFretThrowing(fretNum, stringNum: stringNum, capo: capo)) ?? -1
    }

    public func getValueForFretOrNil(_ fretNum: Int, stringNum: Int, capo: Int = 0) -> Int? {
        try? getValueForFretThrowing(fretNum, stringNum: stringNum, capo: capo)
    }

    /// Return the written note for a displayed fret and an optional capo.
    public func getNoteForFretThrowing(_ fretNum: Int, stringNum: Int, capo: Int = 0) throws -> String {
        let noteValue = try getValueForFretThrowing(fretNum, stringNum: stringNum, capo: capo)
        let octave = noteValue / 12
        let value = ((noteValue % 12) + 12) % 12
        let note = try Tables.integerToNoteThrowing(value)
        return "\(note)/\(octave)"
    }

    public func getNoteForFret(_ fretNum: Int, stringNum: Int, capo: Int = 0) -> String {
        (try? getNoteForFretThrowing(fretNum, stringNum: stringNum, capo: capo)) ?? ""
    }

    public func getNoteForFretOrNil(_ fretNum: Int, stringNum: Int, capo: Int = 0) -> String? {
        try? getNoteForFretThrowing(fretNum, stringNum: stringNum, capo: capo)
    }
}
