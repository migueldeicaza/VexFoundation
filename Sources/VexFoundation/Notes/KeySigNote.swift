// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/keysignote.ts` (VexFlow 5.9.0).
// Inline key signatures participate in voice spacing without consuming metered time.

import Foundation

// MARK: - KeySigNote

/// A note that renders a key signature change inline with other notes.
public final class KeySigNote: Note {

    override public class var category: String { "KeySigNote" }

    // MARK: - Properties

    public var keySignature: KeySignature!

    private var explicitClef: ClefName?
    private var hasWrittenPitches = false

    // MARK: - Init

    public init(keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil, clef: ClefName? = nil) {
        super.init(NoteStruct(duration: .twoFiftySixth))

        explicitClef = clef
        keySignature = KeySignature(
            keySpec: keySpec,
            cancelKeySpec: cancelKeySpec,
            alterKeySpec: alterKeySpec
        ).setClef(clef)

        // Note properties
        ignoreTicks = true
    }

    /// Restate a custom signature at this point in the voice, after any inline clef change. (VexFlow 5.9.0)
    @discardableResult
    public func setOrdered(_ entries: [OrderedKeySign]) throws -> Self {
        try keySignature.setOrdered(entries)
        hasWrittenPitches = entries.contains { $0.pitch != nil }
        preFormatted = false
        return self
    }

    /// A written signature follows the latest preceding clef on this staff in its voice.
    private func precedingClef() -> ClefName? {
        guard let notes = voice?.getTickables(), let index = notes.firstIndex(where: { $0 === self }) else {
            return nil
        }
        for prior in notes[..<index].reversed() {
            if let clefNote = prior as? ClefNote, clefNote.getStave() == nil || clefNote.getStave() === getStave() {
                return clefNote.getClef().getType()
            }
        }
        return nil
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
        if hasWrittenPitches { keySignature.setClef(explicitClef ?? precedingClef()) }
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
