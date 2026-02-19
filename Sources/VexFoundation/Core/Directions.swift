// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Direction for note stems.
public enum StemDirection: Int, CaseIterable, Sendable, Codable {
    case up = 1
    case down = -1

    public var sign: Int { rawValue }
    public var signDouble: Double { Double(rawValue) }

    public var opposite: StemDirection {
        self == .up ? .down : .up
    }

    /// Parse a stem direction from user input (case-insensitive).
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "up":
            self = .up
        case "down":
            self = .down
        default:
            return nil
        }
    }
}

/// Direction for ties and slurs.
public enum TieDirection: Int, CaseIterable, Sendable, Codable {
    case up = 1
    case down = -1

    public var sign: Int { rawValue }
    public var signDouble: Double { Double(rawValue) }

    public var inverted: TieDirection {
        self == .up ? .down : .up
    }

    public init(stemDirection: StemDirection) {
        self = stemDirection == .up ? .up : .down
    }

    public var stemDirection: StemDirection {
        self == .up ? .up : .down
    }
}
