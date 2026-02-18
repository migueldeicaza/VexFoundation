// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

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
    public var stemDirection: Int
    public var stemExtension: Double
    public var yBottom: Double
    public var yTop: Double
    public var xEnd: Double
    public var xBegin: Double

    public init(
        stemDownYBaseOffset: Double = 0, stemUpYBaseOffset: Double = 0,
        stemDownYOffset: Double = 0, stemUpYOffset: Double = 0,
        stemletHeight: Double = 0, isStemlet: Bool = false,
        hide: Bool = false, stemDirection: Int = 0,
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
    public static let UP: Int = 1
    public static let DOWN: Int = -1

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
    public var yBottom: Double
    public var stemUpYOffset: Double = 0
    public var stemDownYOffset: Double = 0
    public var stemUpYBaseOffset: Double = 0
    public var stemDownYBaseOffset: Double = 0
    public var stemDirection: Int
    public var stemExtension: Double
    public var renderHeightAdjustment: Double = 0

    // MARK: - Init

    public init(options: StemOptions? = nil) {
        self.xBegin = options?.xBegin ?? 0
        self.xEnd = options?.xEnd ?? 0
        self.yTop = options?.yTop ?? 0
        self.yBottom = options?.yBottom ?? 0
        self.stemExtension = options?.stemExtension ?? 0
        self.stemDirection = options?.stemDirection ?? 0
        self.hide = options?.hide ?? false
        self.isStemlet = options?.isStemlet ?? false
        self.stemletHeight = options?.stemletHeight ?? 0
        super.init()
        setOptions(options)
    }

    public func setOptions(_ options: StemOptions?) {
        stemUpYOffset = options?.stemUpYOffset ?? 0
        stemDownYOffset = options?.stemDownYOffset ?? 0
        stemUpYBaseOffset = options?.stemUpYBaseOffset ?? 0
        stemDownYBaseOffset = options?.stemDownYBaseOffset ?? 0
    }

    // MARK: - Methods

    @discardableResult
    public func setNoteHeadXBounds(_ xBegin: Double, _ xEnd: Double) -> Self {
        self.xBegin = xBegin
        self.xEnd = xEnd
        return self
    }

    public func setDirection(_ direction: Int) {
        stemDirection = direction
    }

    public func setExtension(_ ext: Double) {
        stemExtension = ext
    }

    public func getExtension() -> Double { stemExtension }

    public func setYBounds(_ yTop: Double, _ yBottom: Double) {
        self.yTop = yTop
        self.yBottom = yBottom
    }

    public func getHeight() -> Double {
        let yOffset = stemDirection == Stem.UP ? stemUpYOffset : stemDownYOffset
        let unsignedHeight = yBottom - yTop + (Stem.HEIGHT - yOffset + stemExtension)
        return unsignedHeight * Double(stemDirection)
    }

    public func getExtents() -> (topY: Double, baseY: Double) {
        let isStemUp = stemDirection == Stem.UP
        let ys = [yTop, yBottom]
        let stemHeight = Stem.HEIGHT + stemExtension

        let innerMostNoteheadY = isStemUp ? ys.min()! : ys.max()!
        let outerMostNoteheadY = isStemUp ? ys.max()! : ys.min()!
        let stemTipY = innerMostNoteheadY + stemHeight * Double(-stemDirection)

        return (topY: stemTipY, baseY: outerMostNoteheadY)
    }

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
        let musicFont = Glyph.MUSIC_FONT_STACK.first!
        renderHeightAdjustment = (musicFont.lookupMetric("stem.heightAdjustmentForFlag") as? Double) ?? -3
    }

    public func adjustHeightForBeam() {
        renderHeightAdjustment = -Stem.WIDTH / 2
    }

    // MARK: - Draw

    override public func draw() throws {
        setRendered()
        if hide { return }
        let ctx = try checkContext()

        var stemX: Double
        var stemY: Double
        var yBaseOffset: Double = 0

        if stemDirection == Stem.DOWN {
            stemX = xBegin
            stemY = yTop + stemDownYOffset
            yBaseOffset = stemDownYBaseOffset
        } else {
            stemX = xEnd
            stemY = yBottom - stemUpYOffset
            yBaseOffset = stemUpYBaseOffset
        }

        let stemHeight = getHeight()
        let stemletYOffset = isStemlet ? stemHeight - stemletHeight * Double(stemDirection) : 0

        ctx.save()
        applyStyle()
        _ = ctx.openGroup("stem", getAttribute("id"))
        ctx.beginPath()
        ctx.setLineWidth(Stem.WIDTH)
        ctx.moveTo(stemX, stemY - stemletYOffset + yBaseOffset)
        ctx.lineTo(stemX, stemY - stemHeight - renderHeightAdjustment * Double(stemDirection))
        ctx.stroke()
        ctx.closeGroup()
        restoreStyle()
        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Stem", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        let upNotes = score.notes("E5/q, F5, G5, A5", options: ["stem": "up"])
        _ = system.addStave(SystemStave(
            voices: [score.voice(upNotes)]
        )).addClef("treble")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
