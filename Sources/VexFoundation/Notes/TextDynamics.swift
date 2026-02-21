// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

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

/// Renders traditional text dynamics markings (p, f, sfz, rfz, ppp, etc.).
/// Can render any combination of: p, m, f, z, r, s.
public final class TextDynamics: Note {

    override public class var category: String { "TextDynamics" }

    // MARK: - Glyph Data

    /// Glyph codes and widths for each dynamics letter.
    public static let GLYPHS: [Character: (code: String, width: Double)] = [
        "f": (code: "dynamicForte", width: 12),
        "p": (code: "dynamicPiano", width: 14),
        "m": (code: "dynamicMezzo", width: 17),
        "s": (code: "dynamicSforzando", width: 10),
        "z": (code: "dynamicZ", width: 12),
        "r": (code: "dynamicRinforzando", width: 12),
    ]

    // MARK: - Properties

    public let sequence: String
    private var dynamicsLine: Double
    private var glyphs: [Glyph] = []
    public private(set) var textDynamicsInitError: TextDynamicsError?

    // MARK: - Init

    public init(_ noteStruct: TextNoteStruct) {
        self.sequence = (noteStruct.text ?? "").lowercased()
        self.dynamicsLine = noteStruct.line ?? 0

        super.init(NoteStruct(
            keys: noteStruct.keys.map(\.rawValue),
            duration: noteStruct.duration
        ))

        if let invalid = sequence.first(where: { TextDynamics.GLYPHS[$0] == nil }) {
            textDynamicsInitError = .invalidDynamicsCharacter(invalid)
        }

        renderOptions.glyphFontScale = Tables.NOTATION_FONT_SCALE
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

    @discardableResult
    public func setLine(_ line: Double) -> Self {
        dynamicsLine = line
        return self
    }

    public func getLine() -> Double { dynamicsLine }

    // MARK: - PreFormat

    public func preFormatThrowing() throws {
        var totalWidth: Double = 0
        glyphs = []

        for letter in sequence {
            guard let glyphData = TextDynamics.GLYPHS[letter] else {
                throw TextDynamicsError.invalidDynamicsCharacter(letter)
            }

            let glyph = Glyph(code: glyphData.code, point: renderOptions.glyphFontScale)
            glyphs.append(glyph)
            totalWidth += glyphData.width
        }

        setTickableWidth(totalWidth)
        preFormatted = true
    }

    override public func preFormat() {
        _ = try? preFormatThrowing()
    }

    // MARK: - Draw

    override public func draw() throws {
        if let textDynamicsInitError {
            throw textDynamicsInitError
        }
        if !preFormatted {
            try preFormatThrowing()
        }
        setRendered()
        let x = getAbsoluteX()
        let stave = checkStave()
        let y = stave.getYForLine(dynamicsLine + (-3))

        var letterX = x
        for (index, glyph) in glyphs.enumerated() {
            let letter = sequence[sequence.index(sequence.startIndex, offsetBy: index)]
            let ctx = try checkContext()
            glyph.render(ctx: ctx, x: letterX, y: y)
            if let glyphData = TextDynamics.GLYPHS[letter] {
                letterX += glyphData.width
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TextDynamics", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
