// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Canonical set of supported clef names.
public enum ClefName: String, CaseIterable, Sendable, Codable {
    case treble
    case bass
    case alto
    case tenor
    case percussion
    case soprano
    case mezzoSoprano = "mezzo-soprano"
    case baritoneC = "baritone-c"
    case baritoneF = "baritone-f"
    case subbass
    case french
    case tab

    /// Parse a clef name from user input (case-insensitive).
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.init(rawValue: normalized)
    }
}
