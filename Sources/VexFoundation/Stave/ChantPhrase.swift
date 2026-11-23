// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/chantphrase.ts` (VexFlow 5.9.0).
// Engrave square-notation chant with one indivisible neume per sung syllable.

import Foundation

/// Natural pitches are written in singing order, e.g. `["c/4", "d/4"]`.
public struct ChantSyllable: Sendable, Equatable {
    public var pitches: [String]
    public var syllable: String

    public init(pitches: [String], syllable: String) {
        self.pitches = pitches
        self.syllable = syllable
    }
}

/// Each new system repeats the selected movable clef. Dimensions are renderer pixels.
public struct ChantPhraseOptions: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var clef: ChantClef
    public var line: Int

    public init(x: Double, y: Double, width: Double, clef: ChantClef, line: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.clef = clef
        self.line = line
    }
}

/// The neume shape of one syllable.
public enum ChantNeumeKind: String, Sendable {
    case punctum, podatus, clivis
}

/// A rendered neume and its lyric share this horizontal center on the returned stave.
public struct ChantGroupPlacement: Sendable, Equatable {
    public var pitches: [String]
    public var syllable: String
    public var kind: ChantNeumeKind
    public var x: Double
    public var ys: [Double]
}

/// An oversized syllable gets a system wide enough to fit its complete neume and text.
public struct ChantPhraseRow {
    public var stave: ChantStave
    public var groups: [ChantGroupPlacement]
    public var lyricY: Double
}

/// Draw one SMuFL component with the middle of its ink at the given pitch.
private func drawComponent(_ ctx: RenderContext, _ glyph: VexElement, _ left: Double, _ y: Double) {
    let ink = glyph.getTextInk(0, 0)
    glyph.renderText(ctx, xPos: left - ink.x, yPos: y - ink.y - ink.h / 2)
}

/// Use one set of music glyphs and staff-relative stroke widths throughout the phrase.
private struct ChantSigns {
    let space: Double
    let punctum: VexElement
    let lower: VexElement
    let upper: VexElement
    let squareWidth: Double
    let risingWidth: Double

    init(space: Double) {
        func sign(_ text: String) -> VexElement {
            VexElement().setText(text).setFontSize("\(formatJSNumber(4 * space))px")
        }
        self.space = space
        punctum = sign(Glyphs.chantPunctum)
        lower = sign(Glyphs.chantPodatusLower)
        upper = sign(Glyphs.chantPodatusUpper)
        squareWidth = punctum.getTextInk(0, 0).w
        risingWidth = max(lower.getTextInk(0, 0).w, upper.getTextInk(0, 0).w)
    }

    func width(_ kind: ChantNeumeKind) -> Double {
        if kind == .podatus { return risingWidth }
        return kind == .clivis ? 2 * squareWidth : squareWidth
    }

    func draw(_ ctx: RenderContext, _ group: ChantGroupPlacement) {
        let center = group.x
        let ys = group.ys
        switch group.kind {
        case .punctum:
            drawComponent(ctx, punctum, center - squareWidth / 2, ys[0])
        case .podatus:
            let right = center + risingWidth / 2
            ctx.fillRect(right - space * 0.12, ys[1], space * 0.12, ys[0] - ys[1])
            drawComponent(ctx, lower, right - lower.getTextInk(0, 0).w, ys[0])
            drawComponent(ctx, upper, right - upper.getTextInk(0, 0).w, ys[1])
        case .clivis:
            let left = center - squareWidth
            ctx.fillRect(left, ys[0], space * 0.12, space * 1.25)
            ctx.fillRect(center - space * 0.06, ys[0], space * 0.12, ys[1] - ys[0])
            drawComponent(ctx, punctum, left, ys[0])
            drawComponent(ctx, punctum, center, ys[1])
        }
    }
}

/// A phrase can be drawn repeatedly at different widths from the same syllables.
public final class ChantPhrase {
    private let syllables: [ChantSyllable]

    /// Throws when a syllable has no text or does not have one or two pitches.
    public init(_ syllables: [ChantSyllable]) throws {
        for syllable in syllables {
            if syllable.pitches.isEmpty || syllable.pitches.count > 2
                || syllable.syllable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw VexError("BadArguments", "A chant syllable needs text and one or two pitches.")
            }
        }
        self.syllables = syllables
    }

    /// Measure whole syllables before choosing breaks. Return the exact printed pitch positions.
    @discardableResult
    public func draw(_ ctx: RenderContext, _ options: ChantPhraseOptions) throws -> [ChantPhraseRow] {
        let x = options.x
        let y = options.y
        let width = options.width
        if ![x, y, width].allSatisfy({ $0.isFinite }) || width <= 0 {
            throw VexError("BadArguments", "Expected finite chant dimensions.")
        }
        if syllables.isEmpty { return [] }
        func makeStave(_ top: Double) throws -> ChantStave {
            let stave = try ChantStave(x: x, y: top, width: width, clef: options.clef, line: options.line)
            stave.setContext(ctx)
            return stave
        }
        var stave = try makeStave(y)
        let space = stave.getSpacingBetweenLines()
        let signs = ChantSigns(space: space)
        let gap = 2 * space
        let rightMargin = space
        var rows: [ChantPhraseRow] = []
        var cursor = stave.getNoteStartX() + space
        var row = ChantPhraseRow(stave: stave, groups: [], lyricY: stave.getYForLine(3) + 2.5 * space)
        var labels: [VexElement] = []

        // Spread complete groups over the available space only after choosing the break.
        func finishRow() {
            let spare = max(0, x + width - (cursor - gap) - rightMargin)
            if row.groups.count > 1 {
                for i in row.groups.indices {
                    row.groups[i].x += (Double(i) * spare) / Double(row.groups.count - 1)
                }
            }
            rows.append(row)
        }

        // Validate every pitch against the same clef before emitting any ink.
        struct Measured {
            var pitches: [String]
            var syllable: String
            var kind: ChantNeumeKind
            var lines: [Double]
            var label: VexElement
            var width: Double
        }
        var measured: [Measured] = []
        for syllable in syllables {
            let lines = try syllable.pitches.map { try stave.getLineForPitch($0) }
            if lines.count == 2 && lines[0] == lines[1] {
                throw VexError("BadArguments", "A two-note neume must rise or fall.")
            }
            let kind: ChantNeumeKind = lines.count == 1 ? .punctum : lines[1] < lines[0] ? .podatus : .clivis
            let musicWidth = signs.width(kind)
            let label = VexElement(category: "Annotation.lyric").setText(syllable.syllable)
            measured.append(Measured(
                pitches: syllable.pitches, syllable: syllable.syllable, kind: kind, lines: lines, label: label,
                width: max(musicWidth, label.getTextInk(0, 0).w)
            ))
        }

        for group in measured {
            if !row.groups.isEmpty && cursor + group.width + rightMargin > x + width {
                finishRow()
                stave = try makeStave(stave.getY() + row.lyricY - stave.getTopLineTopY() + 3 * space)
                row = ChantPhraseRow(stave: stave, groups: [], lyricY: stave.getYForLine(3) + 2.5 * space)
                cursor = stave.getNoteStartX() + space
            }
            let ys = group.lines.map { stave.getYForLine($0) }
            row.groups.append(ChantGroupPlacement(
                pitches: group.pitches, syllable: group.syllable, kind: group.kind, x: cursor + group.width / 2, ys: ys
            ))
            // Leave room below the lowest component anywhere on the current system.
            row.lyricY = max(row.lyricY, (ys.max() ?? row.lyricY) + 2.5 * space)
            labels.append(group.label)
            cursor += group.width
            if cursor + rightMargin > x + width { stave.setWidth(cursor + rightMargin - x) }
            cursor += gap
        }
        finishRow()

        var labelIndex = 0
        ctx.save()
        for printed in rows {
            try printed.stave.draw()
            for group in printed.groups {
                signs.draw(ctx, group)
                let label = labels[labelIndex]
                labelIndex += 1
                let ink = label.getTextInk(0, 0)
                label.renderText(ctx, xPos: group.x - ink.x - ink.w / 2, yPos: printed.lyricY)
            }
        }
        ctx.restore()
        return rows
    }
}
