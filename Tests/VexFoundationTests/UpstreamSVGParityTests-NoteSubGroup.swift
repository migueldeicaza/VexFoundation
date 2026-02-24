import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("NoteSubGroup.Basic___ClefNote__TimeSigNote_and_BarNote")
    func noteSubGroupBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "NoteSubGroup",
            test: "Basic___ClefNote__TimeSigNote_and_BarNote",
            width: 750,
            height: 200
        ) { factory, context in
            let stave = factory.Stave(width: 600).addClef(.treble)

            let notes: [StaveNote] = try [
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "f/5", stemDirection: .down),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "d/4", stemDirection: .down, clef: .bass),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "g/4", stemDirection: .down, clef: .alto),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "a/4", stemDirection: .down, clef: .alto),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/4", stemDirection: .down, clef: .tenor),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/3", stemDirection: .up, clef: .tenor),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "d/4", stemDirection: .down, clef: .tenor),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "f/4", stemDirection: .down, clef: .tenor),
            ]

            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes[1], type: "#")
            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes[2], type: "n")
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes[1],
                subNotes: [factory.ClefNote(type: .bass, size: .small)]
            )
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes[2],
                subNotes: [factory.ClefNote(type: .alto, size: .small)]
            )
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes[4],
                subNotes: [factory.ClefNote(type: .tenor, size: .small), factory.BarNote()]
            )
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes[5],
                subNotes: [factory.TimeSigNote(time: .meter(6, 8))]
            )
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes[6],
                subNotes: [factory.BarNote(type: .repeatBegin)]
            )
            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes[4], type: "b")
            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes[6], type: "bb")

            let voice = factory.Voice().setStrict(false).addTickables(notes.map { $0 as Tickable })
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()

            for note in notes {
                Note.plotMetrics(ctx: context, note: note, yPos: 150)
            }
            plotUpstreamLegendForNoteWidth(context: context, x: 620, y: 120)
        }
    }

    @Test("NoteSubGroup.Multi_Voice")
    func noteSubGroupMultiVoiceMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "NoteSubGroup", test: "Multi_Voice", width: 550, height: 200) { factory, context in
            try drawUpstreamNoteSubGroupMultiVoice(factory: factory, context: context, drawCount: 1)
        }
    }

    @Test("NoteSubGroup.Multi_Voice_Multiple_Draws")
    func noteSubGroupMultiVoiceMultipleDrawsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "NoteSubGroup",
            test: "Multi_Voice_Multiple_Draws",
            width: 550,
            height: 200
        ) { factory, context in
            try drawUpstreamNoteSubGroupMultiVoice(factory: factory, context: context, drawCount: 2)
        }
    }

    @Test("NoteSubGroup.Multi_Staff")
    func noteSubGroupMultiStaffMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "NoteSubGroup", test: "Multi_Staff", width: 550, height: 400) { factory, _ in
            let stave1 = factory.Stave(x: 15, y: 30, width: 500).setClef(.treble)
            let notes1: [StaveNote] = try [
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "f/5", stemDirection: .up),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "d/4", stemDirection: .up, clef: .bass),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/5", stemDirection: .up, clef: .alto),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/5", stemDirection: .up, clef: .soprano),
            ]

            let notes2: [StaveNote] = try [
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/4", stemDirection: .down),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/3", stemDirection: .down, clef: .bass),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "d/4", stemDirection: .down, clef: .alto),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "f/4", stemDirection: .down, clef: .soprano),
            ]

            let stave2 = factory.Stave(x: 15, y: 150, width: 500).setClef(.bass)
            let notes3: [StaveNote] = try [
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "e/3", duration: "8", stemDirection: .down, clef: .bass),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "g/4", duration: "8", stemDirection: .up, clef: .treble),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "d/4", duration: "8", stemDirection: .up, clef: .treble),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "f/4", duration: "8", stemDirection: .up, clef: .treble),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/4", duration: "8", stemDirection: .up, clef: .treble),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "g/3", duration: "8", stemDirection: .down, clef: .bass),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "d/3", duration: "8", stemDirection: .down, clef: .bass),
                makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "f/3", duration: "8", stemDirection: .down, clef: .bass),
            ]

            _ = factory.StaveConnector(topStave: stave1, bottomStave: stave2, type: .brace)
            _ = factory.StaveConnector(topStave: stave1, bottomStave: stave2, type: .singleLeft)
            _ = factory.StaveConnector(topStave: stave1, bottomStave: stave2, type: .singleRight)

            _ = factory.Beam(notes: Array(notes3[1..<4]))
            _ = factory.Beam(notes: Array(notes3[5..<8]))

            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes1[1], type: "#")
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes1[1],
                subNotes: [
                    factory.ClefNote(type: .bass, size: .small),
                    factory.TimeSigNote(time: .meter(3, 4)),
                ]
            )
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes2[2],
                subNotes: [
                    factory.ClefNote(type: .alto, size: .small),
                    factory.TimeSigNote(time: .meter(9, 8)),
                ]
            )
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes1[3],
                subNotes: [factory.ClefNote(type: .soprano, size: .small)]
            )
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes3[1],
                subNotes: [factory.ClefNote(type: .treble, size: .small)]
            )
            try addUpstreamNoteSubGroup(
                factory: factory,
                to: notes3[5],
                subNotes: [factory.ClefNote(type: .bass, size: .small)]
            )

            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes3[0], type: "#")
            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes3[3], type: "b")
            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes3[5], type: "#")
            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes1[2], type: "b")
            try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes2[3], type: "#")

            let voice1 = factory.Voice().addTickables(notes1.map { $0 as Tickable })
            let voice2 = factory.Voice().addTickables(notes2.map { $0 as Tickable })
            let voice3 = factory.Voice().addTickables(notes3.map { $0 as Tickable })
            _ = factory.Formatter()
                .joinVoices([voice1, voice2])
                .joinVoices([voice3])
                .formatToStave([voice1, voice2, voice3], stave: stave1)
            _ = voice3.setStave(stave2)

            try factory.draw()
        }
    }

    private func drawUpstreamNoteSubGroupMultiVoice(factory: Factory, context: RenderContext, drawCount: Int) throws {
        let stave = factory.Stave().addClef(.treble)

        let notes1: [StaveNote] = try [
            makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "f/5", stemDirection: .up),
            makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "d/4", stemDirection: .up, clef: .bass),
            makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/5", stemDirection: .up, clef: .alto),
            makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/5", stemDirection: .up, clef: .soprano),
        ]

        let notes2: [StaveNote] = try [
            makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/4", stemDirection: .down),
            makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "c/3", stemDirection: .down, clef: .bass),
            makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "d/4", stemDirection: .down, clef: .alto),
            makeUpstreamNoteSubGroupStaveNote(factory: factory, key: "f/4", stemDirection: .down, clef: .soprano),
        ]

        try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes1[1], type: "#")
        try addUpstreamNoteSubGroup(
            factory: factory,
            to: notes1[1],
            subNotes: [
                factory.ClefNote(type: .bass, size: .small),
                factory.BarNote(type: .repeatBegin),
                factory.TimeSigNote(time: .meter(3, 4)),
            ]
        )
        try addUpstreamNoteSubGroup(
            factory: factory,
            to: notes2[2],
            subNotes: [
                factory.ClefNote(type: .alto, size: .small),
                factory.TimeSigNote(time: .meter(9, 8)),
                factory.BarNote(type: .double),
            ]
        )
        try addUpstreamNoteSubGroup(
            factory: factory,
            to: notes1[3],
            subNotes: [factory.ClefNote(type: .soprano, size: .small)]
        )
        try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes1[2], type: "b")
        try addUpstreamNoteSubGroupAccidental(factory: factory, to: notes2[3], type: "#")

        let voices = [
            factory.Voice().addTickables(notes1.map { $0 as Tickable }),
            factory.Voice().addTickables(notes2.map { $0 as Tickable }),
        ]
        _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)

        for _ in 0..<drawCount {
            try factory.draw()
        }

        for note in notes1 {
            Note.plotMetrics(ctx: context, note: note, yPos: 150)
        }
    }

    private func makeUpstreamNoteSubGroupStaveNote(
        factory: Factory,
        key: String,
        duration: String = "4",
        stemDirection: StemDirection,
        clef: ClefName? = nil
    ) throws -> StaveNote {
        factory.StaveNote(try StaveNoteStruct(
            parsingKeys: [key],
            duration: duration,
            stemDirection: stemDirection,
            clef: clef
        ))
    }

    private func addUpstreamNoteSubGroupAccidental(
        factory: Factory,
        to note: StaveNote,
        type: String
    ) throws {
        _ = note.addModifier(try factory.Accidental(parsing: type), index: 0)
    }

    private func addUpstreamNoteSubGroup(
        factory: Factory,
        to note: StaveNote,
        subNotes: [Note]
    ) throws {
        _ = note.addModifier(factory.NoteSubGroup(notes: subNotes), index: 0)
    }

    private func plotUpstreamLegendForNoteWidth(context: RenderContext, x: Double, y: Double) {
        _ = context.save()
        _ = context.setFont(VexFont.SANS_SERIF, 8, nil, nil)

        let spacing: Double = 12
        var lastY = y
        func legend(_ color: String, _ text: String) {
            _ = context.beginPath()
            _ = context.setStrokeStyle(color)
            _ = context.setFillStyle(color)
            _ = context.setLineWidth(10)
            _ = context.moveTo(x, lastY - 4)
            _ = context.lineTo(x + 10, lastY - 4)
            _ = context.stroke()

            _ = context.setFillStyle("black")
            _ = context.fillText(text, x + 15, lastY)
            lastY += spacing
        }

        legend("green", "Note + Flag")
        legend("red", "Modifiers")
        legend("#999", "Displaced Head")
        legend("#DDD", "Formatter Shift")

        _ = context.restore()
    }
}
