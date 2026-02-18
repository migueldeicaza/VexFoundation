// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

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

    public var tuningValues: [Int] = []

    // MARK: - Init

    public init(_ tuningString: String = "E/5,B/4,G/4,D/4,A/3,E/3,B/2,E/2") {
        setTuning(tuningString)
    }

    // MARK: - Methods

    public func noteToInteger(_ noteString: String) -> Int {
        (try? Tables.keyProperties(noteString).intValue) ?? -1
    }

    public func setTuning(_ tuningString: String) {
        var resolved = tuningString
        if let named = Tuning.names[tuningString] {
            resolved = named
        }

        tuningValues = []

        let keys = resolved.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !keys.isEmpty else {
            fatalError("[VexError] BadArguments: Invalid tuning string: \(tuningString)")
        }

        for key in keys {
            tuningValues.append(noteToInteger(key))
        }
    }

    public func getValueForString(_ stringNum: Int) -> Int {
        guard stringNum >= 1 && stringNum <= tuningValues.count else {
            fatalError("[VexError] BadArguments: String number must be between 1 and \(tuningValues.count): \(stringNum)")
        }
        return tuningValues[stringNum - 1]
    }

    public func getValueForFret(_ fretNum: Int, stringNum: Int) -> Int {
        let stringValue = getValueForString(stringNum)
        guard fretNum >= 0 else {
            fatalError("[VexError] BadArguments: Fret number must be 0 or higher: \(fretNum)")
        }
        return stringValue + fretNum
    }

    public func getNoteForFret(_ fretNum: Int, stringNum: Int) -> String {
        let noteValue = getValueForFret(fretNum, stringNum: stringNum)
        let octave = noteValue / 12
        let value = noteValue % 12
        return "\(Tables.integerToNote(value))/\(octave)"
    }
}
