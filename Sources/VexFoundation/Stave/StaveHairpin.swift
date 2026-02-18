// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Raffaele Viglianti. MIT License.

import Foundation

// MARK: - Hairpin Type

public enum HairpinType: Int {
    case crescendo = 1
    case decrescendo = 2
}

// MARK: - Hairpin Render Options

public struct HairpinRenderOptions {
    public var leftShiftPx: Double = 0
    public var rightShiftPx: Double = 0
    public var height: Double = 10
    public var yShift: Double = 0

    public init(
        leftShiftPx: Double = 0,
        rightShiftPx: Double = 0,
        height: Double = 10,
        yShift: Double = 0
    ) {
        self.leftShiftPx = leftShiftPx
        self.rightShiftPx = rightShiftPx
        self.height = height
        self.yShift = yShift
    }
}

// MARK: - StaveHairpin

/// Renders crescendo and decrescendo hairpins between two notes.
public final class StaveHairpin: VexElement {

    override public class var category: String { "StaveHairpin" }

    // MARK: - Properties

    public var hairpinType: HairpinType
    public var hairpinPosition: ModifierPosition = .below
    public var renderOptions = HairpinRenderOptions()
    public var firstNote: Note?
    public var lastNote: Note?

    // MARK: - Init

    public init(firstNote: Note?, lastNote: Note?, type: HairpinType) {
        guard firstNote != nil || lastNote != nil else {
            fatalError("[VexError] BadArguments: Hairpin needs to have either firstNote or lastNote set.")
        }
        self.firstNote = firstNote
        self.lastNote = lastNote
        self.hairpinType = type
        super.init()
    }

    // MARK: - Setters

    @discardableResult
    public func setPosition(_ position: ModifierPosition) -> Self {
        if position == .above || position == .below {
            hairpinPosition = position
        }
        return self
    }

    @discardableResult
    public func setRenderOptions(_ options: HairpinRenderOptions) -> Self {
        renderOptions = options
        return self
    }

    @discardableResult
    public func setNotes(firstNote: Note?, lastNote: Note?) -> Self {
        guard firstNote != nil || lastNote != nil else {
            fatalError("[VexError] BadArguments: Hairpin needs to have either firstNote or lastNote set.")
        }
        self.firstNote = firstNote
        self.lastNote = lastNote
        return self
    }

    // MARK: - Render

    private func renderHairpin(
        firstX: Double,
        lastX: Double,
        firstY: Double,
        staffHeight: Double
    ) throws {
        let ctx = try checkContext()
        var dis = renderOptions.yShift + 20
        var yShift = firstY

        if hairpinPosition == .above {
            dis = -dis + 30
            yShift = firstY - staffHeight
        }

        let lShift = renderOptions.leftShiftPx
        let rShift = renderOptions.rightShiftPx

        ctx.beginPath()

        switch hairpinType {
        case .crescendo:
            ctx.moveTo(lastX + rShift, yShift + dis)
            ctx.lineTo(firstX + lShift, yShift + renderOptions.height / 2 + dis)
            ctx.lineTo(lastX + rShift, yShift + renderOptions.height + dis)
        case .decrescendo:
            ctx.moveTo(firstX + lShift, yShift + dis)
            ctx.lineTo(lastX + rShift, yShift + renderOptions.height / 2 + dis)
            ctx.lineTo(firstX + lShift, yShift + renderOptions.height + dis)
        }

        ctx.stroke()
        ctx.closePath()
    }

    // MARK: - Draw

    override public func draw() throws {
        _ = try checkContext()
        setRendered()

        guard let firstNote, let lastNote else {
            fatalError("[VexError] NoNote: Notes required to draw hairpin.")
        }

        let start = firstNote.getModifierStartXY(position: hairpinPosition, index: 0)
        let end = lastNote.getModifierStartXY(position: hairpinPosition, index: 0)

        let stave = firstNote.checkStave()

        try renderHairpin(
            firstX: start.x,
            lastX: end.x,
            firstY: stave.getY() + stave.getHeight(),
            staffHeight: stave.getHeight()
        )
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveHairpin", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 150) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef("treble")

        system.format()

        let hp = StaveHairpin(firstNote: notes[0], lastNote: notes[1], type: .crescendo)
        _ = hp.setContext(ctx)

        let hp2 = StaveHairpin(firstNote: notes[2], lastNote: notes[3], type: .decrescendo)
        _ = hp2.setContext(ctx)

        try? f.draw()
        try? hp.draw()
        try? hp2.draw()
    }
    .padding()
}
#endif
