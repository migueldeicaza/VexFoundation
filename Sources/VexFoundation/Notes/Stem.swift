// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/stem.ts` (VexFlow 5.3.0).
// The `Stem` object is generally handled by its parent `StemmableNote`.

import Foundation

// MARK: - Stem Options

/// Configuration for stem rendering.
public struct StemOptions {
    public var stemDownYBaseOffset: Double
    public var stemUpYBaseOffset: Double
    public var stemDownYOffset: Double
    public var stemUpYOffset: Double
    public var stemletHeight: Double
    public var isStemlet: Bool
    public var hide: Bool
    public var stemDirection: StemDirection
    public var stemExtension: Double
    public var yBottom: Double
    public var yTop: Double
    public var xEnd: Double
    public var xBegin: Double

    public init(
        stemDownYBaseOffset: Double = 0, stemUpYBaseOffset: Double = 0,
        stemDownYOffset: Double = 0, stemUpYOffset: Double = 0,
        stemletHeight: Double = 0, isStemlet: Bool = false,
        hide: Bool = false, stemDirection: StemDirection = .up,
        stemExtension: Double = 0, yBottom: Double = 0,
        yTop: Double = 0, xEnd: Double = 0, xBegin: Double = 0
    ) {
        self.stemDownYBaseOffset = stemDownYBaseOffset
        self.stemUpYBaseOffset = stemUpYBaseOffset
        self.stemDownYOffset = stemDownYOffset
        self.stemUpYOffset = stemUpYOffset
        self.stemletHeight = stemletHeight
        self.isStemlet = isStemlet
        self.hide = hide
        self.stemDirection = stemDirection
        self.stemExtension = stemExtension
        self.yBottom = yBottom
        self.yTop = yTop
        self.xEnd = xEnd
        self.xBegin = xBegin
    }
}

// MARK: - Stem

/// Renders the stem of a note. Generally handled by its parent StemmableNote.
public final class Stem: VexElement {

    override public class var category: String { "Stem" }

    // Stem directions
    public static let UP: StemDirection = .up
    public static let DOWN: StemDirection = .down

    // Theme
    public static var WIDTH: Double { Tables.STEM_WIDTH }
    public static var HEIGHT: Double { Tables.STEM_HEIGHT }

    // MARK: - Properties

    public var hide: Bool
    public var isStemlet: Bool
    public var stemletHeight: Double
    public var xBegin: Double
    public var xEnd: Double
    public var yTop: Double
    public var stemUpYOffset: Double = 0
    public var yBottom: Double
    public var stemDownYOffset: Double = 0
    public var stemUpYBaseOffset: Double = 0
    public var stemDownYBaseOffset: Double = 0
    public var stemDirection: StemDirection
    public var stemExtension: Double
    /// Adjusts the rendered height without changing the result of `getExtents()`.
    public var renderHeightAdjustment: Double

    // MARK: - Init

    public init(options: StemOptions? = nil) {
        // Default notehead x bounds
        self.xBegin = options?.xBegin ?? 0
        self.xEnd = options?.xEnd ?? 0

        // Y bounds for top/bottom most notehead
        self.yTop = options?.yTop ?? 0
        self.yBottom = options?.yBottom ?? 0

        // Stem top extension
        self.stemExtension = options?.stemExtension ?? 0

        // Direction of the stem
        self.stemDirection = options?.stemDirection ?? .up

        // Flag to override all draw calls
        self.hide = options?.hide ?? false

        self.isStemlet = options?.isStemlet ?? false
        self.stemletHeight = options?.stemletHeight ?? 0

        self.renderHeightAdjustment = 0
        super.init(category: nil)
        setOptions(options)
    }

    public func setOptions(_ options: StemOptions?) {
        // Changing where the stem meets the head
        stemUpYOffset = options?.stemUpYOffset ?? 0
        stemDownYOffset = options?.stemDownYOffset ?? 0
        stemUpYBaseOffset = options?.stemUpYBaseOffset ?? 0
        stemDownYBaseOffset = options?.stemDownYBaseOffset ?? 0
    }

    // MARK: - Methods

    /// Set the x bounds for the default notehead.
    @discardableResult
    public func setNoteHeadXBounds(_ xBegin: Double, _ xEnd: Double) -> Self {
        self.xBegin = xBegin
        self.xEnd = xEnd
        return self
    }

    /// Set the direction of the stem in relation to the noteheads.
    public func setDirection(_ direction: StemDirection) {
        stemDirection = direction
    }

    /// Set the extension for the stem, generally for flags or beams.
    public func setExtension(_ ext: Double) {
        stemExtension = ext
    }

    public func getExtension() -> Double { stemExtension }

    /// Set the y bounds for the top and bottom noteheads.
    public func setYBounds(_ yTop: Double, _ yBottom: Double) {
        self.yTop = yTop
        self.yBottom = yBottom
    }

    /// The full height of the stem.
    override public func getHeight() -> Double {
        let yOffset = stemDirection == Stem.UP ? stemUpYOffset : stemDownYOffset
        let unsignedHeight = yBottom - yTop + (Stem.HEIGHT - yOffset + stemExtension)
        return unsignedHeight * stemDirection.signDouble
    }

    /// Bounds of the stroked segment. A hidden stem contributes no area.
    override public func getBoundingBox() -> BoundingBox? {
        let segment = getSegment()
        if hide { return BoundingBox(x: segment.x, y: segment.baseY, w: 0, h: 0) }
        return BoundingBox(
            x: segment.x - Stem.WIDTH / 2,
            y: min(segment.baseY, segment.tipY),
            w: Stem.WIDTH,
            h: abs(segment.baseY - segment.tipY)
        )
    }

    /// The y coordinates from the base of the stem to the top of the extension.
    public func getExtents() -> (topY: Double, baseY: Double) {
        let isStemUp = stemDirection == Stem.UP
        let stemHeight = Stem.HEIGHT + stemExtension

        let innerMostNoteheadY = isStemUp ? min(yTop, yBottom) : max(yTop, yBottom)
        let outerMostNoteheadY = isStemUp ? max(yTop, yBottom) : min(yTop, yBottom)
        let stemTipY = innerMostNoteheadY + stemHeight * -stemDirection.signDouble

        return (topY: stemTipY, baseY: outerMostNoteheadY)
    }

    /// Whether this segment contributes ink.
    public func isVisible() -> Bool { !hide }

    @discardableResult
    public func setVisibility(_ isVisible: Bool) -> Self {
        hide = !isVisible
        return self
    }

    @discardableResult
    public func setStemlet(_ isStemlet: Bool, height: Double) -> Self {
        self.isStemlet = isStemlet
        self.stemletHeight = height
        return self
    }

    public func adjustHeightForFlag() {
        renderHeightAdjustment = Metrics.getDouble("Stem.heightAdjustmentForFlag", -3)
    }

    public func adjustHeightForBeam() {
        renderHeightAdjustment = -Stem.WIDTH / 2
    }

    // MARK: - Draw

    /// Endpoints of the visible segment, including stemlets and flag shortening.
    public func getSegment(x: Double? = nil, adjustment: Double? = nil) -> (x: Double, baseY: Double, tipY: Double) {
        let adjustment = adjustment ?? renderHeightAdjustment
        let stemX: Double
        let stemY: Double
        let yBaseOffset: Double
        if stemDirection == Stem.DOWN {
            // Down stems are rendered to the left of the head.
            stemX = xBegin
            stemY = yTop + stemDownYOffset
            yBaseOffset = stemDownYBaseOffset
        } else {
            // Up stems are rendered to the right of the head.
            stemX = xEnd
            stemY = yBottom - stemUpYOffset
            yBaseOffset = stemUpYBaseOffset
        }

        let stemHeight = getHeight()

        // The offset from the stem base that gives the stemlet height.
        let stemletYOffset = isStemlet ? stemHeight - stemletHeight * stemDirection.signDouble : 0

        return (
            x: x ?? stemX,
            baseY: stemY - stemletYOffset + yBaseOffset,
            tipY: stemY - stemHeight - adjustment * stemDirection.signDouble
        )
    }

    /// Render the stem.
    override public func draw() throws {
        setRendered()
        if hide { return }
        let ctx = try checkContext()
        let segment = getSegment()

        // Draw the stem
        _ = ctx.openGroup(groupClass("stem"), getAttribute("id"))
        ctx.beginPath()
        ctx.setLineWidth(Stem.WIDTH)
        ctx.moveTo(segment.x, segment.baseY)
        ctx.lineTo(segment.x, segment.tipY)
        ctx.stroke()
        ctx.closeGroup()
    }
}
