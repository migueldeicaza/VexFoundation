// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Ornament

/// Modifier that renders ornaments (trills, mordents, turns, etc.) on notes.
public final class Ornament: Modifier {

    override public class var category: String { "Ornament" }
    private struct OrnamentMetrics {
        var xOffset: Double
        var yOffset: Double
        var stemUpYOffset: Double
        var reportedWidth: Double
    }

    // MARK: - Ornament Type Lists

    /// Ornaments that are rendered between note transitions (delayed).
    public static let noteTransitionTypes = ["flip", "jazzTurn", "smear"]

    /// Ornaments that are attack-type (placed before the note).
    public static let attackTypes = ["scoop"]

    /// Ornaments that align with the note head.
    public static let alignWithNoteHeadTypes = [
        "doit", "fall", "fallLong", "doitLong", "bend",
        "plungerClosed", "plungerOpen", "scoop"
    ]

    /// Ornaments that are release-type (placed after the note).
    public static let releaseTypes = [
        "doit", "fall", "fallLong", "doitLong",
        "jazzTurn", "smear", "flip"
    ]

    /// Ornaments that behave like articulations.
    public static let articulationTypes = ["bend", "plungerClosed", "plungerOpen"]
    public static var minPadding: Double {
        (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("noteHead.minPadding") as? Double) ?? 2
    }

    // MARK: - Properties

    public let type: String
    public var delayed: Bool = false
    public var adjustForStemDirection: Bool = false
    public var reportedWidth: Double = 0

    private let ornamentCode: String
    private var ornamentGlyph: Glyph
    private var stemUpYOffset: Double = 0
    private var ornamentAlignWithNoteHead: Bool = false
    private var accidentalUpper: Glyph?
    private var accidentalLower: Glyph?
    private var delayXShift: Double?
    private var formatterReportedWidth: Double = 0

    public var renderOpts = (
        accidentalUpperPadding: 3.0,
        accidentalLowerPadding: 3.0,
        fontScale: Tables.NOTATION_FONT_SCALE
    )

    // MARK: - Init

    public init(_ type: String) {
        self.type = type
        self.ornamentCode = Tables.ornamentCode(type) ?? type
        self.ornamentGlyph = Glyph(
            code: ornamentCode,
            point: Tables.NOTATION_FONT_SCALE,
            options: GlyphOptions(category: "ornament.\(ornamentCode)")
        )

        super.init()
        resetFont()

        let metrics = getMetrics()
        self.adjustForStemDirection = !Ornament.alignWithNoteHeadTypes.contains(type)
        self.delayed = Ornament.noteTransitionTypes.contains(type)
        self.ornamentAlignWithNoteHead = Ornament.alignWithNoteHeadTypes.contains(type)
        self.stemUpYOffset = metrics?.stemUpYOffset ?? 0
        self.xShift = metrics?.xOffset ?? 0
        self.yShift = metrics?.yOffset ?? 0
        self.formatterReportedWidth = metrics?.reportedWidth ?? 0
        // Preserve historical behavior in local unit tests while using upstream
        // reported-width semantics for formatter spacing.
        self.reportedWidth = metrics?.reportedWidth ?? ornamentGlyph.getMetrics().width

        // Legacy ornaments require this origin adjustment for correct placement.
        if metrics == nil {
            ornamentGlyph.setOrigin(0.5, 1.0)
        }
    }

    // MARK: - Delayed

    @discardableResult
    public func setDelayed(_ delayed: Bool) -> Self {
        self.delayed = delayed
        return self
    }

    // MARK: - Accidentals

    @discardableResult
    public func setUpperAccidental(_ accid: String) -> Self {
        let code = Tables.accidentalCodes[accid]?.code ?? accid
        let scale = renderOpts.fontScale / 1.3
        accidentalUpper = Glyph(code: code, point: scale)
        accidentalUpper?.setOrigin(0.5, 1.0)
        return self
    }

    @discardableResult
    public func setLowerAccidental(_ accid: String) -> Self {
        let code = Tables.accidentalCodes[accid]?.code ?? accid
        let scale = renderOpts.fontScale / 1.3
        accidentalLower = Glyph(code: code, point: scale)
        accidentalLower?.setOrigin(0.5, 1.0)
        return self
    }

    // MARK: - Static Format

    @discardableResult
    public static func format(_ ornaments: [Ornament], state: inout ModifierContextState) -> Bool {
        if ornaments.isEmpty { return false }

        var width: Double = 0
        var rightShift = state.rightShift
        var leftShift = state.leftShift
        var yOffset: Double = 0

        for ornament in ornaments {
            _ = ornament.checkAttachedNote()
            let increment = 2.0

            if Ornament.releaseTypes.contains(ornament.type) {
                ornament.xShift += rightShift + 2
            }
            if Ornament.attackTypes.contains(ornament.type) {
                ornament.xShift -= leftShift + 2
            }

            if ornament.formatterReportedWidth > 0, ornament.xShift < 0 {
                leftShift += ornament.formatterReportedWidth
            } else if ornament.formatterReportedWidth > 0, ornament.xShift >= 0 {
                rightShift += ornament.formatterReportedWidth + Ornament.minPadding
            } else {
                width = max(ornament.getWidth(), width)
            }

            if Ornament.articulationTypes.contains(ornament.type) {
                let note = ornament.getNote()
                if note.getLineNumber() >= 3 || ornament.getPosition() == .above {
                    state.topTextLine += increment
                    ornament.yShift += yOffset
                    yOffset -= ornament.ornamentGlyph.bbox.h
                } else {
                    state.textLine += increment
                    ornament.yShift += yOffset
                    yOffset += ornament.ornamentGlyph.bbox.h
                }
            } else if ornament.getPosition() == .above {
                _ = ornament.setTextLine(state.topTextLine)
                state.topTextLine += increment
            } else {
                _ = ornament.setTextLine(state.textLine)
                state.textLine += increment
            }
        }

        state.leftShift = leftShift + width / 2
        state.rightShift = rightShift + width / 2
        return true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        guard let note = checkAttachedNote() as? StemmableNote else { return }
        setRendered()
        _ = ctx.openGroup("ornament", getAttribute("id"))

        let stemDirection = note.getStemDirection()
        let stave = note.checkStave()
        let stemExtents = note.checkStem().getExtents()
        var y = stemDirection == Stem.DOWN ? stemExtents.baseY : stemExtents.topY

        if isTabNote(note) {
            if note.hasStem() {
                if stemDirection == Stem.DOWN {
                    y = stave.getYForTopText(textLine)
                }
            } else {
                y = stave.getYForTopText(textLine)
            }
        }

        let isPlacedOnNoteheadSide = stemDirection == Stem.DOWN
        let spacing = stave.getSpacingBetweenLines()
        var lineSpacing = 1.0
        if !isPlacedOnNoteheadSide && note.hasBeam() {
            lineSpacing += 0.5
        }
        let totalSpacing = spacing * (textLine + lineSpacing)
        let glyphYBetweenLines = y - totalSpacing

        let index = checkIndex()
        let start = note.getModifierStartXY(position: position, index: index)

        var glyphX = start.x
        var glyphY = ornamentAlignWithNoteHead
            ? start.y
            : min(stave.getYForTopText(textLine), glyphYBetweenLines)
        glyphY += yShift

        if delayed {
            let resolvedDelayXShift: Double
            if let cachedDelay = self.delayXShift {
                resolvedDelayXShift = cachedDelay
            } else {
                var computedDelay = ornamentGlyph.getMetrics().width / 2
                let startX = glyphX - stave.getNoteStartX()
                let tickables = note.getVoice().getTickables()
                if let noteIndex = tickables.firstIndex(where: { $0 === note }),
                   noteIndex + 1 < tickables.count {
                    let nextContext = tickables[noteIndex + 1].checkTickContext()
                    computedDelay += (nextContext.getX() - startX) * 0.5
                } else {
                    computedDelay += (stave.getX() + stave.getWidth() - glyphX) * 0.5
                }
                self.delayXShift = computedDelay
                resolvedDelayXShift = computedDelay
            }
            glyphX += resolvedDelayXShift
        }

        if let lower = accidentalLower {
            lower.render(ctx: ctx, x: glyphX, y: glyphY)
            glyphY -= lower.getMetrics().height
            glyphY -= renderOpts.accidentalLowerPadding
        }

        if stemUpYOffset != 0, note.hasStem(), note.getStemDirection() == Stem.UP {
            glyphY += stemUpYOffset
        }
        if note.getLineNumber() < 5, Ornament.noteTransitionTypes.contains(type) {
            glyphY = stave.getBBox().y + 40
        }

        ornamentGlyph.render(ctx: ctx, x: glyphX + xShift, y: glyphY)

        if let upper = accidentalUpper {
            glyphY -= ornamentGlyph.getMetrics().height + renderOpts.accidentalUpperPadding
            upper.render(ctx: ctx, x: glyphX, y: glyphY)
        }
        ctx.closeGroup()
    }

    private func getMetrics() -> OrnamentMetrics? {
        guard let font = Glyph.MUSIC_FONT_STACK.first,
              let ornament = font.lookupMetric("ornament") as? [String: Any],
              let metric = ornament[ornamentCode] as? [String: Any] else {
            return nil
        }

        return OrnamentMetrics(
            xOffset: metric["xOffset"] as? Double ?? 0,
            yOffset: metric["yOffset"] as? Double ?? 0,
            stemUpYOffset: metric["stemUpYOffset"] as? Double ?? 0,
            reportedWidth: metric["reportedWidth"] as? Double ?? 0
        )
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Ornament", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(f.Ornament("tr"), index: 0)
        _ = notes[1].addModifier(f.Ornament("mordent"), index: 0)
        _ = notes[2].addModifier(f.Ornament("turn"), index: 0)

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
