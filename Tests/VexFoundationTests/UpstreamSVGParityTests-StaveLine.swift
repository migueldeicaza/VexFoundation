import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("StaveLine.Simple_StaveLine")
    func staveLineSimpleStaveLineMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveLine", test: "Simple_StaveLine", width: 450, height: 140) {
            factory,
            _ in
            let stave = factory.Stave().addClef(.treble)

            let notes: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .treble)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", clef: .treble)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4", "g/4", "b/4"], duration: "4", clef: .treble)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4", "a/4", "f/5"], duration: "4", clef: .treble)),
            ]

            let voice = factory.Voice().addTickables(notes.map { $0 as Tickable })

            _ = factory.StaveLine(
                notes: StaveLineNotes(
                    firstNote: notes[0],
                    firstIndices: [0],
                    lastNote: notes[1],
                    lastIndices: [0]
                ),
                text: "gliss.",
                font: FontInfo(family: VexFont.SERIF, size: 12, style: VexFontStyle.italic.rawValue)
            )

            let staveLine2 = factory.StaveLine(
                notes: StaveLineNotes(
                    firstNote: notes[2],
                    firstIndices: [2, 1, 0],
                    lastNote: notes[3],
                    lastIndices: [0, 1, 2]
                )
            )
            staveLine2.lineRenderOptions.lineDash = [10, 10]

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("StaveLine.StaveLine_Arrow_Options")
    func staveLineArrowOptionsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveLine", test: "StaveLine_Arrow_Options", width: 770, height: 140) {
            factory,
            _ in
            let stave = factory.Stave().addClef(.treble)

            let notes: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c#/5", "d/5"], duration: "4", stemDirection: .down, clef: .treble)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .treble))
                    .addModifier(factory.Accidental(type: .sharp), index: 0),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4", "e/4", "g/4"], duration: "4", clef: .treble)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4", "a/4", "c/5"], duration: "4", clef: .treble))
                    .addModifier(factory.Accidental(type: .sharp), index: 2),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .treble))
                    .addModifier(factory.Accidental(type: .sharp), index: 0),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c#/5", "d/5"], duration: "4", stemDirection: .down, clef: .treble)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4", "d/4", "g/4"], duration: "4", clef: .treble)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4", "a/4", "c/5"], duration: "4", clef: .treble))
                    .addModifier(factory.Accidental(type: .sharp), index: 2),
            ]

            Dot.buildAndAttach([notes[0] as Note], all: true)

            let voice = factory.Voice().setStrict(false).addTickables(notes.map { $0 as Tickable })

            let staveLine0 = factory.StaveLine(
                notes: StaveLineNotes(firstNote: notes[0], firstIndices: [0], lastNote: notes[1], lastIndices: [0]),
                text: "Left"
            )
            let staveLine4 = factory.StaveLine(
                notes: StaveLineNotes(firstNote: notes[2], firstIndices: [1], lastNote: notes[3], lastIndices: [1]),
                text: "Right"
            )
            let staveLine1 = factory.StaveLine(
                notes: StaveLineNotes(firstNote: notes[4], firstIndices: [0], lastNote: notes[5], lastIndices: [0]),
                text: "Center"
            )
            let staveLine2 = factory.StaveLine(
                notes: StaveLineNotes(firstNote: notes[6], firstIndices: [1], lastNote: notes[7], lastIndices: [0])
            )
            let staveLine3 = factory.StaveLine(
                notes: StaveLineNotes(firstNote: notes[6], firstIndices: [2], lastNote: notes[7], lastIndices: [2]),
                text: "Top"
            )

            staveLine0.lineRenderOptions.drawEndArrow = true
            staveLine0.lineRenderOptions.textJustification = .left
            staveLine0.lineRenderOptions.textPositionVertical = .bottom

            staveLine1.lineRenderOptions.drawEndArrow = true
            staveLine1.lineRenderOptions.arrowheadLength = 30
            staveLine1.lineRenderOptions.lineWidth = 5
            staveLine1.lineRenderOptions.textJustification = .center
            staveLine1.lineRenderOptions.textPositionVertical = .bottom

            staveLine4.lineRenderOptions.lineWidth = 2
            staveLine4.lineRenderOptions.drawEndArrow = true
            staveLine4.lineRenderOptions.drawStartArrow = true
            staveLine4.lineRenderOptions.arrowheadAngle = 0.5
            staveLine4.lineRenderOptions.arrowheadLength = 20
            staveLine4.lineRenderOptions.textJustification = .right
            staveLine4.lineRenderOptions.textPositionVertical = .bottom

            staveLine2.lineRenderOptions.drawStartArrow = true
            staveLine2.lineRenderOptions.lineDash = [5, 4]

            staveLine3.lineRenderOptions.drawEndArrow = true
            staveLine3.lineRenderOptions.drawStartArrow = true
            staveLine3.lineRenderOptions.color = "red"
            staveLine3.lineRenderOptions.textPositionVertical = .top

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }
}
