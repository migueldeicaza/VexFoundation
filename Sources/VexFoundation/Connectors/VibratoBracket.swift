// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Balazs Forian-Szabo. MIT License.

import Foundation

public enum VibratoBracketError: Error, LocalizedError, Equatable, Sendable {
    case requiresStartOrStopNote

    public var errorDescription: String? {
        switch self {
        case .requiresStartOrStopNote:
            return "VibratoBracket needs start or stop note."
        }
    }
}

// MARK: - VibratoBracket

/// Renders vibrato effect between two notes using a wave bracket.
public final class VibratoBracket: VexElement {

    override public class var category: String { "VibratoBracket" }

    // MARK: - Properties

    public var start: Note?
    public var stop: Note?
    public var vibLine: Double = 1
    public var vibRenderOptions = VibratoRenderOptions(vibratoWidth: 0)
    public private(set) var initError: VibratoBracketError?

    // MARK: - Init

    public init(start: Note? = nil, stop: Note? = nil) {
        if start == nil && stop == nil {
            self.initError = .requiresStartOrStopNote
        }
        self.start = start
        self.stop = stop
        super.init()
    }

    public convenience init(validatingStart start: Note? = nil, stop: Note? = nil) throws {
        self.init(start: start, stop: stop)
        if let initError {
            throw initError
        }
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

        guard start != nil || stop != nil else {
            throw VibratoBracketError.requiresStartOrStopNote
        }

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

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("VibratoBracket", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()

        _ = f.VibratoBracket(from: notes[0], to: notes[3])

        try? f.draw()
    }
    .padding()
}
#endif
