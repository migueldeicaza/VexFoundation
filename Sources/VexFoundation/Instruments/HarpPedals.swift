// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/harppedals.ts`, `src/harppedaldiagram.ts` and `src/harppedalchanges.ts` (VexFlow 5.9.0).
// Concert harp pedal settings, a note-anchored pedal diagram, and change instructions.

import Foundation

/// One of the seven pedal letters on a concert harp. `allCases` is the pedal order under the
/// player's left foot (D, C, B), then right foot (E, F, G, A) (upstream `HARP_PEDAL_ORDER`). (VexFlow 5.9.0)
public enum HarpPedalName: String, CaseIterable, Sendable {
    case d = "D"
    case c = "C"
    case b = "B"
    case e = "E"
    case f = "F"
    case g = "G"
    case a = "A"
}

/// Pitch alteration selected by a pedal's three notches. (VexFlow 5.9.0)
public enum HarpPedalPosition: String, Sendable {
    case flat
    case natural
    case sharp
}

/// A complete setting uses each of the seven named pedals exactly once. (VexFlow 5.9.0)
public struct HarpPedalSettings: Equatable, Sendable {
    private var positions: [HarpPedalName: HarpPedalPosition]

    /// Upstream `validateHarpPedals`: every pedal needs a position.
    public init(_ positions: [HarpPedalName: HarpPedalPosition]) throws {
        for name in HarpPedalName.allCases where positions[name] == nil {
            throw VexError("RangeError", "Harp pedal \(name.rawValue) must be flat, natural, or sharp.")
        }
        self.positions = positions
    }

    /// Read settings written with upstream pedal letters and position names, for example `["D": "natural"]`.
    public init(parsing raw: [String: String]) throws {
        var positions: [HarpPedalName: HarpPedalPosition] = [:]
        for name in HarpPedalName.allCases {
            guard let position = raw[name.rawValue].flatMap(HarpPedalPosition.init(rawValue:)) else {
                throw VexError("RangeError", "Harp pedal \(name.rawValue) must be flat, natural, or sharp.")
            }
            positions[name] = position
        }
        if raw.count != HarpPedalName.allCases.count { throw VexError("RangeError", "Unknown harp pedal name.") }
        self.positions = positions
    }

    /// The position of one pedal.
    public subscript(name: HarpPedalName) -> HarpPedalPosition {
        positions[name] ?? .natural
    }

    /// Return a copy with the named pedals moved. Omitted pedals keep their positions.
    public func merging(_ changes: [HarpPedalName: HarpPedalPosition]) -> HarpPedalSettings {
        var copy = self
        copy.positions.merge(changes) { _, new in new }
        return copy
    }
}

/// Each SMuFL pedal glyph carries both its tick and one segment of the horizontal rail.
private func harpPedalGlyph(_ position: HarpPedalPosition) -> String {
    switch position {
    case .flat: return Glyphs.harpPedalRaised
    case .natural: return Glyphs.harpPedalCentered
    case .sharp: return Glyphs.harpPedalLowered
    }
}

/// A complete seven-pedal diagram centered on its note, using ordinary annotation placement and spacing.
/// (VexFlow 5.9.0)
public final class HarpPedalDiagram: Annotation {
    /// Validated positions in effect at the diagram's score location.
    public let settings: HarpPedalSettings

    /// Throws when `scale` is not positive and finite.
    public init(_ settings: HarpPedalSettings, scale: Double = 1) throws {
        guard scale.isFinite, scale > 0 else {
            throw VexError("RangeError", "Expected a positive harp diagram scale.")
        }
        var glyphs = HarpPedalName.allCases.map { harpPedalGlyph(settings[$0]) }
        glyphs.insert(Glyphs.harpPedalDivider, at: 3)
        self.settings = settings
        super.init(glyphs.joined())
        setFont(Metrics.getFontInfo("HarpPedalDiagram"))
        setFontSize(fontSizeInPoints * scale)
        addClass("harp-pedal-diagram")
    }

    /// Resolve ink against the current note position, even before the first draw or after reformatting.
    /// `nil` before the diagram is attached to a formatted note (upstream throws).
    override public func getBoundingBox() -> BoundingBox? {
        guard let x = try? computeX().x, let y = try? computeY().y else { return nil }
        return getTextInk(x, y)
    }
}

/// Printed accidental for each pedal notch, including an explicit natural when cancelling a change.
private func harpAccidental(_ position: HarpPedalPosition) -> String {
    switch position {
    case .flat: return "\u{266D}"
    case .natural: return "\u{266E}"
    case .sharp: return "\u{266F}"
    }
}

/// Track the seven pedals of one harp part in score order. (VexFlow 5.9.0)
public final class HarpPedalChanges {
    private var settings: HarpPedalSettings

    /// Set the starting positions without adding a mark to the score.
    public init(_ initial: HarpPedalSettings) {
        settings = initial
    }

    /// Return the setting after the last instruction.
    public func getSettings() -> HarpPedalSettings {
        settings
    }

    /// Attach a centered instruction below the note. Omitted pedals keep their positions.
    /// Return `nil` when no pedal changes.
    @discardableResult
    public func apply(_ note: Note, _ target: [HarpPedalName: HarpPedalPosition]) -> Annotation? {
        let next = settings.merging(target)
        let changes = HarpPedalName.allCases.filter { next[$0] != settings[$0] }
        if changes.isEmpty { return nil }

        // An en space keeps adjacent pitch names separated equally in SVG and Canvas.
        let text = changes.map { $0.rawValue + harpAccidental(next[$0]) }.joined(separator: "\u{2002}")
        let label = Annotation(text).setVerticalJustification(.bottom)
        _ = note.addModifier(label)
        settings = next
        return label
    }
}
