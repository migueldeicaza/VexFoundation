// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - GhostNote

/// An invisible note used for spacing and formatting.
/// GhostNotes occupy time in a voice but do not render visually.
public final class GhostNote: StemmableNote {

    override public class var CATEGORY: String { "GhostNote" }

    // MARK: - Init

    /// Create a ghost note from a duration string (e.g. "4", "8") or NoteStruct.
    public convenience init(_ duration: String) {
        self.init(NoteStruct(duration: duration))
    }

    public override init(_ noteStruct: NoteStruct) {
        super.init(noteStruct)
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
        preFormatted = true
    }

    override public func draw() throws {
        setRendered()
        // Ghost notes don't render, but their annotations should
        for modifier in getModifiers() {
            modifier.setContext(getContext())
            try modifier.draw()
        }
    }
}
