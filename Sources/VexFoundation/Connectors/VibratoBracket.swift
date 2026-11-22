// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Balazs Forian-Szabo
//
// Port of `src/vibratobracket.ts` (VexFlow 5.0.0).

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

/// `VibratoBracket` renders vibrato effect between two notes.
public final class VibratoBracket: VexElement {

    override public class var category: String { "VibratoBracket" }

    // MARK: - Properties

    public var line: Double = 1
    public let vibrato = Vibrato()

    public var start: Note?
    public var stop: Note?

    /// Swift-native: set when neither a start nor a stop note is given.
    public private(set) var initError: VibratoBracketError?

    // MARK: - Init

    /// Either the stop or start note must be set, or both of them.
    /// A nil start or stop note means that the vibrato is drawn from the
    /// beginning or until the end of the stave.
    public init(start: Note? = nil, stop: Note? = nil) {
        if start == nil && stop == nil {
            self.initError = .requiresStartOrStopNote
        }
        self.start = start
        self.stop = stop
        super.init()
        self.line = 1
    }

    /// Throwing variant: fails when neither a start nor a stop note is given.
    public convenience init(validatingStart start: Note? = nil, stop: Note? = nil) throws {
        self.init(start: start, stop: stop)
        if let initError {
            throw initError
        }
    }

    // MARK: - Setters

    /// Set line position of the vibrato bracket.
    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    /// Set vibrato code.
    @discardableResult
    public func setVibratoCode(_ code: Int) -> Self {
        vibrato.setVibratoCode(code)
        return self
    }

    // MARK: - Draw

    /// JavaScript `||` on numbers: 0 and NaN are falsy.
    private static func truthy(_ v: Double?) -> Double? {
        guard let v, v != 0, !v.isNaN else { return nil }
        return v
    }

    /// Draw the vibrato bracket on the rendering context.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        let y: Double =
            Self.truthy(start.map { $0.checkStave().getYForTopText(line) })
            ?? Self.truthy(stop.map { $0.checkStave().getYForTopText(line) })
            ?? 0
        // If start note is not set then vibrato will be drawn
        // from the beginning of the stave
        let startX: Double =
            Self.truthy(start.map { $0.getAbsoluteX() })
            ?? Self.truthy(stop.map { $0.checkStave().getTieStartX() })
            ?? 0
        // If stop note is not set then vibrato will be drawn
        // until the end of the stave
        let stopX: Double =
            Self.truthy(stop.map { $0.getAbsoluteX() - $0.getWidth() - 5 })
            ?? Self.truthy(start.map { $0.checkStave().getTieEndX() - 10 })
            ?? 0

        vibrato.setVibratoWidth(stopX - startX)

        vibrato.renderText(ctx, xPos: startX, yPos: y)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("VibratoBracket", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

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
