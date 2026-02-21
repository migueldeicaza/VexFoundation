import Testing
@testable import VexFoundation

@Suite("Stave & StaveModifier Parity")
struct StaveModifierParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func makeContext(width: Double = 980, height: Double = 280) -> SVGRenderContext {
        SVGRenderContext(width: width, height: height)
    }

    private func makeNote(
        _ letter: NoteLetter,
        _ octave: Int,
        duration: NoteDurationSpec = .quarter,
        type: NoteType = .note,
        clef: ClefName = .treble
    ) -> StaveNote {
        StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: letter, octave: octave)),
            duration: NoteDurationSpec(uncheckedValue: duration.value, type: type),
            clef: clef
        ))
    }

    private func drawMeasure(
        _ context: SVGRenderContext,
        stave: Stave,
        notes: [StemmableNote]
    ) throws {
        _ = stave.setContext(context)
        try stave.draw()
        _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
    }

    @Test func sortAndOpenStaveParity() {
        let stave = Stave(x: 10, y: 20, width: 420)
        _ = stave.addTimeSignature(.meter(4, 4))
            .addKeySignature("G")
            .addClef(.treble)
            .setEndTimeSignature(.meter(9, 8))
            .setEndKeySignature("D")
            .addEndClef(.bass)
            .setEndBarType(.double)

        stave.format()

        let beginBarlineX = (stave.getModifiers(position: .begin, category: Barline.category).first as? Barline)?.getModifierX()
        let beginClefX = stave.getModifiers(position: .begin, category: Clef.category).first?.getModifierX()
        let beginKeyX = stave.getModifiers(position: .begin, category: KeySignature.category).first?.getModifierX()
        let beginTimeX = stave.getModifiers(position: .begin, category: TimeSignature.category).first?.getModifierX()

        #expect(beginBarlineX != nil)
        #expect(beginClefX != nil)
        #expect(beginKeyX != nil)
        #expect(beginTimeX != nil)
        #expect(beginBarlineX! < beginClefX!)
        #expect(beginClefX! < beginKeyX!)
        #expect(beginKeyX! < beginTimeX!)

        let leftOpen = Stave(x: 10, y: 100, width: 200, options: StaveOptions(leftBar: false, rightBar: true))
        let rightOpen = Stave(x: 220, y: 100, width: 200, options: StaveOptions(leftBar: true, rightBar: false))

        #expect((leftOpen.modifiers[0] as? Barline)?.getBarlineType() == BarlineType.none)
        #expect((leftOpen.modifiers[1] as? Barline)?.getBarlineType() == .single)
        #expect((rightOpen.modifiers[0] as? Barline)?.getBarlineType() == .single)
        #expect((rightOpen.modifiers[1] as? Barline)?.getBarlineType() == BarlineType.none)
    }

    @Test func beginEndModifierMutationParityDraw() throws {
        let context = makeContext(width: 560, height: 280)
        let stave = Stave(x: 10, y: 10, width: 460)
        _ = stave.setContext(context)

        _ = stave.setTimeSignature(.cutTime)
            .setKeySignature("Db")
            .setClef(.treble)
            .setBegBarType(.repeatBegin)
            .setEndClef(.alto)
            .setEndTimeSignature(.meter(9, 8))
            .setEndKeySignature("G", cancelKeySpec: "C#")
            .setEndBarType(.double)

        try stave.draw()

        _ = stave.setStaveY(110)
            .setTimeSignature(.meter(3, 4))
            .setKeySignature("G", cancelKeySpec: "C#")
            .setClef(.bass)
            .setBegBarType(.single)
            .setClef(.treble, position: .end)
            .setTimeSignature(.commonTime, position: .end)
            .setKeySignature("F", position: .end)
            .setEndBarType(.single)

        try stave.draw()

        let beginTime = stave.getModifiers(position: .begin, category: TimeSignature.category).first as? TimeSignature
        let endTime = stave.getModifiers(position: .end, category: TimeSignature.category).first as? TimeSignature
        let beginKey = stave.getModifiers(position: .begin, category: KeySignature.category).first as? KeySignature
        let endKey = stave.getModifiers(position: .end, category: KeySignature.category).first as? KeySignature

        #expect(stave.getClef() == .bass)
        #expect(stave.getEndClef() == .treble)
        #expect((stave.modifiers[0] as? Barline)?.getBarlineType() == .single)
        #expect((stave.modifiers[1] as? Barline)?.getBarlineType() == .single)
        #expect(beginTime?.getTimeSpec() == .meter(3, 4))
        #expect(endTime?.getTimeSpec() == .commonTime)
        #expect(beginKey?.keySpec == "G")
        #expect(endKey?.keySpec == "F")
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func multipleMeasuresAndRepeatsParityDraw() throws {
        let context = makeContext(width: 900, height: 220)

        let stave1 = Stave(x: 10, y: 40, width: 220)
        _ = stave1.setBegBarType(.repeatBegin)
            .setEndBarType(.double)
            .addClef(.treble)
            .addModifier(StaveSection(section: "A", x: stave1.getX(), shiftY: 0, drawRect: false))

        let bar1: [StemmableNote] = [
            makeNote(.c, 4),
            makeNote(.d, 4),
            makeNote(.b, 4, type: .rest),
            StaveNote(StaveNoteStruct(
                keys: NonEmptyArray(
                    StaffKeySpec(letter: .c, octave: 4),
                    StaffKeySpec(letter: .e, octave: 4),
                    StaffKeySpec(letter: .g, octave: 4)
                ),
                duration: .quarter,
                clef: .treble
            ))
        ]
        try drawMeasure(context, stave: stave1, notes: bar1)

        let stave2 = Stave(x: stave1.getX() + stave1.getWidth(), y: stave1.getY(), width: 260)
        _ = stave2.setBegBarType(.repeatBegin)
            .setEndBarType(.repeatEnd)
            .addModifier(StaveSection(section: "B", x: stave2.getX(), shiftY: 0))

        let bar2: [StemmableNote] = [
            makeNote(.c, 4, duration: .eighth),
            makeNote(.d, 4, duration: .eighth),
            makeNote(.g, 4, duration: .eighth),
            makeNote(.e, 4, duration: .eighth),
            makeNote(.c, 4, duration: .eighth),
            makeNote(.d, 4, duration: .eighth),
            makeNote(.g, 4, duration: .eighth),
            makeNote(.e, 4, duration: .eighth),
        ]

        _ = bar2[4].addModifier(Accidental(.sharp), index: 0)
        _ = bar2[5].addModifier(Accidental(.sharp), index: 0)
        _ = bar2[7].addModifier(Accidental(.flat), index: 0)

        try drawMeasure(context, stave: stave2, notes: bar2)

        #expect(stave1.getModifierXShift() > 0)
        #expect(stave2.getModifierXShift() >= 0)
        #expect(stave2.getX() == stave1.getX() + stave1.getWidth())
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func endModifierGridParityDraw() throws {
        let context = makeContext(width: 980, height: 360)
        let endTypes: [BarlineType] = [.single, .double, .repeatEnd, .repeatBoth]

        var x = 10.0
        var y = 20.0
        let width = 220.0

        for (idx, endType) in endTypes.enumerated() {
            let stave = Stave(x: x, y: y, width: width)
            _ = stave.setBegBarType(.repeatBegin)
                .addClef(.treble)
                .addKeySignature(idx.isMultiple(of: 2) ? "A" : "D")
                .setEndBarType(endType)
                .setEndClef(idx.isMultiple(of: 2) ? .bass : .alto)
                .setEndTimeSignature(idx.isMultiple(of: 2) ? .meter(2, 4) : .meter(3, 4))

            if idx.isMultiple(of: 2) {
                _ = stave.setEndKeySignature("E")
            }

            try drawMeasure(context, stave: stave, notes: [
                makeNote(.c, 4),
                makeNote(.d, 4),
                makeNote(.b, 4, type: .rest),
                makeNote(.g, 4),
            ])

            #expect(stave.getNoteEndX() <= stave.getX() + stave.getWidth())
            #expect(stave.getModifiers(position: .end, category: Barline.category).count == 1)

            x += width + 10
            if x + width > 950 {
                x = 10
                y += 140
            }
        }

        #expect(context.getSVG().contains("<svg"))
    }

    @Test func repetitionVoltaTempoAndTextParityDraw() throws {
        let context = makeContext(width: 1180, height: 240)

        let stave1 = Stave(x: 10, y: 40, width: 360)
        _ = stave1.setBegBarType(.repeatBegin)
            .addClef(.treble)
            .addKeySignature("A")
            .setRepetitionType(.segnoLeft)
            .setVoltaType(.beginEnd, number: "1.", yShift: -5)
            .setTempo(StaveTempoOptions(bpm: 80, duration: .quarter, dots: 1), y: 0)
            .setText("Violin", position: .left, options: StaveTextOptions(shiftY: -10))
            .setText("Above Text", position: .above)
            .setSection("A", y: 0, xOffset: 0, fontSize: 10, drawRect: false)

        let stave2 = Stave(x: 390, y: 40, width: 360)
        _ = stave2.setEndBarType(.double)
            .setRepetitionType(.toCoda)
            .setVoltaType(.end, number: "", yShift: -5)
            .setTempo(StaveTempoOptions(bpm: 120, name: "Andante"), y: -16)
            .setText("Right Text", position: .right, options: StaveTextOptions(shiftY: -10))
            .setText("Below Text", position: .below, options: StaveTextOptions(justification: .right))
            .setSection("B", y: 0, xOffset: 0, fontSize: 11)

        try drawMeasure(context, stave: stave1, notes: [makeNote(.c, 4, duration: .whole)])
        try drawMeasure(context, stave: stave2, notes: [makeNote(.d, 4, duration: .whole)])

        #expect(stave1.getModifiers(category: Volta.category).count == 1)
        #expect(stave1.getModifiers(category: StaveRepetition.category).count == 1)
        #expect(stave1.getModifiers(category: StaveTempo.category).count == 1)
        #expect(stave2.getModifiers(category: StaveText.category).count == 2)

        let svg = context.getSVG()
        #expect(svg.contains("Violin"))
        #expect(svg.contains("Andante"))
        #expect(svg.contains("<svg"))
    }

    @Test func stringConvenienceApisThrowOrNil() throws {
        let context = makeContext(width: 680, height: 220)
        let stave = Stave(x: 10, y: 40, width: 620)
        _ = stave.setContext(context).addClef(.treble)

        _ = try stave
            .setRepetitionType(parsing: "to_coda", yShift: 2)
            .setVoltaType(parsing: "begin_end", number: "2.", yShift: -4)
            .setTempo(parsingDuration: "8", bpm: 96, dots: 1, name: "Allegretto", y: -12)
            .setText("Bridge", parsingPosition: "below", shiftY: 10, parsingJustification: "right")

        let badRepetition = stave.setRepetitionType(parsingOrNil: "not-a-repetition")
        let badVolta = stave.setVoltaType(parsingOrNil: "bad", number: "1.", yShift: 0)
        let badTempo = stave.setTempo(parsingDurationOrNil: "bad-duration", bpm: 80, y: 0)
        let badText = stave.setText("X", parsingPositionOrNil: "diagonal", parsingJustificationOrNil: "left")
        #expect(badRepetition == nil)
        #expect(badVolta == nil)
        #expect(badTempo == nil)
        #expect(badText == nil)

        do {
            _ = try stave.setRepetitionType(parsing: "???")
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveError == .invalidRepetitionType("???"))
        }

        do {
            _ = try stave.setVoltaType(parsing: "???", number: "1.", yShift: 0)
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveError == .invalidVoltaType("???"))
        }

        do {
            _ = try stave.setTempo(parsingDuration: "invalid", bpm: 80, y: 0)
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveError == .invalidTempoDuration("invalid"))
        }

        do {
            _ = try stave.setText("X", parsingPosition: "bad", parsingJustification: "left")
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveError == .invalidModifierPosition("bad"))
        }

        try drawMeasure(context, stave: stave, notes: [makeNote(.c, 4, duration: .whole)])
        #expect(context.getSVG().contains("Allegretto"))
        #expect(context.getSVG().contains("Bridge"))
    }
}
