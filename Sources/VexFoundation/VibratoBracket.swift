// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Balazs Forian-Szabo. MIT License.

import Foundation

// MARK: - VibratoBracket

/// Renders vibrato effect between two notes using a wave bracket.
public final class VibratoBracket: VexElement {

    override public class var CATEGORY: String { "VibratoBracket" }

    // MARK: - Properties

    public var start: Note?
    public var stop: Note?
    public var vibLine: Double = 1
    public var vibRenderOptions = VibratoRenderOptions(vibratoWidth: 0)

    // MARK: - Init

    public init(start: Note? = nil, stop: Note? = nil) {
        guard start != nil || stop != nil else {
            fatalError("[VexError] BadArguments: VibratoBracket needs start or stop note.")
        }
        self.start = start
        self.stop = stop
        super.init()
    }

    // MARK: - Setters

    @discardableResult
    public func setLine(_ line: Double) -> Self {
        vibLine = line
        return self
    }

    @discardableResult
    public func setHarsh(_ harsh: Bool) -> Self {
        vibRenderOptions.harsh = harsh
        return self
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        let y: Double
        if let start {
            y = start.checkStave().getYForTopText(vibLine)
        } else if let stop {
            y = stop.checkStave().getYForTopText(vibLine)
        } else {
            y = 0
        }

        let startX: Double
        if let start {
            startX = start.getAbsoluteX()
        } else if let stop {
            startX = stop.checkStave().getTieStartX()
        } else {
            startX = 0
        }

        let stopX: Double
        if let stop {
            stopX = stop.getAbsoluteX() - stop.getGlyphWidth() - 5
        } else if let start {
            stopX = start.checkStave().getTieEndX() - 10
        } else {
            stopX = 0
        }

        vibRenderOptions.vibratoWidth = stopX - startX

        Vibrato.renderVibrato(ctx: ctx, x: startX, y: y, opts: vibRenderOptions)
    }
}
