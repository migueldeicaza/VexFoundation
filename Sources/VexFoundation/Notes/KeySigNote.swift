// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/keysignote.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - KeySigNote

/// A note that renders a key signature change inline with other notes.
public final class KeySigNote: Note {

    override public class var category: String { "KeySigNote" }

    // MARK: - Properties

    public var keySignature: KeySignature!

    // MARK: - Init

    public init(keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil) {
        super.init(NoteStruct(duration: .twoFiftySixth))

        keySignature = KeySignature(
            keySpec: keySpec,
            cancelKeySpec: cancelKeySpec,
            alterKeySpec: alterKeySpec
        )

        // Note properties
        ignoreTicks = true
    }

    // MARK: - Overrides

    /// Overridden to ignore.
    @discardableResult
    override public func addToModifierContext(_ mc: ModifierContext) -> Self {
        // DO NOTHING.
        return self
    }

    override public func preFormat() {
        preFormatted = true
        keySignature.setStave(checkStave())
        setWidth(keySignature.getWidth())
    }

    override public func draw() throws {
        let ctx = try checkStave().checkContext()
        setRendered()
        keySignature.setX(getAbsoluteX())
        keySignature.setContext(ctx)
        try keySignature.drawWithStyle()
    }
}
