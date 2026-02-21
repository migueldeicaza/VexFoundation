// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - GhostNote

/// An invisible note used for spacing and formatting.
/// GhostNotes occupy time in a voice but do not render visually.
public final class GhostNote: StemmableNote {

    override public class var category: String { "GhostNote" }

    // MARK: - Init

    /// Create a ghost note from a typed note value.
    public convenience init(_ duration: NoteValue) {
        self.init(NoteStruct(duration: NoteDurationSpec(uncheckedValue: duration)))
    }

    /// Create a ghost note from a duration string (e.g. "4", "8").
    public convenience init(_ duration: String) throws {
        self.init(try NoteStruct(duration: duration))
    }

    /// Failable string parser convenience.
    public convenience init?(parsingDuration duration: String) {
        guard let noteStruct = NoteStruct(parsingDuration: duration) else { return nil }
        self.init(noteStruct)
    }

    public override init(_ noteStruct: NoteStruct) {
        super.init(noteStruct)
        // Match upstream behavior: ghost notes must not contribute intrinsic width.
        setTickableWidth(0)
    }

    // MARK: - Overrides

    override public func isRest() -> Bool { true }

    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        _ = super.setStave(stave)
        return self
    }

    @discardableResult
    override public func addToModifierContext(_ mc: ModifierContext) -> Self {
        // Ghost notes don't participate in modifier context
        return self
    }

    override public func preFormat() {
        setTickableWidth(0)
        preFormatted = true
    }

    override public func draw() throws {
        setRendered()
        // Ghost notes don't render, but their annotations should.
        for modifier in getModifiers() {
            guard modifier is Annotation else { continue }
            modifier.setContext(getContext())
            try modifier.draw()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("GhostNote", traits: .sizeThatFitsLayout) {
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
            voices: [score.voice(score.notes("C5/q, B4/q/r, E5/q, B4/q/r"))]
        )).addClef(.treble).addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
