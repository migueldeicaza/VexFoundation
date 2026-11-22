import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Voice.Full_Voice_Mode_Test")
    func voiceFullVoiceModeTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Voice", test: "Full_Voice_Mode_Test", width: 550, height: 200) { _, context in
            let stave = Stave(x: 10, y: 50, width: 500)
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .setEndBarType(.end)

            let notes = [
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4"], duration: "4")),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "4")),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["r/4"], duration: "4r")),
            ]

            notes.forEach { _ = $0.setStave(stave) }

            let voice = Voice(timeSignature: .meter(4, 4))
                .setMode(.full)
                .addTickables(notes.map { $0 as Tickable })

            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            _ = stave.setContext(context)
            try stave.drawWithStyle()
            try voice.draw(context: context)

            if let bb = voice.getBoundingBox() {
                _ = context.rect(bb.getX(), bb.getY(), bb.getW(), bb.getH())
            }
            _ = context.stroke()
        }
    }
}
