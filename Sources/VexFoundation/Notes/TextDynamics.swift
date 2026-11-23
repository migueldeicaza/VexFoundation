// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/textdynamics.ts` (VexFlow 5.8.0).

import Foundation

public enum TextDynamicsError: Error, LocalizedError, Equatable, Sendable {
    case invalidDynamicsCharacter(Character)

    public var errorDescription: String? {
        switch self {
        case .invalidDynamicsCharacter(let char):
            return "Invalid dynamics character: \(char)"
        }
    }
}

// MARK: - TextDynamics

/// A timed music-font dynamic such as p, mf, sfz, or n (niente).
///
/// You can render any dynamics string that contains a combination of the
/// letters P, M, F, N, Z, R, S.
public final class TextDynamics: Note {

    override public class var category: String { "TextDynamics" }

    /// The glyph data for each dynamics letter.
    public static let GLYPHS: [Character: String] = [
        "f": Glyphs.dynamicForte,
        "p": Glyphs.dynamicPiano,
        "m": Glyphs.dynamicMezzo,
        "n": Glyphs.dynamicNiente,
        "s": Glyphs.dynamicSforzando,
        "z": Glyphs.dynamicZ,
        "r": Glyphs.dynamicRinforzando,
    ]

    // MARK: - Properties

    public let sequence: String
    public var line: Double
    public private(set) var textDynamicsInitError: TextDynamicsError?

    // MARK: - Init

    /// Create the dynamics marking. `TextDynamics` is a `Note`, so it can be
    /// formatted in a `Voice`.
    ///
    /// - Parameter noteStruct: a `duration` and the dynamics letters in `text`.
    public init(_ noteStruct: TextNoteStruct) {
        self.sequence = (noteStruct.text ?? "").lowercased()
        self.line = noteStruct.line ?? 0

        super.init(NoteStruct(
            keys: noteStruct.keys.map(\.rawValue),
            duration: noteStruct.duration,
            line: noteStruct.line
        ))

        text = ""

        if let invalid = sequence.first(where: { TextDynamics.GLYPHS[$0] == nil }) {
            textDynamicsInitError = .invalidDynamicsCharacter(invalid)
        }
    }

    public convenience init(validating noteStruct: TextNoteStruct) throws {
        self.init(noteStruct)
        if let textDynamicsInitError {
            throw textDynamicsInitError
        }
    }

    public convenience init?(parsingOrNil noteStruct: TextNoteStruct) {
        guard (try? TextDynamics(validating: noteStruct)) != nil else { return nil }
        self.init(noteStruct)
    }

    // MARK: - Line

    /// Set the stave line of the note.
    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    public func getLine() -> Double { line }

    // MARK: - PreFormat

    /// Preformat the dynamics text. Throws for an invalid dynamics character.
    public func preFormatThrowing() throws {
        // Resolve the entire sequence before replacing its text, including on repeated formatting.
        let glyphs = TextDynamics.GLYPHS
        var text = ""
        for letter in sequence {
            guard let glyph = glyphs[letter] else {
                throw TextDynamicsError.invalidDynamicsCharacter(letter)
            }
            text += glyph
        }
        self.text = text
        preFormatted = true
    }

    override public func preFormat() {
        _ = try? preFormatThrowing()
    }

    // MARK: - Bounding box

    /// Measure at the same page coordinates used by `draw()`, after voice formatting. (VexFlow 5.1.0)
    override public func getBoundingBox() -> BoundingBox? {
        guard let stave = getStave() else { return nil }
        let metrics = getTextMetrics()
        return BoundingBox(
            x: getAbsoluteX() + x + xShift,
            y: stave.getYForLine(line - 3) + y + yShift - metrics.actualBoundingBoxAscent,
            w: getWidth(),
            h: getHeight()
        )
    }

    // MARK: - Draw

    /// Draw the dynamics text.
    override public func draw() throws {
        if let textDynamicsInitError {
            throw textDynamicsInitError
        }
        setRendered()
        let x = getAbsoluteX()
        let y = checkStave().getYForLine(line + -3)

        renderText(try checkContext(), xPos: x, yPos: y)
    }
}
