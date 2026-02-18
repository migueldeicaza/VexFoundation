// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - KeySigNote

/// A note that renders a key signature change inline with other notes.
public final class KeySigNote: Note {

    override public class var CATEGORY: String { "KeySigNote" }

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
