import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("TextNote.TextNote_Formatting")
    func textNoteFormattingMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextNote", test: "TextNote_Formatting", width: 400, height: 200) { factory, _ in
            let stave = factory.Stave(y: 40)

            let voice1 = factory.Voice()
            let notes1: [StaveNote] = try [
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "e/4", "a/4"], "h", .down)
                    .addModifier(factory.Accidental(type: .flat), index: 0)
                    .addModifier(factory.Accidental(type: .sharp), index: 1),
                makeUpstreamTextNoteStaveNote(factory, ["d/4", "e/4", "f/4"], "q", .down),
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "f/4", "a/4"], "q", .down)
                    .addModifier(factory.Accidental(type: .natural), index: 0)
                    .addModifier(factory.Accidental(type: .sharp), index: 1),
            ]
            _ = voice1.addTickables(notes1.map { $0 as Tickable })

            let voice2 = factory.Voice()
            let notes2: [TextNote] = try [
                makeUpstreamTextNote(factory, duration: "h", text: "Center Justification")
                    .setJustification(.center),
                makeUpstreamTextNote(factory, duration: "q", text: "Left Line 1")
                    .setLine(1),
                makeUpstreamTextNote(factory, duration: "q", text: "Right")
                    .setJustification(.right),
            ]
            _ = voice2.addTickables(notes2.map { $0 as Tickable })

            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)
            try factory.draw()
        }
    }

    @Test("TextNote.TextNote_Formatting_2")
    func textNoteFormatting2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextNote", test: "TextNote_Formatting_2", width: 600, height: 200) { factory, context in
            let stave = factory.Stave(y: 40)

            let voice1 = factory.Voice()
            let notes1: [StaveNote] = try [
                makeUpstreamTextNoteStaveNote(factory, ["g/4"], "16", .up),
                makeUpstreamTextNoteStaveNote(factory, ["g/4"], "16", .up),
                makeUpstreamTextNoteStaveNote(factory, ["g/4"], "16", .up),
                makeUpstreamTextNoteStaveNote(factory, ["g/5"], "16", .down),
                makeUpstreamTextNoteStaveNote(factory, ["g/5"], "16", .down),
                makeUpstreamTextNoteStaveNote(factory, ["g/5"], "16", .down),
                makeUpstreamTextNoteStaveNote(factory, ["g/5", "a/5"], "16", .down),
                makeUpstreamTextNoteStaveNote(factory, ["g/5", "a/5"], "16", .down),
                makeUpstreamTextNoteStaveNote(factory, ["g/5", "a/5"], "16", .down),
                makeUpstreamTextNoteStaveNote(factory, ["g/4", "a/4"], "16", .up),
                makeUpstreamTextNoteStaveNote(factory, ["g/4", "a/4"], "16", .up),
                makeUpstreamTextNoteStaveNote(factory, ["g/4", "a/4"], "16", .up),
                makeUpstreamTextNoteStaveNote(factory, ["g/4", "a/4"], "q", .up),
            ]
            _ = voice1.addTickables(notes1.map { $0 as Tickable })

            let voice2 = factory.Voice()
            let notes2: [TextNote] = try [
                makeUpstreamTextNote(factory, duration: "16", text: "C").setJustification(.center),
                makeUpstreamTextNote(factory, duration: "16", text: "L"),
                makeUpstreamTextNote(factory, duration: "16", text: "R").setJustification(.right),
                makeUpstreamTextNote(factory, duration: "16", text: "C").setJustification(.center),
                makeUpstreamTextNote(factory, duration: "16", text: "L"),
                makeUpstreamTextNote(factory, duration: "16", text: "R").setJustification(.right),
                makeUpstreamTextNote(factory, duration: "16", text: "C").setJustification(.center),
                makeUpstreamTextNote(factory, duration: "16", text: "L"),
                makeUpstreamTextNote(factory, duration: "16", text: "R").setJustification(.right),
                makeUpstreamTextNote(factory, duration: "16", text: "C").setJustification(.center),
                makeUpstreamTextNote(factory, duration: "16", text: "L"),
                makeUpstreamTextNote(factory, duration: "16", text: "R").setJustification(.right),
                makeUpstreamTextNote(factory, duration: "q", text: "R").setJustification(.right),
            ]
            _ = voice2.addTickables(notes2.map { $0 as Tickable })

            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)

            for note in voice2.getTickables() {
                drawUpstreamTextNoteMetrics(context: context, note: note, yPos: 170)
            }

            try factory.draw()
        }
    }

    @Test("TextNote.TextNote_Superscript_and_Subscript")
    func textNoteSuperscriptAndSubscriptMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextNote", test: "TextNote_Superscript_and_Subscript", width: 600, height: 230) { factory, _ in
            let stave = factory.Stave(y: 40)

            let voice1 = factory.Voice()
            let notes1: [StaveNote] = try [
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "e/4", "a/4"], "h", .up)
                    .addModifier(factory.Accidental(type: .flat), index: 0)
                    .addModifier(factory.Accidental(type: .sharp), index: 1),
                makeUpstreamTextNoteStaveNote(factory, ["d/4", "e/4", "f/4"], "q", .up),
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "f/4", "a/4"], "q", .up)
                    .addModifier(factory.Accidental(type: .natural), index: 0)
                    .addModifier(factory.Accidental(type: .sharp), index: 1),
            ]
            _ = voice1.addTickables(notes1.map { $0 as Tickable })

            let flat = "\u{266D}"
            let sharp = "\u{266F}"
            let triangle = "\u{25B3}"
            let oWithSlash = "\u{00F8}"

            let voice2 = factory.Voice()
            let notes2: [TextNote] = try [
                makeUpstreamTextNote(factory, duration: "8", text: "\(flat)I", superscript: "+5"),
                makeUpstreamTextNote(factory, duration: "4d", text: "D\(sharp)/F", superscript: "sus2"),
                makeUpstreamTextNote(factory, duration: "8", text: "ii", superscript: "6", subscriptText: "4"),
                makeUpstreamTextNote(factory, duration: "8", text: "C", superscript: "\(triangle)7", subscriptText: ""),
                makeUpstreamTextNote(factory, duration: "8", text: "vii", superscript: "\(oWithSlash)7"),
                makeUpstreamTextNote(factory, duration: "8", text: "V", superscript: "7"),
            ]
            for note in notes2 {
                _ = note.setFont(FontInfo(family: VexFont.SERIF, size: "15pt"))
                _ = note.setLine(13)
                _ = note.setJustification(.left)
            }
            _ = voice2.addTickables(notes2.map { $0 as Tickable })

            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)
            try factory.draw()
        }
    }

    @Test("TextNote.TextNote_Formatting_With_Glyphs_0")
    func textNoteFormattingWithGlyphs0MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextNote", test: "TextNote_Formatting_With_Glyphs_0", width: 600, height: 230) { factory, _ in
            let stave = factory.Stave(y: 40)

            let voice1 = factory.Voice()
            let notes1: [StaveNote] = try [
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "e/4", "a/4"], "h", .down)
                    .addModifier(factory.Accidental(type: .flat), index: 0)
                    .addModifier(factory.Accidental(type: .sharp), index: 1),
                makeUpstreamTextNoteStaveNote(factory, ["d/4", "e/4", "f/4"], "8", .down),
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "f/4", "a/4"], "8", .down),
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "f/4", "a/4"], "8", .down),
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "f/4", "a/4"], "8", .down),
            ]
            _ = voice1.addTickables(notes1.map { $0 as Tickable })

            let voice2 = factory.Voice()
            let notes2: [TextNote] = try [
                makeUpstreamTextNote(factory, duration: "8", text: "Center").setJustification(.center),
                makeUpstreamTextNote(factory, duration: "8", glyph: "f"),
                makeUpstreamTextNote(factory, duration: "8", glyph: "p"),
                makeUpstreamTextNote(factory, duration: "8", glyph: "m"),
                makeUpstreamTextNote(factory, duration: "8", glyph: "z"),
                makeUpstreamTextNote(factory, duration: "16", glyph: "mordent_upper"),
                makeUpstreamTextNote(factory, duration: "16", glyph: "mordent_lower"),
                makeUpstreamTextNote(factory, duration: "8", glyph: "segno"),
                makeUpstreamTextNote(factory, duration: "8", glyph: "coda"),
            ]
            for note in notes2 {
                _ = note.setJustification(.center)
            }
            _ = voice2.addTickables(notes2.map { $0 as Tickable })

            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)
            try factory.draw()
        }
    }

    @Test("TextNote.TextNote_Formatting_With_Glyphs_1")
    func textNoteFormattingWithGlyphs1MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextNote", test: "TextNote_Formatting_With_Glyphs_1", width: 600, height: 230) { factory, _ in
            let stave = factory.Stave(y: 40)

            let voice1 = factory.Voice()
            let notes1: [StaveNote] = try [
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "e/4", "a/4"], "h", .down)
                    .addModifier(factory.Accidental(type: .flat), index: 0)
                    .addModifier(factory.Accidental(type: .sharp), index: 1),
                makeUpstreamTextNoteStaveNote(factory, ["d/4", "e/4", "f/4"], "8", .down),
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "f/4", "a/4"], "8", .down),
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "f/4", "a/4"], "8", .down),
                makeUpstreamTextNoteStaveNote(factory, ["c/4", "f/4", "a/4"], "8", .down),
            ]
            _ = voice1.addTickables(notes1.map { $0 as Tickable })

            let voice2 = factory.Voice()
            let notes2: [TextNote] = try [
                makeUpstreamTextNote(factory, duration: "16", glyph: "turn"),
                makeUpstreamTextNote(factory, duration: "16", glyph: "turn_inverted"),
                makeUpstreamTextNote(factory, duration: "8", glyph: "pedal_open").setLine(10),
                makeUpstreamTextNote(factory, duration: "8", glyph: "pedal_close").setLine(10),
                makeUpstreamTextNote(factory, duration: "8", glyph: "caesura_curved").setLine(3),
                makeUpstreamTextNote(factory, duration: "8", glyph: "caesura_straight").setLine(3),
                makeUpstreamTextNote(factory, duration: "8", glyph: "breath").setLine(2),
                makeUpstreamTextNote(factory, duration: "8", glyph: "tick").setLine(3),
                makeUpstreamTextNote(factory, duration: "8", glyph: "tr", smooth: true).setJustification(.center),
            ]
            for note in notes2 {
                _ = note.setJustification(.center)
            }
            _ = voice2.addTickables(notes2.map { $0 as Tickable })

            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)
            try factory.draw()
        }
    }

    @Test("TextNote.Crescendo")
    func textNoteCrescendoMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextNote", test: "Crescendo", width: 600, height: 230) { factory, _ in
            let stave = factory.Stave(y: 40)
            let voice = factory.Voice()

            let cresc1 = try makeUpstreamCrescendo(duration: "4d")
                .setLine(0)
                .setHeight(25)
                .setStave(stave)

            let cresc2 = try makeUpstreamCrescendo(duration: "4")
                .setLine(5)
                .setStave(stave)

            let cresc3 = try makeUpstreamCrescendo(duration: "4")
                .setLine(10)
                .setDecrescendo(true)
                .setHeight(5)
                .setStave(stave)

            let notes: [Tickable] = try [
                makeUpstreamTextNote(factory, duration: "16", glyph: "p"),
                cresc1,
                makeUpstreamTextNote(factory, duration: "16", glyph: "f"),
                cresc2,
                cresc3,
            ]
            _ = voice.addTickables(notes)

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("TextNote.Text_Dynamics")
    func textNoteTextDynamicsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextNote", test: "Text_Dynamics", width: 600, height: 230) { factory, context in
            let voice = Voice(time: VoiceTime(numBeats: 7, beatValue: 4))
            let dynamics: [String] = ["sfz", "rfz", "mp", "ppp", "fff", "mf", "sff"]
            let notes: [Tickable] = try dynamics.map { dyn in
                try TextDynamics(validating: TextNoteStruct(duration: .quarter, text: dyn))
            }
            _ = voice.addTickables(notes)

            let formatter = factory.Formatter()
            _ = formatter.joinVoices([voice])
            let width = formatter.preCalculateMinTotalWidth([voice])
            _ = formatter.format([voice])

            let stave = factory.Stave(y: 40, width: width + Stave.defaultPadding)
            _ = stave.setContext(context)
            try stave.draw()
            try voice.draw(context: context, stave: stave)
        }
    }

    private func makeUpstreamTextNoteStaveNote(
        _ factory: Factory,
        _ keys: [String],
        _ duration: String,
        _ stemDirection: StemDirection
    ) throws -> StaveNote {
        try factory.StaveNote(
            StaveNoteStruct(
                parsingKeys: keys,
                duration: duration,
                stemDirection: stemDirection
            )
        )
    }

    private func makeUpstreamTextNote(
        _ factory: Factory,
        duration: String,
        text: String? = nil,
        glyph: String? = nil,
        smooth: Bool? = nil,
        superscript: String? = nil,
        subscriptText: String? = nil
    ) throws -> TextNote {
        factory.TextNote(
            try TextNoteStruct(
                duration: duration,
                text: text,
                glyph: glyph,
                smooth: smooth,
                superscript: superscript,
                subscriptText: subscriptText
            )
        )
    }

    private func makeUpstreamCrescendo(duration: String) throws -> Crescendo {
        Crescendo(try NoteStruct(duration: duration))
    }

    private func drawUpstreamTextNoteMetrics(context: SVGRenderContext, note: Tickable, yPos: Double) {
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
        drawUpstreamTextNoteDot(context: context, x: xAbs + note.getXShift(), y: y, color: "blue")

        let formatterMetrics = note.getFormatterMetrics()
        if formatterMetrics.iterations > 0 {
            let deviation = formatterMetrics.space.deviation
            let prefix = deviation >= 0 ? "+" : ""
            _ = context.setFillStyle("red")
            _ = context.fillText("\(prefix)\(Int(deviation.rounded()))", xAbs + note.getXShift(), yPos - 10)
        }

        _ = context.restore()
    }

    private func drawUpstreamTextNoteDot(context: SVGRenderContext, x: Double, y: Double, color: String = "#F55") {
        _ = context.save()
        _ = context.setFillStyle(color)
        _ = context.beginPath()
        _ = context.arc(x, y, 3, 0, Double.pi * 2, false)
        _ = context.closePath()
        _ = context.fill()
        _ = context.restore()
    }
}
