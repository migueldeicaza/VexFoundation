// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/ghostnote.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - GhostNote

/// An invisible note used for spacing and formatting.
/// Ghost notes take time in a voice, but do not render.
public final class GhostNote: StemmableNote {

    override public class var category: String { "GhostNote" }

    // MARK: - Init

    /// Create a ghost note from a typed note value.
    public convenience init(_ duration: NoteValue) {
        self.init(NoteStruct(duration: NoteDurationSpec(uncheckedValue: duration)))
    }

    /// Create a ghost note from a duration string (e.g. "4", "8").
    /// Preserves backwards compatibility with the upstream string parameter.
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

        // Note properties
        setWidth(0)
    }

    // MARK: - Overrides

    /// True: ghost notes are a type of rest.
    override public func isRest() -> Bool { true }

    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        super.setStave(stave)
        return self
    }

    /// Overridden to ignore.
    @discardableResult
    override public func addToModifierContext(_ mc: ModifierContext) -> Self {
        // DO NOTHING.
        return self
    }

    override public func preFormat() {
        preFormatted = true
    }

    override public func draw() throws {
        // Draw Annotations
        setRendered()
        for modifier in modifiers {
            if modifier is Annotation {
                modifier.setContext(getContext())
                try modifier.drawWithStyle()
            }
        }
    }
}
