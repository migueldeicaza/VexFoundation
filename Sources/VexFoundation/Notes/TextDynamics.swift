// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/textdynamics.ts` (VexFlow 5.0.0).

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

/// `TextDynamics` renders traditional text dynamics markings, for example
/// p, f, sfz, rfz, ppp.
///
/// You can render any dynamics string that contains a combination of the
/// letters P, M, F, Z, R, S.
public final class TextDynamics: Note {

    override public class var category: String { "TextDynamics" }

    /// The glyph data for each dynamics letter.
    public static let GLYPHS: [Character: String] = [
        "f": Glyphs.dynamicForte,
        "p": Glyphs.dynamicPiano,
        "m": Glyphs.dynamicMezzo,
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
    /// - Parameter noteStruct: a `duration` and the `text` (the sequence of letters to render).
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
        // Create new glyphs if the note was formatted before.
        text = ""
        // Iterate through each letter
        for letter in sequence {
            // Get the glyph data for the letter
            guard let glyph = TextDynamics.GLYPHS[letter] else {
                throw TextDynamicsError.invalidDynamicsCharacter(letter)
            }

            // Add the glyph
            text += glyph
        }

        preFormatted = true
    }

    override public func preFormat() {
        _ = try? preFormatThrowing()
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
