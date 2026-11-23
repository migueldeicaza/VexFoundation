// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/accordionregister.ts` (VexFlow 5.9.0).
// Right-hand accordion register signs selected by the number and pitch of the sounding reeds.

import Foundation

/// Active reed ranks. Omitted ranks are silent. (VexFlow 5.9.0)
public struct AccordionRanks: Equatable, Sendable {
    /// The 4-foot reed.
    public var high: Bool
    /// Number of sounding 8-foot reeds, from zero through three.
    public var middle: Int
    /// The 16-foot reed.
    public var low: Bool

    public init(high: Bool = false, middle: Int = 0, low: Bool = false) {
        self.high = high
        self.middle = middle
        self.low = low
    }
}

/// Each row lists the precomposed SMuFL signs for zero, one, two, or three middle reeds.
private enum AccordionRegisterSigns {
    static let neither = [
        Glyphs.accdnCombRH3RanksEmpty,
        Glyphs.accdnRH3RanksClarinet,
        Glyphs.accdnRH3RanksTwoChoirs,
        Glyphs.accdnRH3RanksAuthenticMusette,
    ]
    static let high = [
        Glyphs.accdnRH3RanksPiccolo,
        Glyphs.accdnRH3RanksOboe,
        Glyphs.accdnRH3RanksImitationMusette,
        Glyphs.accdnRH3RanksDoubleTremoloUpper8ve,
    ]
    static let low = [
        Glyphs.accdnRH3RanksBassoon,
        Glyphs.accdnRH3RanksBandoneon,
        Glyphs.accdnRH3RanksAccordion,
        Glyphs.accdnRH3RanksDoubleTremoloLower8ve,
    ]
    static let both = [
        Glyphs.accdnRH3RanksOrgan,
        Glyphs.accdnRH3RanksHarmonium,
        Glyphs.accdnRH3RanksMaster,
        Glyphs.accdnRH3RanksFullFactory,
    ]
}

/// A circular, three-band register sign centered above the attached note. (VexFlow 5.9.0)
public final class AccordionRegister: Annotation {
    private let ranks: AccordionRanks

    /// Throws when `middle` is not zero through three.
    public init(_ ranks: AccordionRanks) throws {
        guard (0...3).contains(ranks.middle) else {
            throw VexError("RangeError", "The middle accordion rank supports zero through three reeds.")
        }
        var row = ranks.low ? AccordionRegisterSigns.low : AccordionRegisterSigns.neither
        if ranks.high { row = ranks.low ? AccordionRegisterSigns.both : AccordionRegisterSigns.high }
        self.ranks = ranks
        super.init(row[ranks.middle])
        setFont(Metrics.getFontInfo("AccordionRegister"))
        addClass("accordion-register")
    }

    /// Read the active ranks independently of the font or switch name.
    public func getRanks() -> AccordionRanks {
        ranks
    }

    /// Some music fonts draw past the advance width. Reserve the entire circular frame.
    override public func getWidth() -> Double {
        let metrics = getTextMetrics()
        return max(metrics.width, metrics.actualBoundingBoxLeft + metrics.actualBoundingBoxRight)
    }

    /// Align the visible circle to the annotation box even when the font has asymmetric side bearings.
    override public func computeX() throws -> (x: Double, textWidth: Double) {
        let (x, textWidth) = try super.computeX()
        let metrics = getTextMetrics()
        let inkWidth = metrics.actualBoundingBoxLeft + metrics.actualBoundingBoxRight
        return (x + (textWidth - inkWidth) / 2 + metrics.actualBoundingBoxLeft, textWidth)
    }

    /// Measure the sign at its current entrance, including after a width change.
    /// `nil` before the sign is attached to a formatted note (upstream throws).
    override public func getBoundingBox() -> BoundingBox? {
        guard let x = try? computeX().x, let y = try? computeY().y else { return nil }
        return getTextInk(x, y)
    }
}
