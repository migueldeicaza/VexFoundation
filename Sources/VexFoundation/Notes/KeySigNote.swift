// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - KeySigNote

/// A note that renders a key signature change inline with other notes.
public final class KeySigNote: Note {

    override public class var category: String { "KeySigNote" }

    // MARK: - Properties

    public var keySignature: KeySignature

    // MARK: - Init

    public init(keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil) {
        self.keySignature = KeySignature(keySpec: keySpec)
        super.init(NoteStruct(duration: "b"))
        ignoreTicks = true
    }

    // MARK: - Overrides

    @discardableResult
    override public func addToModifierContext(_ mc: ModifierContext) -> Self {
        // Key signature notes don't participate in modifier context
        return self
    }

    override public func preFormat() {
        preFormatted = true
        if let stave = getStave() {
            keySignature.setStave(stave)
        }
        tickableWidth = keySignature.getModifierWidth()
    }

    override public func draw() throws {
        let stave = checkStave()
        setRendered()

        keySignature.modifierX = getAbsoluteX()
        try keySignature.drawStave(stave: stave)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("KeySigNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(score.notes("C5/q, D5, E5, F5"))]
        )).addClef(.treble).addKeySignature("D")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
