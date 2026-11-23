// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/guitargesture.ts` (VexFlow 5.7.0).
// Guitar performance data and its written signs on paired notation and tablature.

import Foundation

/// One right-hand action. Direction follows the physical order of strings for either arrow convention.
public struct GuitarStroke: Equatable, Sendable {
    public enum Finger: String, Sendable, CaseIterable {
        case p, i, m, a, e
    }

    public enum Direction: String, Sendable, CaseIterable {
        case bassToTreble = "bass-to-treble"
        case trebleToBass = "treble-to-bass"
    }

    public enum Arrows: String, Sendable, CaseIterable {
        case strings, hand
    }

    public var finger: Finger
    public var direction: Direction
    public var golpe: Bool?
    /// One freely rolled chord occupies its written value. Individual finger attacks are unspecified.
    public var roll: Bool?
    public var arrows: Arrows?

    public init(finger: Finger, direction: Direction, golpe: Bool? = nil, roll: Bool? = nil, arrows: Arrows? = nil) {
        self.finger = finger
        self.direction = direction
        self.golpe = golpe
        self.roll = roll
        self.arrows = arrows
    }
}

/// An exact fraction of an attack's duration, `(numerator, denominator)`.
public typealias GesturePhase = (Int, Int)

/// Endpoints are exact fractions of this attack's duration, measured from its onset.
public struct TimedStringBend: Sendable {
    public var string: Int
    public var semitones: Double
    public var rise: GesturePhase
    public var hold: GesturePhase?
    public var release: GesturePhase?
    /// Optional written amount, e.g. "½". Defaults to full, ½ or an explicit semitone count.
    public var label: String?

    public init(
        string: Int,
        semitones: Double,
        rise: GesturePhase,
        hold: GesturePhase? = nil,
        release: GesturePhase? = nil,
        label: String? = nil
    ) {
        self.string = string
        self.semitones = semitones
        self.rise = rise
        self.hold = hold
        self.release = release
        self.label = label
    }
}

extension TimedStringBend: Equatable {
    public static func == (a: TimedStringBend, b: TimedStringBend) -> Bool {
        a.string == b.string && a.semitones == b.semitones && a.rise == b.rise
            && a.hold.map { [$0.0, $0.1] } == b.hold.map { [$0.0, $0.1] }
            && a.release.map { [$0.0, $0.1] } == b.release.map { [$0.0, $0.1] }
            && a.label == b.label
    }
}

/// A string tie carries the target between two adjacent events. Rise belongs to the first event, and
/// hold and release are measured from the start of the tied continuation. (VexFlow 5.7.0)
public struct TiedBend: Sendable {
    public var semitones: Double
    public var rise: GesturePhase
    public var hold: GesturePhase
    public var release: GesturePhase
    public var label: String?

    public init(semitones: Double, rise: GesturePhase, hold: GesturePhase, release: GesturePhase, label: String? = nil) {
        self.semitones = semitones
        self.rise = rise
        self.hold = hold
        self.release = release
        self.label = label
    }
}

extension TiedBend: Equatable {
    public static func == (a: TiedBend, b: TiedBend) -> Bool {
        a.semitones == b.semitones && a.rise == b.rise && a.hold == b.hold && a.release == b.release
            && a.label == b.label
    }
}

/// Normalize the written amount independently of the bend's horizontal length.
public func bendAmount(_ bend: TimedStringBend) -> String {
    bendAmount(semitones: bend.semitones, label: bend.label)
}

/// Normalize the written amount of a tied bend. (VexFlow 5.7.0)
public func bendAmount(_ bend: TiedBend) -> String {
    bendAmount(semitones: bend.semitones, label: bend.label)
}

private func bendAmount(semitones: Double, label: String?) -> String {
    if let label { return label }
    if semitones == 2 { return "full" }
    if semitones == 1 { return "½" }
    return formatJSNumber(semitones) + " st"
}

/// `a.0 / a.1 <= b.0 / b.1` for positive denominators, without overflow (upstream `BigInt`).
private func phaseAtMost(_ a: GesturePhase, _ b: GesturePhase) -> Bool {
    let lhs = a.0.multipliedFullWidth(by: b.1)
    let rhs = b.0.multipliedFullWidth(by: a.1)
    return lhs.high < rhs.high || (lhs.high == rhs.high && lhs.low <= rhs.low)
}

/// Validate increasing fractions within one written event.
private func checkPhases(_ ends: [GesturePhase]) throws {
    var previous: GesturePhase = (0, 1)
    for end in ends {
        if end.1 <= 0 || end.0 <= 0 || end.0 > end.1 || phaseAtMost(end, previous) {
            throw VexError("BadArguments", "Bend endpoints must increase within the written duration.")
        }
        previous = end
    }
}

/// Check the clocks of the initial attack and tied continuation independently. (VexFlow 5.7.0)
public func copyTiedBend(_ bend: TiedBend) throws -> TiedBend {
    if !bend.semitones.isFinite || bend.semitones <= 0 {
        throw VexError("BadArguments", "A tied bend needs a positive semitone amount.")
    }
    try checkPhases([bend.rise])
    try checkPhases([bend.hold, bend.release])
    return bend
}

/// Validate the performed order before constructing a modifier or changing a note.
public func copyBend(_ bend: TimedStringBend) throws -> TimedStringBend {
    if bend.string < 1 || !bend.semitones.isFinite || bend.semitones <= 0 {
        throw VexError("BadArguments", "A timed bend needs a string and positive semitone amount.")
    }
    var ends = [bend.rise]
    if let hold = bend.hold { ends.append(hold) }
    if let release = bend.release { ends.append(release) }
    try checkPhases(ends)
    return bend
}

/// Preserve the action as structured score metadata as well as a spoken description.
/// The typed `GuitarStroke` cannot hold the invalid values that upstream rejects.
public func strokeIdentity(_ action: GuitarStroke) -> NotationIdentity {
    var label = [
        action.roll == true ? "Rolled rasgueado" : "Rasgueado",
        action.finger.rawValue,
        action.direction.rawValue.replacingOccurrences(of: "-", with: " "),
    ]
    if action.golpe == true { label.append("simultaneous golpe") }
    return NotationIdentity(kind: .technique, id: "rasgueado", label: label.joined(separator: ", "), stroke: action)
}
