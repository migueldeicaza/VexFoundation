import Testing
@testable import VexFoundation

@Suite("DebugTextNoteMetricsTemp")
struct DebugTextNoteMetricsTemp {
    @Test("dump")
    func dump() throws {
        try Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            FontLoader.loadDefaultFonts()
            _ = try Flow.setMusicFont(parsing: ["Bravura", "Custom"])

            let font = Glyph.MUSIC_FONT_STACK.first!
            print("metric textNote.shiftX=\(font.lookupMetric("glyphs.textNote.shiftX") ?? "nil")")
            print("metric textNote.ornamentTurn.shiftX=\(font.lookupMetric("glyphs.textNote.ornamentTurn.shiftX") ?? "nil")")

            let context = SVGRenderContext(width: 600, height: 230, options: SVGRenderOptions(precision: 3))
            let factory = Factory(options: FactoryOptions(width: 600, height: 230))
            _ = factory.setContext(context)
            let stave = factory.Stave(y: 40)

            let voice1 = factory.Voice()
            let notes1: [StaveNote] = try [
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4"], duration: "h", stemDirection: .down))
                    .addModifier(factory.Accidental(type: .flat), index: 0)
                    .addModifier(factory.Accidental(type: .sharp), index: 1),
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["d/4", "e/4", "f/4"], duration: "8", stemDirection: .down)),
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "f/4", "a/4"], duration: "8", stemDirection: .down)),
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "f/4", "a/4"], duration: "8", stemDirection: .down)),
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "f/4", "a/4"], duration: "8", stemDirection: .down)),
            ]
            _ = voice1.addTickables(notes1.map { $0 as Tickable })

            let voice2 = factory.Voice()
            let notes2: [TextNote] = try [
                factory.TextNote(try TextNoteStruct(duration: "16", glyph: "turn")),
                factory.TextNote(try TextNoteStruct(duration: "16", glyph: "turn_inverted")),
                factory.TextNote(try TextNoteStruct(duration: "8", glyph: "pedal_open")).setLine(10),
                factory.TextNote(try TextNoteStruct(duration: "8", glyph: "pedal_close")).setLine(10),
                factory.TextNote(try TextNoteStruct(duration: "8", glyph: "caesura_curved")).setLine(3),
                factory.TextNote(try TextNoteStruct(duration: "8", glyph: "caesura_straight")).setLine(3),
                factory.TextNote(try TextNoteStruct(duration: "8", glyph: "breath")).setLine(2),
                factory.TextNote(try TextNoteStruct(duration: "8", glyph: "tick")).setLine(3),
                factory.TextNote(try TextNoteStruct(duration: "8", glyph: "tr", smooth: true)).setJustification(.center),
            ]
            for note in notes2 { _ = note.setJustification(.center) }
            _ = voice2.addTickables(notes2.map { $0 as Tickable })

            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)
            for (i, note) in notes2.enumerated() {
                let tc = note.checkTickContext("missing")
                let tcMetrics = tc.getMetrics()
                let glyphMetrics = note.noteGlyph?.getMetrics()
                let glyphW = glyphMetrics?.width ?? -1
                let drawX = note.getAbsoluteX() + tcMetrics.glyphPx / 2 - glyphW / 2
                let moveX = drawX + ((glyphMetrics?.xMin) ?? 0)
                print(
                    "PRE[\(i)] glyph=\(note.noteGlyph?.code ?? "text") just=\(note.justification.rawValue) " +
                        "tickW=\(note.tickableWidth) tcX=\(tc.getX()) absX=\(note.getAbsoluteX()) hasStave=\(note.noteStave != nil) drawX=\(drawX) moveX=\(moveX) " +
                        "tc.glyphPx=\(tcMetrics.glyphPx) tc.modL=\(tcMetrics.modLeftPx) tc.totalL=\(tcMetrics.totalLeftPx)"
                )
            }

            try factory.draw()

            for (i, note) in notes2.enumerated() {
                let tc = note.checkTickContext("missing")
                let tcMetrics = tc.getMetrics()
                let glyphMetrics = note.noteGlyph?.getMetrics()
                let glyphW = glyphMetrics?.width ?? -1
                let drawX = note.getAbsoluteX() + tcMetrics.glyphPx / 2 - glyphW / 2
                let moveX = drawX + ((glyphMetrics?.xMin) ?? 0)
                print(
                    "POST[\(i)] glyph=\(note.noteGlyph?.code ?? "text") just=\(note.justification.rawValue) " +
                        "tickW=\(note.tickableWidth) tcX=\(tc.getX()) absX=\(note.getAbsoluteX()) hasStave=\(note.noteStave != nil) drawX=\(drawX) moveX=\(moveX) " +
                        "tc.glyphPx=\(tcMetrics.glyphPx) tc.modL=\(tcMetrics.modLeftPx) tc.totalL=\(tcMetrics.totalLeftPx)"
                )
            }

            let has66 = context.getSVG().contains("M 66.168 41.183")
            print("HAS66=\(has66)")
        }
    }

    @Test("formatter_mixed_metrics")
    func formatterMixedMetrics() throws {
        try Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            FontLoader.loadDefaultFonts()
            _ = try Flow.setMusicFont(parsing: ["Bravura", "Custom"])

            let context = SVGRenderContext(width: 800, height: 500, options: SVGRenderOptions(precision: 3))
            let stave = Stave(x: 10, y: 200, width: 400)
            let staveB = Stave(x: 410, y: 200, width: 400)
            _ = stave.setContext(context)
            _ = staveB.setContext(context)

            let note0 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8"))
                .addModifier(Accidental(.doubleSharp), index: 0)
                .addModifier(FretHandFinger("4").setPosition(.below), index: 0)
                .addModifier(StringNumber("3").setPosition(.below), index: 0)
                .addModifier(Articulation("a.").setPosition(.below), index: 0)
                .addModifier(Articulation("a>").setPosition(.below), index: 0)
                .addModifier(Articulation("a^").setPosition(.below), index: 0)
                .addModifier(Articulation("am").setPosition(.below), index: 0)
                .addModifier(Articulation("a@u").setPosition(.below), index: 0)
                .addModifier(Annotation("yyyy").setVerticalJustification(.bottom), index: 0)
                .addModifier(Annotation("xxxx").setVerticalJustification(.bottom).setFont(FontInfo(family: VexFont.SANS_SERIF, size: 20)), index: 0)
                .addModifier(Annotation("ttt").setVerticalJustification(.bottom).setFont(FontInfo(family: VexFont.SANS_SERIF, size: 20)), index: 0)

            let note1 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8", stemDirection: .down))
                .addModifier(StringNumber("3").setPosition(.below), index: 0)
                .addModifier(Articulation("a.").setPosition(.below), index: 0)
                .addModifier(Articulation("a>").setPosition(.below), index: 0)

            let note2 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8"))
            let notes = [note0, note1, note2]

            let note3 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8"))
                .addModifier(StringNumber("3").setPosition(.above), index: 0)
                .addModifier(Articulation("a.").setPosition(.above), index: 0)
                .addModifier(Annotation("yyyy").setVerticalJustification(.top), index: 0)
            let note4 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8", stemDirection: .down))
                .addModifier(FretHandFinger("4").setPosition(.above), index: 0)
                .addModifier(StringNumber("3").setPosition(.above), index: 0)
                .addModifier(Articulation("a.").setPosition(.above), index: 0)
                .addModifier(Articulation("a>").setPosition(.above), index: 0)
                .addModifier(Articulation("a^").setPosition(.above), index: 0)
                .addModifier(Articulation("am").setPosition(.above), index: 0)
                .addModifier(Articulation("a@u").setPosition(.above), index: 0)
                .addModifier(Annotation("yyyy").setVerticalJustification(.top), index: 0)
                .addModifier(Annotation("xxxx").setVerticalJustification(.top).setFont(FontInfo(family: VexFont.SANS_SERIF, size: 20)), index: 0)
                .addModifier(Annotation("ttt").setVerticalJustification(.top).setFont(FontInfo(family: VexFont.SANS_SERIF, size: 20)), index: 0)
            let note5 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8"))
            let notesB = [note3, note4, note5]

            _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            _ = try Formatter.FormatAndDraw(ctx: context, stave: staveB, notes: notesB)
            try stave.draw()
            try staveB.draw()

            print("stave.noteStartX=\(stave.getNoteStartX())")
            for (i, n) in notes.enumerated() {
                let tc = n.checkTickContext("missing tc")
                let tcMetrics = tc.getMetrics()
                let nm = n.getMetrics()
                let mcState = n.modifierContext?.getState()
                print(
                    """
                    note[\(i)] absX=\(n.getAbsoluteX()) tcX=\(tc.getX()) tc.width=\(tc.getWidth()) \
                    tc.totalL=\(tcMetrics.totalLeftPx) tc.totalR=\(tcMetrics.totalRightPx) \
                    note.modL=\(nm.modLeftPx) note.modR=\(nm.modRightPx) note.notePx=\(nm.notePx) \
                    mc.left=\(mcState?.leftShift ?? -1) mc.right=\(mcState?.rightShift ?? -1) \
                    mc.text=\(mcState?.textLine ?? -1) mc.top=\(mcState?.topTextLine ?? -1)
                    """
                )
            }

            let accidental = note0.getModifiers().compactMap { $0 as? Accidental }.first
            if let accidental {
                print("accidental.width=\(accidental.getWidth()) xShift=\(accidental.getXShift())")
            }
            let anns = note0.getModifiersByType("Annotation").compactMap { $0 as? Annotation }
            for (i, ann) in anns.enumerated() {
                let tf = TextFormatter.create(font: ann.fontInfo)
                let w = tf.getWidthForTextInPx(ann.text)
                let h = tf.getYForStringInPx(ann.text).height
                print("ann[\(i)] text=\(ann.text) font=\(String(describing: ann.fontInfo)) width=\(w) height=\(h)")
            }
            var s = ModifierContextState()
            func dump(_ label: String) {
                print("step \(label) left=\(s.leftShift) right=\(s.rightShift) text=\(s.textLine) top=\(s.topTextLine)")
            }
            _ = StaveNote.format([note0], state: &s)
            dump("StaveNote")
            _ = Parenthesis.format(note0.getModifiersByType("Parenthesis").compactMap { $0 as? Parenthesis }, state: &s)
            dump("Parenthesis")
            _ = Dot.format(note0.getModifiersByType("Dot").compactMap { $0 as? Dot }, state: &s)
            dump("Dot")
            _ = FretHandFinger.format(note0.getModifiersByType("FretHandFinger").compactMap { $0 as? FretHandFinger }, state: &s)
            dump("FretHandFinger")
            _ = Accidental.format(note0.getModifiersByType("Accidental").compactMap { $0 as? Accidental }, state: &s)
            dump("Accidental")
            _ = Stroke.format(note0.getModifiersByType("Stroke").compactMap { $0 as? Stroke }, state: &s)
            dump("Stroke")
            _ = GraceNoteGroup.format(note0.getModifiersByType("GraceNoteGroup").compactMap { $0 as? GraceNoteGroup }, state: &s)
            dump("GraceNoteGroup")
            _ = NoteSubGroup.format(note0.getModifiersByType("NoteSubGroup").compactMap { $0 as? NoteSubGroup }, state: &s)
            dump("NoteSubGroup")
            _ = try? StringNumber.formatThrowing(note0.getModifiersByType("StringNumber").compactMap { $0 as? StringNumber }, state: &s)
            dump("StringNumber")
            _ = Articulation.format(note0.getModifiersByType("Articulation").compactMap { $0 as? Articulation }, state: &s)
            dump("Articulation")
            _ = Annotation.format(note0.getModifiersByType("Annotation").compactMap { $0 as? Annotation }, state: &s)
            dump("Annotation")
            _ = ChordSymbol.format(note0.getModifiersByType("ChordSymbol").compactMap { $0 as? ChordSymbol }, state: &s)
            dump("ChordSymbol")
            _ = Bend.format(note0.getModifiersByType("Bend").compactMap { $0 as? Bend }, state: &s)
            dump("Bend")
            for (i, n) in notesB.enumerated() {
                if n.modifierContext == nil { continue }
                let mc = n.modifierContext!.getState()
                let tc = n.checkTickContext("missing")
                print("notesB[\(i)] absX=\(n.getAbsoluteX()) tcX=\(tc.getX()) mc.left=\(mc.leftShift) mc.right=\(mc.rightShift) mc.text=\(mc.textLine) mc.top=\(mc.topTextLine)")
            }
            let font = Glyph.MUSIC_FONT_STACK.first
            let m1 = font?.lookupMetric("accidental.noteheadAccidentalPadding")
            let m2 = font?.lookupMetric("accidental.accidentalSpacing")
            let m3 = font?.lookupMetric("accidental.leftPadding")
            let m4 = font?.lookupMetric("stave.padding")
            print("metric accidental.noteheadAccidentalPadding=\(String(describing: m1))")
            print("metric accidental.accidentalSpacing=\(String(describing: m2))")
            print("metric accidental.leftPadding=\(String(describing: m3))")
            print("metric stave.padding=\(String(describing: m4))")
        }
    }
}
