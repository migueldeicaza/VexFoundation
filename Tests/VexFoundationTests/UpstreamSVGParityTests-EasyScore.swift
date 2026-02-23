import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("EasyScore.Draw_Basic")
    func easyScoreDrawBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Basic", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q, c4/q, c4/q/r, c4/q", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c#5/h., c5/q", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let lower = score.voice(
                score.notes("c#3/q, cn3/q, bb3/q, d##3/q", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [lower])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Different_KeySignature")
    func easyScoreDrawDifferentKeySignatureMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Different_KeySignature", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q, c4/q, c4/q/r, c4/q", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c5/h., c5/q", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice]))
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .addKeySignature("D")

            let lower = score.voice(
                score.notes("c#3/q, cn3/q, bb3/q, d##3/q", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [lower]))
                .addClef(.bass)
                .addTimeSignature(.meter(4, 4))
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Accidentals")
    func easyScoreDrawAccidentalsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Accidentals", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(cbbs4 ebb4 gbss4)/q, cbs4/q, cdb4/q/r, cd4/q", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c++-5/h., c++5/q", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let lower = score.voice(
                score.notes("c+-3/q, c+3/q, bb3/q, d##3/q", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [lower])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Basic_Muted")
    func easyScoreDrawBasicMutedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Basic_Muted", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q/m, c4/q/m, c4/q/r, c4/q/m", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c#5/h/m., c5/q/m", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let bassVoice = score.voice(
                score.notes("c#3/q/m, cn3/q/m, bb3/q/m, d##3/q/m", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [bassVoice])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Basic_Harmonic")
    func easyScoreDrawBasicHarmonicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Basic_Harmonic", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q/h, c4/q/h, c4/q/r, c4/q/h", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c#5/h/h., c5/q/h", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let bassVoice = score.voice(
                score.notes("c#3/q/h, cn3/q/h, bb3/q/h, d##3/q/h", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [bassVoice])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Basic_Slash")
    func easyScoreDrawBasicSlashMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Basic_Slash", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q/s, c4/q/s, c4/q/r, c4/q/s", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c#5/h/s., c5/q/s", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let bassVoice = score.voice(
                score.notes("c#3/q/s, cn3/q/s, bb3/q/s, d##3/q/s", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [bassVoice])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Beams")
    func easyScoreDrawBeamsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Beams", width: 600, height: 250) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let lower = score.notes("(c4 e4 g4)/q, c4/q, c4/q/r, c4/q", options: ["stem": "down"])
            let upper = score.notes("c#5/h.", options: ["stem": "up"])
                + score.beam(score.notes("c5/8, c5/8", options: ["stem": "up"]))

            let lowerVoice = score.voice(lower.map { $0 as Note })
            let upperVoice = score.voice(upper.map { $0 as Note })
            _ = system.addStave(SystemStave(voices: [lowerVoice, upperVoice])).addClef(.treble)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Dots")
    func easyScoreDrawDotsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Dots", width: 600, height: 250) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let voice = score.voice(
                score.notes("(c4 e4 g4)/8., (c4 e4 g4)/8.., (c4 e4 g4)/8..., (c4 e4 g4)/8...., (c4 e4 g4)/16...")
                    .map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [voice])).addClef(.treble)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Ghostnote_Basic")
    func easyScoreDrawGhostnoteBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Ghostnote_Basic", width: 550, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperNotes = score.notes("f#5/4, f5, db5, c5", options: ["stem": "up"])
                + score.beam(score.notes("c5/8, d5, fn5, e5", options: ["stem": "up"]))
                + score.beam(score.notes("d5, c5", options: ["stem": "up"]))
            let upperVoice = score.voice(upperNotes.map { $0 as Note }, time: .meter(7, 4))

            let lowerNotes = score.notes(
                "c4/h/g, f4/4, c4/4/g, e4/4, c4/8/g, d##4/8, c4/8, c4/8",
                options: ["stem": "down"]
            )
            let lowerVoice = score.voice(lowerNotes.map { $0 as Note }, time: .meter(7, 4))
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice]))

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Ghostnote_Dotted")
    func easyScoreDrawGhostnoteDottedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Ghostnote_Dotted", width: 550, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperNotes = score.notes("c4/4/g., fbb5/8, d5/4", options: ["stem": "up"])
                + score.beam(score.notes("c5/8, c#5/16, d5/16", options: ["stem": "up"]))
                + score.notes("c4/2/g.., fn5/8", options: ["stem": "up"])
            let upperVoice = score.voice(upperNotes.map { $0 as Note }, time: .meter(8, 4))

            let lowerNotes = score.notes("f#4/4", options: ["stem": "down"])
                + score.beam(score.notes("e4/8, d4/8", options: ["stem": "down"]))
                + score.notes("c4/4/g.., cb4/16, c#4/h, d4/4", options: ["stem": "down"])
                + score.beam(score.notes("fn4/8, e4/8", options: ["stem": "down"]))
            let lowerVoice = score.voice(lowerNotes.map { $0 as Note }, time: .meter(8, 4))
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice]))

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Parenthesised")
    func easyScoreDrawParenthesisedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Parenthesised", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let notes1 = score.notes("(d4 e4 g4)/q, c4/q, c4/q/r, c4/q", options: ["stem": "down"])
            Parenthesis.buildAndAttach([notes1[0] as Note, notes1[3] as Note])

            let notes2 = score.notes("c#5/h., c5/q", options: ["stem": "down"])
            Parenthesis.buildAndAttach([notes2[0] as Note, notes2[1] as Note])

            _ = system.addStave(SystemStave(voices: [
                score.voice(notes1.map { $0 as Note }),
                score.voice(notes2.map { $0 as Note }),
            ])).addClef(.treble)

            let notes3 = score.notes("c#3/q, cn3/q, bb3/q, d##3/q", options: ["stem": "down"])
            Parenthesis.buildAndAttach(notes3.map { $0 as Note })
            _ = system.addStave(SystemStave(voices: [score.voice(notes3.map { $0 as Note })])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Options")
    func easyScoreDrawOptionsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Options", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let notes = score.notes(
                "B4/h[id=\"foobar\", class=\"red,bold\", stem=\"up\", articulations=\"staccato.below,tenuto\"], " +
                    "B4/q[articulations=\"accent.above\"], B4/q[stem=\"down\"]"
            )
            _ = system.addStave(SystemStave(voices: [score.voice(notes.map { $0 as Note })]))

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Fingerings")
    func easyScoreDrawFingeringsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Fingerings", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let notes = score.notes(
                "C4/q[fingerings=\"1\"], E4[fingerings=\"3.above\"], G4[fingerings=\"5.below\"], " +
                    "(C4 E4 G4)[fingerings=\"1,3,5\"]"
            )
            _ = system.addStave(SystemStave(voices: [score.voice(notes.map { $0 as Note })]))

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Tuplets")
    func easyScoreDrawTupletsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Tuplets", width: 600, height: 250) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let lowerTuplet = score.tuplet(
                score.notes("(c4 e4 g4)/q, cbb4/q, c4/q", options: ["stem": "down"]),
                options: TupletOptions(location: .bottom)
            )
            let lowerHalf = score.notes("c4/h", options: ["stem": "down"])
            let lowerVoice = score.voice((lowerTuplet + lowerHalf).map { $0 as Note })

            let upperHalf = score.notes("c#5/h.", options: ["stem": "up"])
            let upperTuplet = score.tuplet(
                score.beam(score.notes("cb5/8, cn5/8, c5/8", options: ["stem": "up"]))
            )
            let upperVoice = score.voice((upperHalf + upperTuplet).map { $0 as Note })

            _ = system.addStave(SystemStave(voices: [lowerVoice, upperVoice])).addClef(.treble)

            try factory.draw()
        }
    }

    @Test("EasyScore.Keys")
    func easyScoreKeysMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Keys", width: 700, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let notes = score.notes(
                "c#3/q, c##3, cb3, cbb3, cn3, c3, cbbs3, cbss3, cbs3, cdb3, cd3, c++-3, c++3, c+-3, c+3, co3, ck3",
                options: ["clef": "bass"]
            )
            let voice = factory.Voice()
                .setStrict(false)
                .addTickables(notes.map { $0 as Tickable })
            _ = system.addStave(SystemStave(voices: [voice])).addClef(.bass)

            try factory.draw()
        }
    }
}
