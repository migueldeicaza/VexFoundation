import Foundation
import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Formatter.StaveNote___Justification")
    func formatterStaveNoteJustificationMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "StaveNote___Justification",
            width: 520,
            height: 280
        ) { factory, context in
            let score = factory.EasyScore()
            var y = 30.0

            func justifyToWidth(_ width: Double) {
                _ = factory.Stave(y: y).addClef(.treble)

                let lowerNotes = score.notes(
                    "(cbb4 en4 a4)/2, (d4 e4 f4)/8, (d4 f4 a4)/8, (cn4 f#4 a4)/4",
                    options: ["stem": "down"]
                )
                let upperNotes = score.notes(
                    "(bb4 e#5 a5)/4, (d5 e5 f5)/2, (c##5 fb5 a5)/4",
                    options: ["stem": "up"]
                )

                let lowerVoice = score.voice(lowerNotes.map { $0 as Note })
                let upperVoice = score.voice(upperNotes.map { $0 as Note })
                let voices = [lowerVoice, upperVoice]

                let justifyWidth = width - (Stave.defaultPadding + upstreamFormatterGlyphWidth("gClef"))
                _ = factory.Formatter()
                    .joinVoices(voices)
                    .format(voices, justifyWidth: justifyWidth)

                lowerVoice.getTickables().forEach { tickable in
                    drawUpstreamFormatterNoteMetrics(context: context, note: tickable, yPos: y + 140)
                }
                upperVoice.getTickables().forEach { tickable in
                    drawUpstreamFormatterNoteMetrics(context: context, note: tickable, yPos: y - 20)
                }

                y += 210
            }

            justifyToWidth(520)
            try factory.draw()
        }
    }

    @Test("Formatter.Whitespace_and_justify")
    func formatterWhitespaceAndJustifyMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Whitespace_and_justify",
            width: 1200,
            height: 150
        ) { _, context in
            let time44 = VoiceTime(numBeats: 4, beatValue: 4, resolution: 4 * Tables.RESOLUTION)
            let time34 = VoiceTime(numBeats: 3, beatValue: 4, resolution: 4 * Tables.RESOLUTION)

            try drawUpstreamFormatterRightJustifyScenario(
                context: context,
                time: time44,
                noteCount: 3,
                duration: "4",
                finalDuration: "2",
                x: 10,
                width: 300
            )
            try drawUpstreamFormatterRightJustifyScenario(
                context: context,
                time: time44,
                noteCount: 1,
                duration: "w",
                finalDuration: "w",
                x: 310,
                width: 300
            )
            try drawUpstreamFormatterRightJustifyScenario(
                context: context,
                time: time34,
                noteCount: 3,
                duration: "4",
                finalDuration: "4",
                x: 610,
                width: 300
            )
            try drawUpstreamFormatterRightJustifyScenario(
                context: context,
                time: time34,
                noteCount: 6,
                duration: "8",
                finalDuration: "8",
                x: 910,
                width: 300
            )
        }
    }

    @Test("Formatter.Tight")
    func formatterTightMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Tight", width: 440, height: 250) { factory, context in
            try drawUpstreamFormatterTightCase(
                factory: factory,
                context: context,
                secondVoiceWholeNote: false,
                maxIterations: 10
            )
        }
    }

    @Test("Formatter.Tight_2")
    func formatterTight2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Tight_2", width: 440, height: 250) { factory, context in
            try drawUpstreamFormatterTightCase(
                factory: factory,
                context: context,
                secondVoiceWholeNote: true,
                maxIterations: nil
            )
        }
    }

    private func drawUpstreamFormatterRightJustifyScenario(
        context: SVGRenderContext,
        time: VoiceTime,
        noteCount: Int,
        duration: String,
        finalDuration: String,
        x: Double,
        width: Double
    ) throws {
        let formatter = VexFoundation.Formatter()
        let stave = Stave(x: x, y: 20, width: width)
        _ = stave.setContext(context)

        let voice = try makeUpstreamFormatterVoice(
            time: time,
            noteCount: noteCount,
            duration: duration,
            finalDuration: finalDuration
        )
        _ = formatter.joinVoices([voice]).formatToStave([voice], stave: stave)

        try stave.draw()
        try voice.draw(context: context, stave: stave)
    }

    private func makeUpstreamFormatterVoice(
        time: VoiceTime,
        noteCount: Int,
        duration: String,
        finalDuration: String
    ) throws -> Voice {
        let voice = Voice(time: time)
        _ = voice.setMode(.soft)
        var tickables: [Tickable] = []
        for index in 0..<noteCount {
            let noteDuration = (index == noteCount - 1) ? finalDuration : duration
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: noteDuration))
            tickables.append(note)
        }
        _ = voice.addTickables(tickables)
        return voice
    }

    private func drawUpstreamFormatterTightCase(
        factory: Factory,
        context: SVGRenderContext,
        secondVoiceWholeNote: Bool,
        maxIterations: Int?
    ) throws {
        _ = context.scale(0.8, 0.8)
        let score = factory.EasyScore()

        let beamedPrefix = score.beam(score.notes("B4/16, B4, B4, B4, B4, B4, B4, B4"))
        let notesTop = beamedPrefix + score.notes("B4/q, B4")
        let notesBottom: [StemmableNote]
        if secondVoiceWholeNote {
            notesBottom = score.notes("B4/w")
        } else {
            notesBottom = score.notes("B4/q, B4") + score.beam(score.notes("B4/16, B4, B4, B4, B4, B4, B4, B4"))
        }

        let voiceTop = score.voice(notesTop.map { $0 as Note })
        let voiceBottom = score.voice(notesBottom.map { $0 as Note })

        let x = 10.0
        let y = 10.0
        let spaceBetweenStaves = 12.0

        let staveTop = factory.Stave(x: x, y: y, width: 500, options: StaveOptions(leftBar: false))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))
        let staveBottom = factory.Stave(
            x: x,
            y: y + staveTop.space(spaceBetweenStaves),
            width: 500,
            options: StaveOptions(leftBar: false)
        )
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

        attachUpstreamFormatterVoice(voiceTop, to: staveTop)
        attachUpstreamFormatterVoice(voiceBottom, to: staveBottom)

        var formatterOptions = FormatterOptions()
        if let maxIterations {
            formatterOptions.maxIterations = maxIterations
        }
        let formatter = VexFoundation.Formatter(options: formatterOptions)
        _ = formatter.joinVoices([voiceTop, voiceBottom])

        let startX = max(staveTop.getNoteStartX(), staveBottom.getNoteStartX())
        _ = staveTop.setNoteStartX(startX)
        _ = staveBottom.setNoteStartX(startX)

        let justifyWidth = formatter.preCalculateMinTotalWidth([voiceTop, voiceBottom])
        let autoWidth = justifyWidth + Stave.rightPadding + (startX - x)
        _ = staveTop.setStaveWidth(autoWidth)
        _ = staveBottom.setStaveWidth(autoWidth)

        _ = formatter.format([voiceTop, voiceBottom], justifyWidth: justifyWidth)
        _ = formatter.postFormat()
        Stave.formatBegModifiers([staveTop, staveBottom])

        try factory.draw()

        let lastY = y + staveTop.space(spaceBetweenStaves) + staveBottom.space(spaceBetweenStaves)
        drawUpstreamFormatterDebugging(context: context, formatter: formatter, xPos: startX, y1: y, y2: lastY)
    }

    private func attachUpstreamFormatterVoice(_ voice: Voice, to stave: Stave) {
        _ = voice.setStave(stave)
        for tickable in voice.getTickables() {
            _ = tickable.setStave(stave)
        }
    }

    private func drawUpstreamFormatterNoteMetrics(context: SVGRenderContext, note: Tickable, yPos: Double) {
        let metrics = note.getMetrics()
        let xStart = note.getAbsoluteX() - metrics.modLeftPx - metrics.leftDisplacedHeadPx
        let xPre1 = note.getAbsoluteX() - metrics.leftDisplacedHeadPx
        let xAbs = note.getAbsoluteX()
        let xPost1 = note.getAbsoluteX() + metrics.notePx
        let xPost2 = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx
        let xEnd = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx + metrics.modRightPx
        let xFreedomRight = xEnd + note.getFormatterMetrics().freedom.right
        let xWidth = xEnd - xStart

        _ = context.save()
        _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "8pt"))
        _ = context.fillText("\(Int(xWidth.rounded()))px", xStart + note.getXShift(), yPos)

        let y = yPos + 7
        func stroke(_ x1: Double, _ x2: Double, _ color: String, _ yy: Double = y) {
            _ = context.beginPath()
            _ = context.setStrokeStyle(color)
            _ = context.setFillStyle(color)
            _ = context.setLineWidth(3)
            _ = context.moveTo(x1 + note.getXShift(), yy)
            _ = context.lineTo(x2 + note.getXShift(), yy)
            _ = context.stroke()
        }

        stroke(xStart, xPre1, "red")
        stroke(xPre1, xAbs, "#999")
        stroke(xAbs, xPost1, "green")
        stroke(xPost1, xPost2, "#999")
        stroke(xPost2, xEnd, "red")
        stroke(xEnd, xFreedomRight, "#DD0")
        stroke(xStart - note.getXShift(), xStart, "#BBB")
        drawUpstreamFormatterDot(context: context, x: xAbs + note.getXShift(), y: y, color: "blue")

        let formatterMetrics = note.getFormatterMetrics()
        if formatterMetrics.iterations > 0 {
            let deviation = formatterMetrics.space.deviation
            let prefix = deviation >= 0 ? "+" : ""
            _ = context.setFillStyle("red")
            _ = context.fillText("\(prefix)\(Int(deviation.rounded()))", xAbs + note.getXShift(), yPos - 10)
        }

        _ = context.restore()
    }

    private func drawUpstreamFormatterDot(context: SVGRenderContext, x: Double, y: Double, color: String = "#F55") {
        _ = context.save()
        _ = context.setFillStyle(color)
        _ = context.beginPath()
        _ = context.arc(x, y, 3, 0, Double.pi * 2, false)
        _ = context.closePath()
        _ = context.fill()
        _ = context.restore()
    }

    private func drawUpstreamFormatterDebugging(
        context: SVGRenderContext,
        formatter: VexFoundation.Formatter,
        xPos: Double,
        y1: Double,
        y2: Double
    ) {
        let stavePadding = (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("stave.padding", defaultValue: 0) as? Double) ?? 0
        let x = xPos + stavePadding

        _ = context.save()
        _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "8pt"))

        for gap in formatter.contextGaps.gaps {
            _ = context.beginPath()
            _ = context.setStrokeStyle("rgba(100,200,100,0.4)")
            _ = context.setFillStyle("rgba(100,200,100,0.4)")
            _ = context.setLineWidth(1)
            _ = context.fillRect(x + gap.x1, y1, max(gap.x2 - gap.x1, 0), y2 - y1)
            _ = context.setFillStyle("green")
            _ = context.fillText("\(Int((gap.x2 - gap.x1).rounded()))", x + gap.x1, y2 + 12)
        }

        _ = context.setFillStyle("red")
        let lossText = String(
            format: "Loss: %.2f Shift: %.2f Gap: %.2f",
            formatter.totalCost,
            formatter.totalShift,
            formatter.contextGaps.total
        )
        _ = context.fillText(lossText, x - 20, y2 + 27)
        _ = context.restore()
    }

    private func upstreamFormatterGlyphWidth(_ glyphName: String) -> Double {
        guard let musicFont = Glyph.MUSIC_FONT_STACK.first,
              let glyphs = try? musicFont.getGlyphs(),
              let glyph = glyphs[glyphName],
              let resolution = try? musicFont.getResolution(),
              resolution != 0
        else {
            return Glyph.getWidth(code: glyphName, point: 39)
        }

        let widthInEm = (glyph.xMax - glyph.xMin) / resolution
        let ptScale = VexFont.scaleToPxFrom["pt"] ?? (4.0 / 3.0)
        return widthInEm * 38 * ptScale * 2
    }
}
