// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Crescendo Options

public struct CrescendoOptions {
    public var extendLeft: Double = 0
    public var extendRight: Double = 0
    public var yShift: Double = 0

    public init(
        extendLeft: Double = 0,
        extendRight: Double = 0,
        yShift: Double = 0
    ) {
        self.extendLeft = extendLeft
        self.extendRight = extendRight
        self.yShift = yShift
    }
}

// MARK: - Crescendo

/// A note that renders crescendo and decrescendo (hairpin) dynamics.
/// Formatted as part of a Voice like any other Note type.
public final class Crescendo: Note {

    override public class var category: String { "Crescendo" }

    // MARK: - Properties

    public var decrescendo: Bool = false
    public var height: Double = 15
    public var line: Double = 0
    public var crescendoOptions = CrescendoOptions()

    // MARK: - Init

    public override init(_ noteStruct: NoteStruct) {
        self.line = noteStruct.line ?? 0
        super.init(noteStruct)
    }

    // MARK: - Setters

    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    @discardableResult
    public func setHeight(_ height: Double) -> Self {
        self.height = height
        return self
    }

    @discardableResult
    public func setDecrescendo(_ decresc: Bool) -> Self {
        self.decrescendo = decresc
        return self
    }

    // MARK: - PreFormat

    override public func preFormat() {
        preFormatted = true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let stave = checkStave()
        setRendered()

        let tickContext = checkTickContext()
        let nextContext = TickContext.getNextContext(tickContext)

        let beginX = getAbsoluteX()
        let endX = nextContext != nil ? nextContext!.getX() : stave.getX() + stave.getWidth()
        let y = stave.getYForLine(line + (-3)) + 1

        Crescendo.renderHairpin(
            ctx: ctx,
            beginX: beginX - crescendoOptions.extendLeft,
            endX: endX + crescendoOptions.extendRight,
            y: y + crescendoOptions.yShift,
            height: height,
            reverse: decrescendo
        )
    }

    // MARK: - Static Render

    private static func renderHairpin(
        ctx: any RenderContext,
        beginX: Double,
        endX: Double,
        y: Double,
        height: Double,
        reverse: Bool
    ) {
        let halfHeight = height / 2

        ctx.beginPath()

        if reverse {
            ctx.moveTo(beginX, y - halfHeight)
            ctx.lineTo(endX, y)
            ctx.lineTo(beginX, y + halfHeight)
        } else {
            ctx.moveTo(endX, y - halfHeight)
            ctx.lineTo(beginX, y)
            ctx.lineTo(endX, y + halfHeight)
        }

        ctx.stroke()
        ctx.closePath()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Crescendo", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 150) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))

        let cresc = Crescendo(NoteStruct(duration: .quarter))
        _ = cresc.setDecrescendo(false)
        _ = cresc.setHeight(15)
        _ = cresc.setLine(4)

        let notes = score.notes("C5/q, D5, E5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes + [cresc])]
        )).addClef(.treble)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
