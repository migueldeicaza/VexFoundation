// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Cyril Silverman
//
// Port of `src/keysignature.ts` (VexFlow 5.9.0).
//
// This file implements key signatures. A key signature sits on a stave
// and indicates the notes with implicit accidentals.

import Foundation

/// An accidental of a key signature: the accidental type and the stave line.
public typealias KeySignatureAccidental = (type: String, line: Double)

/// A custom sign is anchored to a written pitch or to an explicit half-line measured from the top.
/// (VexFlow 5.9.0)
public struct OrderedKeySign: Sendable, Equatable {
    public enum Placement: Sendable, Equatable {
        /// A written pitch such as `g/4`, placed against the active clef during formatting.
        case pitch(String)
        /// A stave line from the top line down, already in the target clef. Must be a line or a space.
        case line(Double)
    }

    public var type: String
    public var placement: Placement

    public init(type: String, placement: Placement) {
        self.type = type
        self.placement = placement
    }

    /// A sign at a written pitch (upstream `{ type, pitch }`).
    public init(type: String, pitch: String) {
        self.init(type: type, placement: .pitch(pitch))
    }

    /// A sign at an explicit stave line (upstream `{ type, line }`).
    public init(type: String, line: Double) {
        self.init(type: type, placement: .line(line))
    }

    public var pitch: String? {
        if case .pitch(let pitch) = placement { return pitch }
        return nil
    }

    public var line: Double? {
        if case .line(let line) = placement { return line }
        return nil
    }
}

/// `true` for a written natural pitch with an integer octave, such as `g/4` or `c/-1`
/// (upstream `/^[a-g]\/-?\d+$/i` and a safe-integer octave).
func isWrittenNaturalPitch(_ pitch: String) -> Bool {
    let parts = pitch.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 2, parts[0].count == 1,
          let letter = parts[0].lowercased().first, ("a"..."g").contains(letter) else { return false }
    var octave = Substring(parts[1])
    if octave.hasPrefix("-") { octave = octave.dropFirst() }
    guard !octave.isEmpty, octave.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
    guard let value = Double(parts[1]), abs(value) <= 9_007_199_254_740_991 else { return false }
    return true
}

/// Snapshot a definition before it becomes part of a reusable preset or a score.
private func copyOrderedSigns(_ entries: [OrderedKeySign]) throws -> [OrderedKeySign] {
    for entry in entries {
        let placed: Bool
        switch entry.placement {
        case .pitch(let pitch):
            placed = isWrittenNaturalPitch(pitch)
        case .line(let line):
            let doubled = line * 2
            placed = doubled.isFinite && doubled.rounded() == doubled && abs(doubled) <= 9_007_199_254_740_991
        }
        if entry.type.isEmpty || !placed {
            throw VexError("BadArguments", "Expected an accidental with a written pitch or a staff line or space.")
        }
    }
    return entries
}

/// An edition's named written signatures. Each selection creates an independent stave modifier.
/// (VexFlow 5.9.0)
public final class KeySignaturePresets {
    private var definitions: [String: [OrderedKeySign]] = [:]

    public init() {}

    /// Register or replace an edition's definition. Existing selections keep their own signs.
    @discardableResult
    public func register(_ name: String, _ entries: [OrderedKeySign]) throws -> Self {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw VexError("BadKeySignature", "Expected a named key signature preset.")
        }
        definitions[name] = try copyOrderedSigns(entries)
        return self
    }

    /// Select a signature by its exact name within this edition.
    public func select(_ name: String) throws -> KeySignature {
        guard let signs = definitions[name] else {
            throw VexError("BadKeySignature", "Unknown key signature preset: '\(name)'.")
        }
        return try KeySignature(keySpec: "C").setOrdered(signs)
    }
}

/// Renders key signatures (sharps/flats) on a stave.
public final class KeySignature: StaveModifier {

    override public class var category: String { "KeySignature" }

    // MARK: - Properties

    public var paddingForced: Bool = false
    public var formatted: Bool = false
    /// Clef that replaces the stave clef for an inline signature after an inline clef change. (VexFlow 5.2.0)
    public private(set) var clefOverride: ClefName?
    public var cancelKeySpec: String?
    public var accList: [KeySignatureAccidental] = []
    public var keySpec: String?
    public var alterKeySpec: [String]?
    /// Custom signs in the author's order. (VexFlow 5.4.0; written pitches 5.9.0)
    private var ordered: [OrderedKeySign]?
    private var formattedStaveY: Double?
    private var formattedClef: ClefName?

    // MARK: - Init

    /// Create a new Key Signature based on a `keySpec`.
    public init(keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil) {
        super.init()

        setKeySig(keySpec, cancelKeySpec: cancelKeySpec, alterKeySpec: alterKeySpec)
        setPosition(.begin)
        children = []
        paddingForced = false
    }

    // MARK: - Glyphs

    /// Add an accidental glyph to the `KeySignature` instance which represents
    /// the provided `acc`. If `nextAcc` is also provided, the appropriate
    /// spacing will be included in the glyph's position.
    func convertToGlyph(_ acc: KeySignatureAccidental, _ nextAcc: KeySignatureAccidental?, _ stave: Stave) {
        let code = Tables.accidentalCodes(acc.type)
        let glyph = VexElement(category: KeySignature.category)
        glyph.setFont(fontInfo).setText(code)

        // Determine spacing between current accidental and the next accidental
        var extraWidth: Double = 1
        // Place the glyph on the stave
        glyph.setYShift(stave.getYForLine(acc.line))
        if let prevGlyph = children.last {
            let isNatural: (VexElement) -> Bool = { $0.getText() == Glyphs.accidentalNatural }
            let yShiftDiff: (VexElement, VexElement) -> Double = { abs($1.getYShift() - $0.getYShift()) }

            if (isNatural(prevGlyph) || isNatural(glyph)) && yShiftDiff(prevGlyph, glyph) < 10 {
                extraWidth = 2
            }
            glyph.setXShift(prevGlyph.getXShift() + prevGlyph.getWidth() + extraWidth)
        }
        children.append(glyph)

        // Expand size of key signature
        width += glyph.getWidth() + extraWidth
    }

    /// Use explicit accidentals and staff lines instead of a key spec. A line must be a whole
    /// line or space. (VexFlow 5.4.0)
    @discardableResult
    public func setOrdered(_ entries: [KeySignatureAccidental]) throws -> Self {
        try setOrdered(entries.map { OrderedKeySign(type: $0.type, line: $0.line) })
    }

    /// Preserve the author's sign order. Resolve pitches against the active clef during formatting.
    /// (VexFlow 5.9.0)
    @discardableResult
    public func setOrdered(_ entries: [OrderedKeySign]) throws -> Self {
        ordered = try copyOrderedSigns(entries)
        formatted = false
        return self
    }

    /// Cancel out a key signature provided in the `spec` parameter. This will
    /// place appropriate natural accidentals before the key signature.
    @discardableResult
    public func cancelKey(_ spec: String) -> Self {
        formatted = false
        cancelKeySpec = spec
        return self
    }

    /// Convert the `cancelKeySpec` into a list of naturals to be displayed.
    func convertToCancelAccList(_ spec: String) -> (type: String, accList: [KeySignatureAccidental])? {
        // Get the accidental list for the cancelled key signature
        let cancelAccList = (try? Tables.keySignature(spec)) ?? []

        // If the cancelled key has a different accidental type, ie: # vs b
        let differentTypes = !accList.isEmpty && !cancelAccList.isEmpty && cancelAccList[0].type != accList[0].type

        // Determine how many naturals needed to add
        let naturals = differentTypes ? cancelAccList.count : cancelAccList.count - accList.count

        // Return if no naturals needed
        if naturals < 1 { return nil }

        // Get the line position for each natural
        var cancelled: [KeySignatureAccidental] = []
        for i in 0..<naturals {
            var index = i
            if !differentTypes {
                index = cancelAccList.count - naturals + i
            }

            let acc = cancelAccList[index]
            cancelled.append((type: "n", line: acc.line))
        }

        // Combine naturals with main accidental list for the key signature
        accList = cancelled + accList

        return (type: cancelAccList[0].type, accList: cancelled)
    }

    /// Add this key signature to the start of a stave.
    @discardableResult
    public func addToStave(_ stave: Stave) -> Self {
        paddingForced = true
        stave.addModifier(self)
        return self
    }

    /// Add this key signature to a stave.
    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        formatted = false
        return super.setStave(stave)
    }

    /// Get the `BoundingBox`.
    override public func getBoundingBox() -> BoundingBox? {
        ensureFormatted()
        return super.getBoundingBox()
    }

    /// Calculate the width and height for the entire signature.
    func calculateDimensions() {
        var boundingBox: BoundingBox
        if let first = children.first, let bb = first.getBoundingBox() {
            boundingBox = bb
        } else {
            boundingBox = BoundingBox(x: x + xShift, y: y + yShift, w: 0, h: 0)
        }
        for glyph in children {
            if let bb = glyph.getBoundingBox() {
                boundingBox.mergeWith(bb)
            }
        }
        width = boundingBox.getW()
        height = boundingBox.getH()
        y = boundingBox.getY()
    }

    /// Apply the accidental staff line placement based on the `clef` and
    /// the accidental `type` for the key signature ('#' or 'b').
    func convertAccLines(_ clef: ClefName, _ type: String?, _ accList: inout [KeySignatureAccidental]) {
        var offset: Double = 0.0 // if clef === "treble"
        var customLines: [Double]? // when clef doesn't follow treble key sig shape

        switch clef {
        // Treble & Subbass both have offsets of 0, so are not included.
        case .soprano:
            if type == "#" { customLines = [2.5, 0.5, 2, 0, 1.5, -0.5, 1] } else { offset = -1 }
        case .mezzoSoprano:
            if type == "b" { customLines = [0, 2, 0.5, 2.5, 1, 3, 1.5] } else { offset = 1.5 }
        case .alto:
            offset = 0.5
        case .tenor:
            if type == "#" { customLines = [3, 1, 2.5, 0.5, 2, 0, 1.5] } else { offset = -0.5 }
        case .baritoneF, .baritoneC:
            if type == "b" { customLines = [0.5, 2.5, 1, 3, 1.5, 3.5, 2] } else { offset = 2 }
        case .bass, .french:
            offset = 1
        default:
            break
        }

        // If there's a special case, assign those lines/spaces:
        if let customLines {
            for i in 0..<accList.count where i < customLines.count {
                accList[i].line = customLines[i]
            }
        } else if offset != 0 {
            for i in 0..<accList.count {
                accList[i].line += offset
            }
        }
    }

    /// Get the padding required for this modifier.
    override public func getPadding(_ index: Int) -> Double {
        ensureFormatted()
        return children.isEmpty || (!paddingForced && index < 2) ? 0 : padding
    }

    /// Get the width of the modifier.
    override public func getWidth() -> Double {
        ensureFormatted()
        return width
    }

    /// Override the stave clef for an inline signature following an inline clef change. (VexFlow 5.2.0)
    @discardableResult
    public func setClef(_ clef: ClefName?) -> Self {
        clefOverride = clef
        formatted = false
        return self
    }

    /// Set the key signature to a specific key, ie: 'C' or 'Gm'.
    @discardableResult
    public func setKeySig(_ keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil) -> Self {
        formatted = false
        ordered = nil
        self.keySpec = keySpec
        self.cancelKeySpec = cancelKeySpec
        self.alterKeySpec = alterKeySpec
        return self
    }

    /// Alter the accidentals of a key spec one by one.
    /// Each alteration is a new accidental that replaces the
    /// original accidental (or the canceled one).
    @discardableResult
    public func alterKey(_ alterKeySpec: [String]) -> Self {
        formatted = false
        self.alterKeySpec = alterKeySpec
        return self
    }

    /// Convert the `alterKeySpec` into a list of accidentals to be displayed.
    func convertToAlterAccList(_ alterKeySpec: [String]) {
        let max = min(alterKeySpec.count, accList.count)
        for i in 0..<max {
            if !alterKeySpec[i].isEmpty {
                accList[i].type = alterKeySpec[i]
            }
        }
    }

    /// Format and position the modifier.
    /// If no stave is set, a dummy stave is created.
    public func format() {
        let stave: Stave
        if let attached = getStave() {
            stave = attached
        } else {
            stave = Stave(x: 0, y: 0, width: 100)
            setStave(stave)
        }

        let clef = activeClef(stave)
        formattedClef = clef
        formattedStaveY = stave.getY()
        width = 0
        children = []
        if let ordered {
            let positioned: [KeySignatureAccidental] = ordered.map { entry in
                switch entry.placement {
                case .line(let line):
                    return (type: entry.type, line: line)
                case .pitch(let pitch):
                    // Note lines count upward, with E4 on treble line one. Stave modifier lines count down
                    // from zero. The pitch was validated, so the lookup cannot fail.
                    let line = (try? Tables.keyProperties(pitch, clef: clef).line) ?? .nan
                    return (type: entry.type, line: 5 - line)
                }
            }
            for (i, entry) in positioned.enumerated() {
                convertToGlyph(entry, i + 1 < positioned.count ? positioned[i + 1] : nil, stave)
            }
            calculateDimensions()
            formatted = true
            return
        }
        // Upstream throws 'BadKeySignature' here; this method does not throw, so an
        // unknown key spec gives an empty key signature.
        accList = keySpec.flatMap { try? Tables.keySignature($0) } ?? []
        let firstAccidentalType = accList.first?.type
        var cancelAccList: (type: String, accList: [KeySignatureAccidental])?
        if let cancelKeySpec, !cancelKeySpec.isEmpty {
            cancelAccList = convertToCancelAccList(cancelKeySpec)
        }
        if let alterKeySpec {
            convertToAlterAccList(alterKeySpec)
        }

        if !accList.isEmpty {
            // Upstream converts `cancelAccList.accList` and the local `accList` in place.
            // The local `accList` is the list from before the naturals were prepended, so
            // the naturals get only the cancel conversion and the key accidentals get only
            // the main conversion. Reproduce that with value types here.
            let cancelCount = cancelAccList?.accList.count ?? 0
            if let cancelAccList {
                var cancelled = cancelAccList.accList
                convertAccLines(clef, cancelAccList.type, &cancelled)
                for i in 0..<cancelled.count {
                    accList[i] = cancelled[i]
                }
            }
            var main = Array(accList.dropFirst(cancelCount))
            convertAccLines(clef, firstAccidentalType, &main)
            for i in 0..<main.count {
                accList[cancelCount + i] = main[i]
            }
            for i in 0..<accList.count {
                convertToGlyph(accList[i], i + 1 < accList.count ? accList[i + 1] : nil, stave)
            }
        }

        calculateDimensions()
        formatted = true
    }

    /// End signatures follow an end clef when one is present. Inline signatures can override the stave.
    private func activeClef(_ stave: Stave) -> ClefName {
        clefOverride ?? ((position == .end ? stave.getEndClef() : nil) ?? stave.getClef())
    }

    /// Stave clef and origin can change while the same signature object stays attached. (VexFlow 5.9.0)
    private func ensureFormatted() {
        if !formatted {
            format()
        } else if let stave = getStave(), formattedClef != activeClef(stave) || formattedStaveY != stave.getY() {
            format()
        }
    }

    /// Refresh the accidental origins after moving a staff and return each positioned glyph. (VexFlow 5.4.0)
    public func getInkParts() -> [BoundingBox] {
        ensureFormatted()
        return children.map { $0.getTextInk(x, 0) }
    }

    // MARK: - Draw

    /// Render the key signature.
    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let ctx = try stave.checkContext()

        ensureFormatted()
        setRendered()

        _ = ctx.openGroup(groupClass("keysignature"), getAttribute("id"))
        for glyph in children {
            glyph.renderText(ctx, xPos: x, yPos: 0)
        }
        drawPointerRect()
        ctx.closeGroup()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("KeySignature", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 20, width: 240)
        _ = s1.addClef(.treble).addKeySignature("A")

        let s2 = f.Stave(x: 260, y: 20, width: 240)
        _ = s2.addClef(.treble).addKeySignature("Bb")

        try? f.draw()
    }
    .padding()
}
#endif
