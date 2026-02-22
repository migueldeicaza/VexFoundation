import Foundation
import Testing
@testable import VexFoundation

@Suite("Upstream SVG Parity (Opt-In)")
struct UpstreamSVGParityTests {
    private enum UpstreamSVGParityError: Error {
        case unsupportedFont(String)
        case invalidTimeSignatureSpec(String)
    }

    private static let enableEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_PARITY"
    private static let referenceDirEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_REFERENCE_DIR"
    private static let fontsEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_FONTS"
    private static let artifactsDirEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_ARTIFACTS_DIR"
    private static let signatureEpsilonEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_SIGNATURE_EPSILON"

    private let defaultFonts = ["Bravura", "Gonville", "Petaluma", "Leland"]

    @Test("Barline.Simple_BarNotes")
    func barlineSimpleBarNotesMatchesUpstream() throws {
        try runSVGParityCase(module: "Barline", test: "Simple_BarNotes", width: 380, height: 160) { factory, _ in
            let stave = factory.Stave()
            let noteA = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["d/4", "e/4", "f/4"],
                duration: "2",
                stemDirection: .down
            ))
            let bar = factory.BarNote(type: .single)
            let noteB = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["c/4", "f/4", "a/4"],
                duration: "2",
                stemDirection: .down
            ))
            _ = noteB.addModifier(factory.Accidental(type: .natural), index: 0)
            _ = noteB.addModifier(factory.Accidental(type: .sharp), index: 1)

            let voice = factory.Voice()
            _ = voice.addTickables([noteA, bar, noteB])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Barline.Style_BarNotes")
    func barlineStyleBarNotesMatchesUpstream() throws {
        try runSVGParityCase(module: "Barline", test: "Style_BarNotes", width: 380, height: 160) { factory, _ in
            let stave = factory.Stave()
            let noteA = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["d/4", "e/4", "f/4"],
                duration: "2",
                stemDirection: .down
            ))
            let bar = factory.BarNote(type: .single)
            let noteB = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["c/4", "f/4", "a/4"],
                duration: "2",
                stemDirection: .down
            ))
            _ = noteB.addModifier(factory.Accidental(type: .natural), index: 0)
            _ = noteB.addModifier(factory.Accidental(type: .sharp), index: 1)
            _ = bar.setStyle(ElementStyle(
                shadowColor: "blue",
                shadowBlur: 15,
                fillStyle: "blue",
                strokeStyle: "blue"
            ))

            let voice = factory.Voice()
            _ = voice.addTickables([noteA, bar, noteB])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Auto_Beaming.Simple_Auto_Beaming")
    func autoBeamingSimpleAutoBeamingMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Simple_Auto_Beaming", width: 450, height: 140) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("f5/8, e5, d5, c5/16, c5, d5/8, e5, f5, f5/32, f5, f5, f5"),
                time: .meter(4, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Auto_Beaming_With_Overflow_Group")
    func autoBeamingWithOverflowGroupMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Auto_Beaming_With_Overflow_Group",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("f5/4., e5/8, d5/8, d5/16, c5/16, c5/16, c5/16, f5/16, f5/32, f5/32"),
                time: .meter(4, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Even_Group_Stem_Directions")
    func autoBeamingEvenGroupStemDirectionsMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Even_Group_Stem_Directions",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("a4/8, b4, g4, c5, f4, d5, e4, e5, b4, b4, g4, d5"),
                time: .meter(6, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Odd_Group_Stem_Directions")
    func autoBeamingOddGroupStemDirectionsMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Odd_Group_Stem_Directions",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("g4/8, b4, d5, c5, f4, d5, e4, g5, g4, b4, g4, d5, a4, c5, a4"),
                time: .meter(15, 8)
            )
            let beams = try Beam.applyAndGetBeams(voice, groups: [Fraction(3, 8)])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Odd_Beam_Groups_Auto_Beaming")
    func autoBeamingOddBeamGroupsAutoBeamingMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Odd_Beam_Groups_Auto_Beaming",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("f5, e5, d5, c5, c5, d5, e5, f5, f5, f4, f3, f5/16, f5"),
                time: .meter(6, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice, groups: [Fraction(2, 8), Fraction(3, 8), Fraction(1, 8)])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.More_Simple_Auto_Beaming_0")
    func autoBeamingMoreSimple0MatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "More_Simple_Auto_Beaming_0",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c4/8, g4, c5, g5, a5, c4, d4, a5"),
                time: .meter(4, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.More_Simple_Auto_Beaming_1")
    func autoBeamingMoreSimple1MatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "More_Simple_Auto_Beaming_1",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c5/16, g5, c5, c5/r, c5/r, (c4 e4 g4), d4, a5, c4, g4, c5, b4/r, (c4 e4), b4/r, b4/r, a4"),
                time: .meter(4, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Beam_Across_All_Rests")
    func autoBeamingBeamAcrossAllRestsMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Beam_Across_All_Rests", width: 450, height: 140) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c5/16, g5, c5, c5/r, c5/r, (c4 e4 g4), d4, a5, c4, g4, c5, b4/r, (c4 e4), b4/r, b4/r, a4"),
                time: .meter(4, 4)
            )
            let beams = try Beam.generateBeams(stemmableNotes(in: voice), config: BeamConfig(beamRests: true))
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Beam_Across_All_Rests_with_Stemlets")
    func autoBeamingBeamAcrossAllRestsWithStemletsMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Beam_Across_All_Rests_with_Stemlets",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c5/16, g5, c5, c5/r, c5/r, (c4 e4 g4), d4, a5, c4, g4, c5, b4/r, (c4 e4), b4/r, b4/r, a4"),
                time: .meter(4, 4)
            )
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(beamRests: true, showStemlets: true)
            )
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Break_Beams_on_Middle_Rests_Only")
    func autoBeamingBreakBeamsOnMiddleRestsOnlyMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Break_Beams_on_Middle_Rests_Only",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c5/16, g5, c5, c5/r, c5/r, (c4 e4 g4), d4, a5, c4, g4, c5, b4/r, (c4 e4), b4/r, b4/r, a4"),
                time: .meter(4, 4)
            )
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(beamRests: true, beamMiddleOnly: true)
            )
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Break_Beams_on_Rest")
    func autoBeamingBreakBeamsOnRestMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Break_Beams_on_Rest", width: 450, height: 140) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c5/16, g5, c5, c5/r, c5/r, (c4 e4 g4), d4, a5, c4, g4, c5, b4/r, (c4 e4), b4/r, b4/r, a4"),
                time: .meter(4, 4)
            )
            let beams = try Beam.generateBeams(stemmableNotes(in: voice), config: BeamConfig(beamRests: false))
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Maintain_Stem_Directions")
    func autoBeamingMaintainStemDirectionsMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Maintain_Stem_Directions", width: 450, height: 200) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes(
                    [
                        #"b4/16,            b4,              b4[stem="down"], b4/r"#,
                        #"b4/r,             b4[stem="down"], b4,              b4"#,
                        #"b4[stem="down"],  b4[stem="down"], b4,              b4/r"#,
                        #"b4/32,            b4[stem="down"], b4[stem="down"], b4, b4/16/r, b4"#,
                    ].joined(separator: ","),
                    options: ["stem": "up"]
                ),
                time: .meter(4, 4)
            )
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(beamRests: false, maintainStemDirections: true)
            )
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Maintain_Stem_Directions___Beam_Over_Rests")
    func autoBeamingMaintainStemDirectionsBeamOverRestsMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Maintain_Stem_Directions___Beam_Over_Rests",
            width: 450,
            height: 200
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes(
                    [
                        #"b4/16,            b4,              b4[stem="down"], b4/r"#,
                        #"b4/r,             b4[stem="down"], b4,              b4"#,
                        #"b4[stem="down"],  b4[stem="down"], b4,              b4/r"#,
                        #"b4/32,            b4[stem="down"], b4[stem="down"], b4, b4/16/r, b4"#,
                    ].joined(separator: ","),
                    options: ["stem": "up"]
                ),
                time: .meter(4, 4)
            )
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(beamRests: true, maintainStemDirections: true)
            )
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Beat_group_with_unbeamable_note___2_2")
    func autoBeamingBeatGroupWithUnbeamableNote22MatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Beat_group_with_unbeamable_note___2_2",
            width: 450,
            height: 200
        ) { factory, context in
            let stave = factory.Stave().addTimeSignature(.meter(2, 4))
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("b4/16, b4, b4/4, b4/16, b4"),
                time: .meter(2, 4)
            )
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(groups: [Fraction(2, 2)], beamRests: false, maintainStemDirections: true)
            )
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Offset_beat_grouping___6_8_")
    func autoBeamingOffsetBeatGrouping68MatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Offset_beat_grouping___6_8_",
            width: 450,
            height: 200
        ) { factory, context in
            let stave = factory.Stave().addTimeSignature(.meter(6, 8))
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("b4/4, b4/4, b4/8, b4/8"),
                time: .meter(6, 8)
            )
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(groups: [Fraction(3, 8)], beamRests: false, maintainStemDirections: true)
            )
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Odd_Time___Guessing_Default_Beam_Groups")
    func autoBeamingOddTimeGuessingDefaultBeamGroupsMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Odd_Time___Guessing_Default_Beam_Groups",
            width: 450,
            height: 400
        ) { factory, context in
            let score = factory.EasyScore()

            let stave1 = factory.Stave(y: 10).addTimeSignature(.meter(5, 4))
            let voice1 = score.voice(score.notes("c5/8, g5, c5, b4, b4, c4, d4, a5, c4, g4"), time: .meter(5, 4))

            let stave2 = factory.Stave(y: 150).addTimeSignature(.meter(5, 8))
            let voice2 = score.voice(score.notes("c5/8, g5, c5, b4, b4"), time: .meter(5, 8))

            let stave3 = factory.Stave(y: 290).addTimeSignature(.meter(13, 16))
            let voice3 = score.voice(
                score.notes("c5/16, g5, c5, b4, b4, c5, g5, c5, b4, b4, c5, b4, b4"),
                time: .meter(13, 16)
            )

            var beams: [Beam] = []
            beams += try Beam.applyAndGetBeams(voice1, groups: Beam.getDefaultBeamGroups(.meter(5, 4)))
            beams += try Beam.applyAndGetBeams(voice2, groups: Beam.getDefaultBeamGroups(.meter(5, 8)))
            beams += try Beam.applyAndGetBeams(voice3, groups: Beam.getDefaultBeamGroups(.meter(13, 16)))

            let formatter = factory.Formatter()
            _ = formatter.formatToStave([voice1], stave: stave1)
            _ = formatter.formatToStave([voice2], stave: stave2)
            _ = formatter.formatToStave([voice3], stave: stave3)
            Stave.formatBegModifiers([stave1, stave2, stave3])

            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Custom_Beam_Groups")
    func autoBeamingCustomBeamGroupsMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Custom_Beam_Groups", width: 450, height: 400) { factory, context in
            let score = factory.EasyScore()

            let stave1 = factory.Stave(y: 10).addTimeSignature(.meter(5, 4))
            let voice1 = score.voice(score.notes("c5/8, g5, c5, b4, b4, c4, d4, a5, c4, g4"), time: .meter(5, 4))

            let stave2 = factory.Stave(y: 150).addTimeSignature(.meter(5, 8))
            let voice2 = score.voice(score.notes("c5/8, g5, c5, b4, b4"), time: .meter(5, 8))

            let stave3 = factory.Stave(y: 290).addTimeSignature(.meter(13, 16))
            let voice3 = score.voice(
                score.notes("c5/16, g5, c5, b4, b4, c5, g5, c5, b4, b4, c5, b4, b4"),
                time: .meter(13, 16)
            )

            var beams: [Beam] = []
            beams += try Beam.applyAndGetBeams(voice1, groups: [Fraction(5, 8)])
            beams += try Beam.applyAndGetBeams(voice2, groups: [Fraction(3, 8), Fraction(2, 8)])
            beams += try Beam.applyAndGetBeams(voice3, groups: [Fraction(7, 16), Fraction(2, 16), Fraction(4, 16)])

            let formatter = factory.Formatter()
            _ = formatter.formatToStave([voice1], stave: stave1)
            _ = formatter.formatToStave([voice2], stave: stave2)
            _ = formatter.formatToStave([voice3], stave: stave3)
            Stave.formatBegModifiers([stave1, stave2, stave3])

            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.More_Automatic_Beaming")
    func autoBeamingMoreAutomaticBeamingMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "More_Automatic_Beaming", width: 450, height: 140) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c4/8, g4/4, c5/8., g5/16, a5/4, a5/16, (c5 e5)/16, a5/8"),
                time: .meter(9, 8)
            )
            let beams = try Beam.applyAndGetBeams(voice, groups: Beam.getDefaultBeamGroups(.meter(9, 8)))
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Automatic_Beaming_4_4_with__3__3__2_Pattern")
    func autoBeamingAutomaticBeaming44332PatternMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Automatic_Beaming_4_4_with__3__3__2_Pattern",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c4/8, g4/4, c5/8, g5, a5, a5, f5"),
                time: .meter(4, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice, groups: [Fraction(3, 8), Fraction(3, 8), Fraction(2, 8)])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Automatic_Beaming_4_4_with__3__3__2_Pattern_and_Overflow")
    func autoBeamingAutomaticBeaming44332PatternAndOverflowMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Automatic_Beaming_4_4_with__3__3__2_Pattern_and_Overflow",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c4/8, g4/4., c5/8, g5, a5, a5"),
                time: .meter(4, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice, groups: [Fraction(3, 8), Fraction(3, 8), Fraction(2, 8)])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Automatic_Beaming_8_4_with__3__2__3_Pattern_and_2_Overflows")
    func autoBeamingAutomaticBeaming84232PatternAnd2OverflowsMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Automatic_Beaming_8_4_with__3__2__3_Pattern_and_2_Overflows",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c4/16, g4/2, f4/16, c5/8, a4/16, c4/16, g4/8, b4, c5, g5, f5, e5, c5, a4/4"),
                time: .meter(8, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice, groups: [Fraction(3, 8), Fraction(2, 8), Fraction(3, 8)])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Automatic_Beaming_8_4_with__3__2__3_Pattern_and_3_Overflows")
    func autoBeamingAutomaticBeaming84232PatternAnd3OverflowsMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Automatic_Beaming_8_4_with__3__2__3_Pattern_and_3_Overflows",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes("c4/16, g4/1, f4/16, c5/8, g5, f5, e5, c5, a4/4"),
                time: .meter(8, 4)
            )
            let beams = try Beam.applyAndGetBeams(voice, groups: [Fraction(3, 8), Fraction(2, 8), Fraction(3, 8)])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Duration_Based_Secondary_Beam_Breaks")
    func autoBeamingDurationBasedSecondaryBeamBreaksMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Duration_Based_Secondary_Beam_Breaks",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes(
                    [
                        "f5/32, f5, f5, f5, f5/16., f5/32",
                        "f5/16, f5/8, f5/16",
                        "f5/32, f5/16., f5., f5/32",
                        "f5/16., f5/32, f5, f5/16.",
                    ].joined(separator: ",")
                )
            )

            let beams = try Beam.generateBeams(stemmableNotes(in: voice), config: BeamConfig(secondaryBreaks: "8"))
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Duration_Based_Secondary_Beam_Breaks_2")
    func autoBeamingDurationBasedSecondaryBeamBreaks2MatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "Duration_Based_Secondary_Beam_Breaks_2",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let notes = score.tuplet(score.notes("e5/16, f5, f5"))
                + score.tuplet(score.notes("f5/16, f5, c5"))
                + score.notes("a4/16., f4/32")
                + score.tuplet(score.notes("d4/16, d4, d4"))
                + score.tuplet(score.notes("a5/8, (e5 g5), a5"))
                + score.tuplet(score.notes("f5/16, f5, f5"))
                + score.tuplet(score.notes("f5/16, f5, a4"))

            let voice = score.voice(notes)
            let beams = try Beam.generateBeams(stemmableNotes(in: voice), config: BeamConfig(secondaryBreaks: "8"))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Simple_Tuplet_Auto_Beaming")
    func autoBeamingSimpleTupletAutoBeamingMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Simple_Tuplet_Auto_Beaming", width: 450, height: 140) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let notes = score.tuplet(score.notes("c4/8, g4, c5"))
                + score.notes("g5/8, a5")
                + score.tuplet(
                    score.notes("a5/16, (c5 e5), a5, d5, a5"),
                    options: TupletOptions(notesOccupied: 4, ratioed: false)
                )
            let voice = score.voice(notes, time: .meter(3, 4))
            let beams = try Beam.applyAndGetBeams(voice)

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.More_Simple_Tuplet_Auto_Beaming")
    func autoBeamingMoreSimpleTupletAutoBeamingMatchesUpstream() throws {
        try runSVGParityCase(
            module: "Auto_Beaming",
            test: "More_Simple_Tuplet_Auto_Beaming",
            width: 450,
            height: 140
        ) { factory, context in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let notes = score.tuplet(score.notes("d4/4, g4, c5"))
                + score.notes("g5/16, a5, a5, (c5 e5)")
            let voice = score.voice(notes, time: .meter(3, 4))
            let beams = try Beam.applyAndGetBeams(voice)

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Flat_Beams_Up")
    func autoBeamingFlatBeamsUpMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Flat_Beams_Up", width: 450, height: 140) { factory, context in
            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()

            let notes = score.tuplet(score.notes("c4/8, g4, f5"))
                + score.notes("d5/8")
                + score.tuplet(score.notes("c5/16, (c4 e4 g4), f4"))
                + score.notes("d5/8, e5, c4, f5/32, f5, f5, f5")
            let voice = score.voice(notes)
            let beams = try Beam.generateBeams(stemmableNotes(in: voice), config: BeamConfig(stemDirection: .up, flatBeams: true))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Flat_Beams_Down")
    func autoBeamingFlatBeamsDownMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Flat_Beams_Down", width: 450, height: 200) { factory, context in
            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes(
                    "c5/64, c5, c5, c5, c5, c5, c5, c5, a5/8, g5, (d4 f4 a4)/16, d4, d5/8, e5, g5, a6/32, a6, a6, g4/64, g4"
                )
            )
            let beams = try Beam.generateBeams(stemmableNotes(in: voice), config: BeamConfig(stemDirection: .down, flatBeams: true))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Flat_Beams_Mixed_Direction")
    func autoBeamingFlatBeamsMixedDirectionMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Flat_Beams_Mixed_Direction", width: 450, height: 200) { factory, context in
            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes(
                    "c5/64, d5, e5, c5, f5, c5, a5, c5, a5/8, g5, (d4 f4 a4)/16, d4, d5/8, e5, c4, a4/32, a4, a4, g4/64, g4"
                )
            )
            let beams = try Beam.generateBeams(stemmableNotes(in: voice), config: BeamConfig(flatBeams: true))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Flat_Beams_Up__uniform_")
    func autoBeamingFlatBeamsUpUniformMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Flat_Beams_Up__uniform_", width: 450, height: 140) { factory, context in
            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()

            let notes = score.tuplet(score.notes("c4/8, g4, g5"))
                + score.notes("d5/8, c5/16, (c4 e4 g4), d5/8, e5, c4, f5/32, f5, f5, f5")
            let voice = score.voice(notes)
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(stemDirection: .up, flatBeams: true, flatBeamOffset: 50)
            )

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Flat_Beams_Down__uniform_")
    func autoBeamingFlatBeamsDownUniformMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Flat_Beams_Down__uniform_", width: 450, height: 200) { factory, context in
            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes(
                    "c5/64, c5, c5, c5, c5, c5, c5, c5, a5/8, g5, (e4 g4 b4)/16, e5, d5/8, e5/8, g5/8, a6/32, a6, a6, g4/64, g4"
                )
            )
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(stemDirection: .down, flatBeams: true, flatBeamOffset: 155)
            )

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Flat_Beams_Up_Bounds")
    func autoBeamingFlatBeamsUpBoundsMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Flat_Beams_Up_Bounds", width: 450, height: 140) { factory, context in
            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()

            let notes = score.tuplet(score.notes("c4/8, g4/8, g5/8"))
                + score.notes("d5/8, c5/16, (c4 e4 g4)/16, d5/8, e5/8, c4/8, f5/32, f5/32, f5/32, f5/32")
            let voice = score.voice(notes)
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(stemDirection: .up, flatBeams: true, flatBeamOffset: 60)
            )

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("Auto_Beaming.Flat_Beams_Down_Bounds")
    func autoBeamingFlatBeamsDownBoundsMatchesUpstream() throws {
        try runSVGParityCase(module: "Auto_Beaming", test: "Flat_Beams_Down_Bounds", width: 450, height: 200) { factory, context in
            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()
            let voice = score.voice(
                score.notes(
                    [
                        "g5/8, a6/32, a6/32, a6/32, g4/64, g4/64",
                        "c5/64, c5/64, c5/64, c5/64, c5/64, c5/64, c5/64, c5/64, a5/8",
                        "g5/8, (e4 g4 b4)/16, e5/16",
                        "d5/8, e5/8",
                    ].joined(separator: ","),
                    options: ["stem": "down"]
                )
            )
            let beams = try Beam.generateBeams(
                stemmableNotes(in: voice),
                config: BeamConfig(stemDirection: .down, flatBeams: true, flatBeamOffset: 145)
            )

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
            try drawBeams(beams, context: context)
        }
    }

    @Test("StaveModifier.Stave_Draw_Test")
    func staveModifierStaveDrawTestMatchesUpstream() throws {
        try runSVGParityCase(module: "StaveModifier", test: "Stave_Draw_Test", width: 400, height: 120) { _, context in
            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave.setContext(context)
            try stave.draw()
        }
    }

    @Test("StaveModifier.Begin___End_StaveModifier_Test")
    func staveModifierBeginEndStaveModifierTestMatchesUpstream() throws {
        try runSVGParityCase(
            module: "StaveModifier",
            test: "Begin___End_StaveModifier_Test",
            width: 500,
            height: 240
        ) { _, context in
            let stave = Stave(x: 10, y: 10, width: 400)
            _ = stave.setContext(context)
            _ = stave.setTimeSignature(.cutTime)
            _ = stave.setKeySignature("Db")
            _ = stave.setClef(.treble)
            _ = stave.setBegBarType(.repeatBegin)
            _ = stave.setEndClef(.alto)
            _ = stave.setEndTimeSignature(.meter(9, 8))
            _ = stave.setEndKeySignature("G", cancelKeySpec: "C#")
            _ = stave.setEndBarType(.double)
            try stave.draw()

            _ = stave.setY(100)
            _ = stave.setTimeSignature(.meter(3, 4))
            _ = stave.setKeySignature("G", cancelKeySpec: "C#")
            _ = stave.setClef(.bass)
            _ = stave.setBegBarType(.single)
            _ = stave.setClef(.treble, position: .end)
            _ = stave.setTimeSignature(.commonTime, position: .end)
            _ = stave.setKeySignature("F", position: .end)
            _ = stave.setEndBarType(.single)
            try stave.draw()
        }
    }

    @Test("StaveConnector.Single_Draw_Test")
    func staveConnectorSingleDrawTestMatchesUpstream() throws {
        try runSVGParityCase(module: "StaveConnector", test: "Single_Draw_Test", width: 400, height: 300) { _, context in
            let stave1 = Stave(x: 25, y: 10, width: 300)
            let stave2 = Stave(x: 25, y: 120, width: 300)
            _ = stave1.setContext(context)
            _ = stave2.setContext(context)

            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector.setType(.singleLeft)
            _ = connector.setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
        }
    }

    @Test("StaveConnector.Single_Both_Sides_Test")
    func staveConnectorSingleBothSidesTestMatchesUpstream() throws {
        try runSVGParityCase(
            module: "StaveConnector",
            test: "Single_Both_Sides_Test",
            width: 400,
            height: 300
        ) { _, context in
            let stave1 = Stave(x: 25, y: 10, width: 300)
            let stave2 = Stave(x: 25, y: 120, width: 300)
            _ = stave1.setContext(context)
            _ = stave2.setContext(context)

            let connectorLeft = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connectorLeft.setType(.singleLeft)
            _ = connectorLeft.setContext(context)

            let connectorRight = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connectorRight.setType(.singleRight)
            _ = connectorRight.setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connectorLeft.draw()
            try connectorRight.draw()
        }
    }

    @Test("Clef.Clef_Test")
    func clefTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Clef", test: "Clef_Test", width: 800, height: 120) { factory, _ in
            _ = factory.Stave()
                .addClef(.treble)
                .addClef(.treble, size: .default, annotation: .octaveUp)
                .addClef(.treble, size: .default, annotation: .octaveDown)
                .addClef(.alto)
                .addClef(.tenor)
                .addClef(.soprano)
                .addClef(.bass)
                .addClef(.bass, size: .default, annotation: .octaveDown)
                .addClef(.mezzoSoprano)
                .addClef(.baritoneC)
                .addClef(.baritoneF)
                .addClef(.subbass)
                .addClef(.percussion)
                .addClef(.french)
                .addEndClef(.treble)
            try factory.draw()
        }
    }

    @Test("Clef.Small_Clef_Test")
    func clefSmallTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Clef", test: "Small_Clef_Test", width: 800, height: 120) { factory, _ in
            _ = factory.Stave()
                .addClef(.treble, size: .small)
                .addClef(.treble, size: .small, annotation: .octaveUp)
                .addClef(.treble, size: .small, annotation: .octaveDown)
                .addClef(.alto, size: .small)
                .addClef(.tenor, size: .small)
                .addClef(.soprano, size: .small)
                .addClef(.bass, size: .small)
                .addClef(.bass, size: .small, annotation: .octaveDown)
                .addClef(.mezzoSoprano, size: .small)
                .addClef(.baritoneC, size: .small)
                .addClef(.baritoneF, size: .small)
                .addClef(.subbass, size: .small)
                .addClef(.percussion, size: .small)
                .addClef(.french, size: .small)
                .addEndClef(.treble, size: .small)
            try factory.draw()
        }
    }

    @Test("Clef.Clef_End_Test")
    func clefEndTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Clef", test: "Clef_End_Test", width: 800, height: 120) { factory, _ in
            _ = factory.Stave()
                .addClef(.bass)
                .addEndClef(.treble)
                .addEndClef(.treble, size: .default, annotation: .octaveUp)
                .addEndClef(.treble, size: .default, annotation: .octaveDown)
                .addEndClef(.alto)
                .addEndClef(.tenor)
                .addEndClef(.soprano)
                .addEndClef(.bass)
                .addEndClef(.bass, size: .default, annotation: .octaveDown)
                .addEndClef(.mezzoSoprano)
                .addEndClef(.baritoneC)
                .addEndClef(.baritoneF)
                .addEndClef(.subbass)
                .addEndClef(.percussion)
                .addEndClef(.french)
            try factory.draw()
        }
    }

    @Test("Clef.Small_Clef_End_Test")
    func clefSmallEndTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Clef", test: "Small_Clef_End_Test", width: 800, height: 120) { factory, _ in
            _ = factory.Stave()
                .addClef(.bass, size: .small)
                .addEndClef(.treble, size: .small)
                .addEndClef(.treble, size: .small, annotation: .octaveUp)
                .addEndClef(.treble, size: .small, annotation: .octaveDown)
                .addEndClef(.alto, size: .small)
                .addEndClef(.tenor, size: .small)
                .addEndClef(.soprano, size: .small)
                .addEndClef(.bass, size: .small)
                .addEndClef(.bass, size: .small, annotation: .octaveDown)
                .addEndClef(.mezzoSoprano, size: .small)
                .addEndClef(.baritoneC, size: .small)
                .addEndClef(.baritoneF, size: .small)
                .addEndClef(.subbass, size: .small)
                .addEndClef(.percussion, size: .small)
                .addEndClef(.french, size: .small)
            try factory.draw()
        }
    }

    @Test("Clef.Clef_Change_Test")
    func clefChangeTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Clef", test: "Clef_Change_Test", width: 800, height: 180) { factory, _ in
            let stave = factory.Stave().addClef(.treble)

            var tickables: [Tickable] = []
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .treble)))
            tickables.append(factory.ClefNote(type: .alto, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .alto)))
            tickables.append(factory.ClefNote(type: .tenor, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .tenor)))
            tickables.append(factory.ClefNote(type: .soprano, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .soprano)))
            tickables.append(factory.ClefNote(type: .bass, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .bass)))
            tickables.append(factory.ClefNote(type: .mezzoSoprano, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .mezzoSoprano)))
            tickables.append(factory.ClefNote(type: .baritoneC, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .baritoneC)))
            tickables.append(factory.ClefNote(type: .baritoneF, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .baritoneF)))
            tickables.append(factory.ClefNote(type: .subbass, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .subbass)))
            tickables.append(factory.ClefNote(type: .french, size: .small))
            tickables.append(try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .french)))
            tickables.append(factory.ClefNote(type: .treble, size: .small, annotation: .octaveDown))
            tickables.append(try factory.StaveNote(
                StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", octaveShift: -1, clef: .treble)
            ))
            tickables.append(factory.ClefNote(type: .treble, size: .small, annotation: .octaveUp))
            tickables.append(try factory.StaveNote(
                StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", octaveShift: 1, clef: .treble)
            ))

            let voice = factory.Voice(timeSignature: .meter(12, 4))
            _ = voice.addTickables(tickables)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Clef_Keys.Major_Key_Clef_Test")
    func clefKeysMajorKeyClefTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Clef_Keys", test: "Major_Key_Clef_Test", width: 720, height: 1780) { _, context in
            try drawClefKeysTest(context: context, keys: upstreamMajorKeys)
        }
    }

    @Test("Clef_Keys.Minor_Key_Clef_Test")
    func clefKeysMinorKeyClefTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Clef_Keys", test: "Minor_Key_Clef_Test", width: 720, height: 1780) { _, context in
            try drawClefKeysTest(context: context, keys: upstreamMinorKeys)
        }
    }

    @Test("Clef_Keys.Stave_Helper")
    func clefKeysStaveHelperMatchesUpstream() throws {
        try runSVGParityCase(module: "Clef_Keys", test: "Stave_Helper", width: 720, height: 400) { _, context in
            let widths = upstreamKeySigFontWidths()
            let clefWidth = upstreamKeyClefWidth()
            let accidentalCount = 28.0
            let keySigPadding = 10.0
            let sharpTestWidth = accidentalCount * widths.sharpWidth + clefWidth + Stave.defaultPadding + 7 * keySigPadding
            let flatTestWidth = accidentalCount * widths.flatWidth + clefWidth + Stave.defaultPadding + 7 * keySigPadding

            let keys = upstreamMajorKeys
            let stave1 = Stave(x: 10, y: 10, width: flatTestWidth).addClef(.treble)
            let stave2 = Stave(x: 10, y: 90, width: flatTestWidth).addClef(.bass)
            let stave3 = Stave(x: 10, y: 170, width: sharpTestWidth).addClef(.alto)
            let stave4 = Stave(x: 10, y: 260, width: sharpTestWidth).addClef(.tenor)

            for i in 0..<8 {
                _ = stave1.addKeySignature(keys[i])
                _ = stave2.addKeySignature(keys[i])
            }

            for i in 8..<keys.count {
                _ = stave3.addKeySignature(keys[i])
                _ = stave4.addKeySignature(keys[i])
            }

            _ = stave1.setContext(context)
            _ = stave2.setContext(context)
            _ = stave3.setContext(context)
            _ = stave4.setContext(context)
            try stave1.draw()
            try stave2.draw()
            try stave3.draw()
            try stave4.draw()
        }
    }

    @Test("KeySignature.End_key_with_clef_test")
    func keySignatureEndKeyWithClefTestMatchesUpstream() throws {
        try runSVGParityCase(module: "KeySignature", test: "End_key_with_clef_test", width: 400, height: 200) { _, context in
            context.scale(0.9, 0.9)

            let stave1 = Stave(x: 10, y: 10, width: 350)
            _ = stave1
                .setKeySignature("G")
                .setBegBarType(.repeatBegin)
                .setEndBarType(.repeatEnd)
                .setClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .setEndClef(.bass)
                .setEndKeySignature("Cb")

            let stave2 = Stave(x: 10, y: 90, width: 350)
            _ = stave2
                .setKeySignature("Cb")
                .setClef(.bass)
                .setEndClef(.treble)
                .setEndKeySignature("G")

            _ = stave1.setContext(context)
            _ = stave2.setContext(context)
            try stave1.draw()
            try stave2.draw()
        }
    }

    @Test("KeySignature.Major_Key_Test")
    func keySignatureMajorKeyTestMatchesUpstream() throws {
        try runSVGParityCase(module: "KeySignature", test: "Major_Key_Test", width: 1400, height: 240) { _, context in
            let widths = upstreamKeySigFontWidths()
            let accidentalCount = 28.0
            let casePadding = 10.0
            let testCases = 7.0

            let sharpTestWidth = accidentalCount * widths.sharpWidth + casePadding * testCases + Stave.defaultPadding
            let flatTestWidth = accidentalCount * widths.flatWidth + casePadding * testCases + Stave.defaultPadding

            let keys = upstreamMajorKeys
            let stave1 = Stave(x: 10, y: 10, width: flatTestWidth)
            let stave2 = Stave(x: 10, y: 90, width: sharpTestWidth)

            for i in 0..<8 {
                _ = KeySignature(keySpec: keys[i]).addToStave(stave1)
            }
            for i in 8..<keys.count {
                _ = KeySignature(keySpec: keys[i]).addToStave(stave2)
            }

            _ = stave1.setContext(context)
            _ = stave2.setContext(context)
            try stave1.draw()
            try stave2.draw()
        }
    }

    @Test("KeySignature.Minor_Key_Test")
    func keySignatureMinorKeyTestMatchesUpstream() throws {
        try runSVGParityCase(module: "KeySignature", test: "Minor_Key_Test", width: 1400, height: 240) { _, context in
            let widths = upstreamKeySigFontWidths()
            let accidentalCount = 28.0
            let casePadding = 10.0
            let testCases = 7.0

            let sharpTestWidth = accidentalCount * widths.sharpWidth + casePadding * testCases + Stave.defaultPadding
            let flatTestWidth = accidentalCount * widths.flatWidth + casePadding * testCases + Stave.defaultPadding

            let keys = upstreamMinorKeys
            let stave1 = Stave(x: 10, y: 10, width: flatTestWidth)
            let stave2 = Stave(x: 10, y: 90, width: sharpTestWidth)

            for i in 0..<8 {
                _ = KeySignature(keySpec: keys[i]).addToStave(stave1)
            }
            for i in 8..<keys.count {
                _ = KeySignature(keySpec: keys[i]).addToStave(stave2)
            }

            _ = stave1.setContext(context)
            _ = stave2.setContext(context)
            try stave1.draw()
            try stave2.draw()
        }
    }

    @Test("KeySignature.Stave_Helper")
    func keySignatureStaveHelperMatchesUpstream() throws {
        try runSVGParityCase(module: "KeySignature", test: "Stave_Helper", width: 1400, height: 240) { _, context in
            let widths = upstreamKeySigFontWidths()
            let accidentalCount = 28.0
            let casePadding = 10.0
            let testCases = 7.0

            let sharpTestWidth = accidentalCount * widths.sharpWidth + casePadding * testCases + Stave.defaultPadding
            let flatTestWidth = accidentalCount * widths.flatWidth + casePadding * testCases + Stave.defaultPadding

            let keys = upstreamMajorKeys
            let stave1 = Stave(x: 10, y: 10, width: flatTestWidth)
            let stave2 = Stave(x: 10, y: 90, width: sharpTestWidth)

            for i in 0..<8 {
                _ = stave1.addKeySignature(keys[i])
            }
            for i in 8..<keys.count {
                _ = stave2.addKeySignature(keys[i])
            }

            _ = stave1.setContext(context)
            _ = stave2.setContext(context)
            try stave1.draw()
            try stave2.draw()
        }
    }

    @Test("KeySignature.Cancelled_key_test")
    func keySignatureCancelledKeyTestMatchesUpstream() throws {
        try runSVGParityCase(module: "KeySignature", test: "Cancelled_key_test", width: 2200, height: 500) { _, context in
            let widths = upstreamKeySigFontWidths()
            let flatPadding = 18.0
            let sharpPadding = 20.0
            let flatTestCases = 8.0
            let sharpTestCases = 7.0

            let sharpTestWidth = 28 * widths.sharpWidth + 21 * widths.naturalWidth
                + sharpPadding * sharpTestCases + Stave.defaultPadding + widths.clefWidth
            let flatTestWidth = 28 * widths.flatWidth + 28 * widths.naturalWidth
                + flatPadding * flatTestCases + Stave.defaultPadding + widths.clefWidth
            let eFlatTestWidth = 28 * widths.flatWidth + 32 * widths.naturalWidth
                + flatPadding * flatTestCases + Stave.defaultPadding + widths.clefWidth
            let eSharpTestWidth = 28 * widths.sharpWidth + 28 * widths.naturalWidth
                + sharpPadding * sharpTestCases + Stave.defaultPadding + widths.clefWidth

            context.scale(0.9, 0.9)

            let keys = upstreamMajorKeys
            let stave1 = Stave(x: 10, y: 10, width: flatTestWidth).addClef(.treble)
            let stave2 = Stave(x: 10, y: 90, width: sharpTestWidth).addClef(.treble)
            let stave3 = Stave(x: 10, y: 170, width: eFlatTestWidth).addClef(.treble)
            let stave4 = Stave(x: 10, y: 250, width: eSharpTestWidth).addClef(.treble)

            for i in 0..<8 {
                let keySig = KeySignature(keySpec: keys[i])
                _ = keySig.cancelKey("Cb")
                _ = keySig.setPadding(flatPadding)
                _ = stave1.addModifier(keySig)
            }

            for i in 8..<keys.count {
                let keySig = KeySignature(keySpec: keys[i])
                _ = keySig.cancelKey("C#")
                _ = keySig.setPadding(sharpPadding)
                _ = stave2.addModifier(keySig)
            }

            for i in 0..<8 {
                let keySig = KeySignature(keySpec: keys[i])
                _ = keySig.cancelKey("E")
                _ = keySig.setPadding(flatPadding)
                _ = stave3.addModifier(keySig)
            }

            for i in 8..<keys.count {
                let keySig = KeySignature(keySpec: keys[i])
                _ = keySig.cancelKey("Ab")
                _ = keySig.setPadding(sharpPadding)
                _ = stave4.addModifier(keySig)
            }

            _ = stave1.setContext(context)
            _ = stave2.setContext(context)
            _ = stave3.setContext(context)
            _ = stave4.setContext(context)
            try stave1.draw()
            try stave2.draw()
            try stave3.draw()
            try stave4.draw()
        }
    }

    @Test("KeySignature.Cancelled_key__for_each_clef__test")
    func keySignatureCancelledForEachClefTestMatchesUpstream() throws {
        try runSVGParityCase(
            module: "KeySignature",
            test: "Cancelled_key__for_each_clef__test",
            width: 2600,
            height: 380
        ) { _, context in
            let widths = upstreamKeySigFontWidths()
            let keyPadding = 10.0
            let keys = ["C#", "Cb"]
            let flatsPerKey = [7.0, 14.0]
            let sharpsPerKey = [14.0, 7.0]
            let naturalsPerKey = [7.0, 7.0]

            context.scale(0.8, 0.8)

            let x = 20.0
            var y = 20.0
            let clefs: [ClefName] = [.bass, .tenor, .soprano, .mezzoSoprano, .baritoneF]

            for clef in clefs {
                var tx = x
                for keyIx in 0..<keys.count {
                    let key = keys[keyIx]
                    let cancelKey = keys[(keyIx + 1) % keys.count]
                    let width = flatsPerKey[keyIx] * widths.flatWidth
                        + naturalsPerKey[keyIx] * widths.naturalWidth
                        + sharpsPerKey[keyIx] * widths.sharpWidth
                        + keyPadding * 3
                        + widths.clefWidth
                        + Stave.defaultPadding

                    let stave = Stave(x: tx, y: y, width: width)
                    _ = stave
                        .setClef(clef)
                        .addKeySignature(cancelKey)
                        .addKeySignature(key, cancelKeySpec: cancelKey)
                        .addKeySignature(key)
                        .setContext(context)
                    try stave.draw()
                    tx += width
                }
                y += 80
            }
        }
    }

    @Test("KeySignature.Altered_key_test")
    func keySignatureAlteredKeyTestMatchesUpstream() throws {
        try runSVGParityCase(module: "KeySignature", test: "Altered_key_test", width: 780, height: 500) { _, context in
            context.scale(0.9, 0.9)

            let keys = upstreamMajorKeys
            let stave1 = Stave(x: 10, y: 10, width: 750).addClef(.treble)
            let stave2 = Stave(x: 10, y: 90, width: 750).addClef(.treble)
            let stave3 = Stave(x: 10, y: 170, width: 750).addClef(.treble)
            let stave4 = Stave(x: 10, y: 250, width: 750).addClef(.treble)

            for i in 0..<8 {
                let keySig = KeySignature(keySpec: keys[i])
                _ = keySig.alterKey(["bs", "bs"])
                _ = keySig.setPadding(18)
                _ = stave1.addModifier(keySig)
            }

            for i in 8..<keys.count {
                let keySig = KeySignature(keySpec: keys[i])
                _ = keySig.alterKey(["+", "+", "+"])
                _ = keySig.setPadding(20)
                _ = stave2.addModifier(keySig)
            }

            for i in 0..<8 {
                let keySig = KeySignature(keySpec: keys[i])
                _ = keySig.alterKey(["n", "bs", "bb"])
                _ = keySig.setPadding(18)
                _ = stave3.addModifier(keySig)
            }

            for i in 8..<keys.count {
                let keySig = KeySignature(keySpec: keys[i])
                _ = keySig.alterKey(["++", "+", "n", "+"])
                _ = keySig.setPadding(20)
                _ = stave4.addModifier(keySig)
            }

            _ = stave1.setContext(context)
            _ = stave2.setContext(context)
            _ = stave3.setContext(context)
            _ = stave4.setContext(context)
            try stave1.draw()
            try stave2.draw()
            try stave3.draw()
            try stave4.draw()
        }
    }

    @Test("KeySignature.Key_Signature_Change_test")
    func keySignatureChangeTestMatchesUpstream() throws {
        try runSVGParityCase(
            module: "KeySignature",
            test: "Key_Signature_Change_test",
            width: 900,
            height: 140
        ) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 800)
                .addClef(.treble)
                .addTimeSignature(.cutTime)

            let noteA = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "1"))
            let noteB = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "1"))
            let noteC = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "1"))
            let noteD = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "1"))

            let voice = factory.Voice()
                .setStrict(false)
                .addTickables([
                    factory.KeySigNote(key: "Bb"),
                    noteA,
                    factory.BarNote(),
                    factory.KeySigNote(key: "D", cancelKey: "Bb"),
                    noteB,
                    factory.BarNote(),
                    factory.KeySigNote(key: "Bb"),
                    noteC,
                    factory.BarNote(),
                    factory.KeySigNote(key: "D", alterKey: ["b", "n"]),
                    noteD,
                ])

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("KeySignature.Key_Signature_with_without_clef_symbol")
    func keySignatureWithWithoutClefSymbolMatchesUpstream() throws {
        try runSVGParityCase(
            module: "KeySignature",
            test: "Key_Signature_with_without_clef_symbol",
            width: 900,
            height: 140
        ) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 800)
                .addClef(.bass)
                .addTimeSignature(.cutTime)
                .setClefLines(.bass)

            let noteA = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "1", clef: .bass))
            let noteB = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "1", clef: .bass))
            let noteC = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "1", clef: .bass))
            let noteD = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "1", clef: .bass))

            let voice = factory.Voice()
                .setStrict(false)
                .addTickables([
                    factory.KeySigNote(key: "Bb"),
                    noteA,
                    factory.BarNote(),
                    factory.KeySigNote(key: "D", cancelKey: "Bb"),
                    noteB,
                    factory.BarNote(),
                    factory.KeySigNote(key: "Bb"),
                    noteC,
                    factory.BarNote(),
                    factory.KeySigNote(key: "D", alterKey: ["b", "n"]),
                    noteD,
                ])

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("TimeSignature.Basic_Time_Signatures")
    func timeSignatureBasicTimeSignaturesMatchesUpstream() throws {
        try runSVGParityCase(module: "TimeSignature", test: "Basic_Time_Signatures", width: 600, height: 120) { _, context in
            let stave = Stave(x: 10, y: 10, width: 500)
            _ = stave
                .addTimeSignature(.meter(2, 2))
                .addTimeSignature(.meter(3, 4))
                .addTimeSignature(.meter(4, 4))
                .addTimeSignature(.meter(6, 8))
                .addTimeSignature(.commonTime)
                .addTimeSignature(.cutTime)
                .addTimeSignature(.meter(2, 2), position: .end)
                .addTimeSignature(.meter(3, 4), position: .end)
                .addTimeSignature(.meter(4, 4), position: .end)
                .addEndClef(.treble)
                .addTimeSignature(.meter(6, 8), position: .end)
                .addTimeSignature(.commonTime, position: .end)
                .addTimeSignature(.cutTime, position: .end)
                .setContext(context)
            try stave.draw()
        }
    }

    @Test("TimeSignature.Big_Signature_Test")
    func timeSignatureBigSignatureTestMatchesUpstream() throws {
        try runSVGParityCase(module: "TimeSignature", test: "Big_Signature_Test", width: 400, height: 120) { _, context in
            let threePart = try parseTimeSignature("1234567/890")
            let fourPart = try parseTimeSignature("987/654321")

            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave
                .addTimeSignature(.meter(12, 8))
                .addTimeSignature(.meter(7, 16))
                .addTimeSignature(threePart)
                .addTimeSignature(fourPart)
                .setContext(context)
            try stave.draw()
        }
    }

    @Test("TimeSignature.Additive_Signature_Test")
    func timeSignatureAdditiveSignatureTestMatchesUpstream() throws {
        try runSVGParityCase(module: "TimeSignature", test: "Additive_Signature_Test", width: 400, height: 120) { _, context in
            let additive = try parseTimeSignature("2+3+2/8")
            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave
                .addTimeSignature(additive)
                .setContext(context)
            try stave.draw()
        }
    }

    @Test("TimeSignature.Alternating_Signature_Test")
    func timeSignatureAlternatingSignatureTestMatchesUpstream() throws {
        try runSVGParityCase(module: "TimeSignature", test: "Alternating_Signature_Test", width: 400, height: 120) { _, context in
            let sixEight = try parseTimeSignature("6/8")
            let plus = try parseTimeSignature("+")
            let threeFour = try parseTimeSignature("3/4")

            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave
                .addTimeSignature(sixEight)
                .addTimeSignature(plus)
                .addTimeSignature(threeFour)
                .setContext(context)
            try stave.draw()
        }
    }

    @Test("TimeSignature.Interchangeable_Signature_Test")
    func timeSignatureInterchangeableSignatureTestMatchesUpstream() throws {
        try runSVGParityCase(
            module: "TimeSignature",
            test: "Interchangeable_Signature_Test",
            width: 400,
            height: 120
        ) { _, context in
            let threeFour = try parseTimeSignature("3/4")
            let minus = try parseTimeSignature("-")
            let twoFour = try parseTimeSignature("2/4")

            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave
                .addTimeSignature(threeFour)
                .addTimeSignature(minus)
                .addTimeSignature(twoFour)
                .setContext(context)
            try stave.draw()
        }
    }

    @Test("TimeSignature.Aggregate_Signature_Test")
    func timeSignatureAggregateSignatureTestMatchesUpstream() throws {
        try runSVGParityCase(module: "TimeSignature", test: "Aggregate_Signature_Test", width: 400, height: 120) { _, context in
            let twoFour = try parseTimeSignature("2/4")
            let plus = try parseTimeSignature("+")
            let threeEight = try parseTimeSignature("3/8")
            let fiveFour = try parseTimeSignature("5/4")

            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave
                .addTimeSignature(twoFour)
                .addTimeSignature(plus)
                .addTimeSignature(threeEight)
                .addTimeSignature(plus)
                .addTimeSignature(fiveFour)
                .setContext(context)
            try stave.draw()
        }
    }

    @Test("TimeSignature.Complex_Signature_Test")
    func timeSignatureComplexSignatureTestMatchesUpstream() throws {
        try runSVGParityCase(module: "TimeSignature", test: "Complex_Signature_Test", width: 400, height: 120) { _, context in
            let twoPlusThreeOverSixteen = try parseTimeSignature("(2+3)/16")
            let plus = try parseTimeSignature("+")
            let threeEight = try parseTimeSignature("3/8")

            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave
                .addTimeSignature(twoPlusThreeOverSixteen)
                .addTimeSignature(plus)
                .addTimeSignature(threeEight)
                .setContext(context)
            try stave.draw()
        }
    }

    @Test("TimeSignature.Time_Signature_multiple_staves_alignment_test")
    func timeSignatureMultipleStavesAlignmentTestMatchesUpstream() throws {
        try runSVGParityCase(
            module: "TimeSignature",
            test: "Time_Signature_multiple_staves_alignment_test",
            width: 400,
            height: 350
        ) { _, context in
            let stave1LineConfig = [false, false, true, false, false].map { StaveLineConfig(visible: $0) }

            let stave1 = Stave(x: 15, y: 0, width: 300)
            _ = stave1
                .setConfigForLines(stave1LineConfig)
                .addClef(.percussion)
                .addTimeSignature(.meter(4, 4), customPadding: 25)
                .setContext(context)
            try stave1.draw()

            let stave2 = Stave(x: 15, y: 110, width: 300)
            _ = stave2
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .setContext(context)
            try stave2.draw()

            let stave3 = Stave(x: 15, y: 220, width: 300)
            _ = stave3
                .addClef(.bass)
                .addTimeSignature(.meter(4, 4))
                .setContext(context)
            try stave3.draw()

            Stave.formatBegModifiers([stave1, stave2, stave3])

            let connector1 = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector1.setType(.singleLeft).setContext(context)
            try connector1.draw()

            let connector2 = StaveConnector(topStave: stave2, bottomStave: stave3)
            _ = connector2.setType(.singleLeft).setContext(context)
            try connector2.draw()

            let connector3 = StaveConnector(topStave: stave2, bottomStave: stave3)
            _ = connector3.setType(.brace).setContext(context)
            try connector3.draw()
        }
    }

    @Test("TimeSignature.Time_Signature_Change_Test")
    func timeSignatureChangeTestMatchesUpstream() throws {
        try runSVGParityCase(module: "TimeSignature", test: "Time_Signature_Change_Test", width: 900, height: 140) { factory, _ in
            let stave = factory.Stave(x: 0, y: 0)
                .addClef(.treble)
                .addTimeSignature(.cutTime)

            let tickables: [Tickable] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .treble)),
                factory.TimeSigNote(time: .meter(3, 4)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4"], duration: "4", clef: .alto)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/3"], duration: "4r", clef: .alto)),
                factory.TimeSigNote(time: .commonTime),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/3", "e/3", "g/3"], duration: "4", clef: .bass)),
                factory.TimeSigNote(time: .meter(9, 8)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", clef: .treble)),
            ]

            let voice = factory.Voice().setStrict(false)
            _ = voice.addTickables(tickables)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Stave.Stave_Draw_Test")
    func staveDrawTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Stave", test: "Stave_Draw_Test", width: 400, height: 150) { _, context in
            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave.setContext(context)
            try stave.draw()
        }
    }

    @Test("Stave.Open_Stave_Draw_Test")
    func staveOpenStaveDrawTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Stave", test: "Open_Stave_Draw_Test", width: 400, height: 350) { _, context in
            let leftOpen = Stave(x: 10, y: 10, width: 300, options: StaveOptions(leftBar: false))
            _ = leftOpen.setContext(context)
            try leftOpen.draw()

            let rightOpen = Stave(x: 10, y: 150, width: 300, options: StaveOptions(rightBar: false))
            _ = rightOpen.setContext(context)
            try rightOpen.draw()
        }
    }

    @Test("Stave.Single_Line_Configuration_Test")
    func staveSingleLineConfigurationTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Stave", test: "Single_Line_Configuration_Test", width: 400, height: 120) { _, context in
            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave
                .setConfigForLine(0, config: StaveLineConfig(visible: true))
                .setConfigForLine(1, config: StaveLineConfig(visible: false))
                .setConfigForLine(2, config: StaveLineConfig(visible: true))
                .setConfigForLine(3, config: StaveLineConfig(visible: false))
                .setConfigForLine(4, config: StaveLineConfig(visible: true))
                .setContext(context)
            try stave.draw()
        }
    }

    @Test("Stave.Batch_Line_Configuration_Test")
    func staveBatchLineConfigurationTestMatchesUpstream() throws {
        try runSVGParityCase(module: "Stave", test: "Batch_Line_Configuration_Test", width: 400, height: 120) { _, context in
            let lineConfig = [
                StaveLineConfig(visible: false),
                StaveLineConfig(),
                StaveLineConfig(visible: false),
                StaveLineConfig(visible: true),
                StaveLineConfig(visible: false),
            ]

            let stave = Stave(x: 10, y: 10, width: 300)
            _ = stave
                .setConfigForLines(lineConfig)
                .setContext(context)
            try stave.draw()
        }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment[Self.enableEnvKey] == "1"
    }

    private var configuredFonts: [String] {
        guard let raw = ProcessInfo.processInfo.environment[Self.fontsEnvKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return defaultFonts
        }
        let parsed = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parsed.isEmpty ? defaultFonts : parsed
    }

    private var signatureComparisonEpsilon: Double {
        guard let raw = ProcessInfo.processInfo.environment[Self.signatureEpsilonEnvKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty,
            let parsed = Double(raw),
            parsed > 0
        else {
            return 0
        }
        return parsed
    }

    private func stemmableNotes(in voice: Voice) -> [StemmableNote] {
        voice.getTickables().compactMap { $0 as? StemmableNote }
    }

    private func drawBeams(_ beams: [Beam], context: SVGRenderContext) throws {
        for beam in beams {
            _ = beam.setContext(context)
            try beam.draw()
        }
    }

    private func runSVGParityCase(
        module: String,
        test: String,
        width: Double,
        height: Double,
        draw: (Factory, SVGRenderContext) throws -> Void
    ) throws {
        guard isEnabled else { return }

        for font in configuredFonts {
            try Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
                FontLoader.loadDefaultFonts()
                try applyUpstreamFontStack(fontName: font)

                let context = SVGRenderContext(
                    width: width,
                    height: height,
                    options: SVGRenderOptions(precision: 3)
                )
                let factory = Factory(options: FactoryOptions(width: width, height: height))
                _ = factory.setContext(context)

                try draw(factory, context)

                let expectedURL = expectedSVGURL(module: module, test: test, font: font)
                guard FileManager.default.fileExists(atPath: expectedURL.path) else {
                    Issue.record("Missing upstream reference: \(expectedURL.path)")
                    return
                }

                let actualSVG = context.getSVG()
                let expectedSVG = try String(contentsOf: expectedURL, encoding: .utf8)
                let actualSignature = drawingSignature(svg: actualSVG)
                let expectedSignature = drawingSignature(svg: expectedSVG)

                let epsilon = signatureComparisonEpsilon
                if !signaturesMatch(actual: actualSignature, expected: expectedSignature, epsilon: epsilon) {
                    let artifacts = try writeMismatchArtifacts(
                        module: module,
                        test: test,
                        font: font,
                        actualSVG: actualSVG,
                        expectedSVG: expectedSVG,
                        actualSignature: actualSignature,
                        expectedSignature: expectedSignature
                    )
                    Issue.record(
                        """
                        Upstream SVG mismatch for \(module).\(test).\(font)
                        Expected: \(expectedURL.path)
                        Actual artifact: \(artifacts.actualSVG.path)
                        Expected artifact: \(artifacts.expectedSVG.path)
                        Signature epsilon: \(epsilon)
                        """
                    )
                }
            }
        }
    }

    func runCategorySVGParityCase(
        module: String,
        test: String,
        width: Double,
        height: Double,
        draw: (Factory, SVGRenderContext) throws -> Void
    ) throws {
        try runSVGParityCase(module: module, test: test, width: width, height: height, draw: draw)
    }

    private func applyUpstreamFontStack(fontName: String) throws {
        switch fontName {
        case "Bravura":
            _ = try Flow.setMusicFont(parsing: ["Bravura", "Custom"])
        case "Gonville":
            _ = try Flow.setMusicFont(parsing: ["Gonville", "Bravura", "Custom"])
        case "Petaluma":
            _ = try Flow.setMusicFont(parsing: ["Petaluma", "Gonville", "Bravura", "Custom"])
        case "Leland":
            _ = try Flow.setMusicFont(parsing: ["Leland", "Bravura", "Custom"])
        default:
            throw UpstreamSVGParityError.unsupportedFont(fontName)
        }
    }

    private func parseTimeSignature(_ raw: String) throws -> TimeSignatureSpec {
        guard let parsed = TimeSignatureSpec(parsing: raw) else {
            throw UpstreamSVGParityError.invalidTimeSignatureSpec(raw)
        }
        return parsed
    }

    private var upstreamMajorKeys: [String] {
        ["C", "F", "Bb", "Eb", "Ab", "Db", "Gb", "Cb", "G", "D", "A", "E", "B", "F#", "C#"]
    }

    private var upstreamMinorKeys: [String] {
        ["Am", "Dm", "Gm", "Cm", "Fm", "Bbm", "Ebm", "Abm", "Em", "Bm", "F#m", "C#m", "G#m", "D#m", "A#m"]
    }

    private func upstreamKeySigFontWidths() -> (sharpWidth: Double, flatWidth: Double, naturalWidth: Double, clefWidth: Double) {
        let glyphScale = 39.0
        let sharpWidth = Glyph.getWidth(code: "accidentalSharp", point: glyphScale) + 1
        let flatWidth = Glyph.getWidth(code: "accidentalFlat", point: glyphScale) + 1
        let naturalWidth = Glyph.getWidth(code: "accidentalNatural", point: glyphScale) + 2
        let clefWidth = Glyph.getWidth(code: "gClef", point: glyphScale) * 2
        return (sharpWidth: sharpWidth, flatWidth: flatWidth, naturalWidth: naturalWidth, clefWidth: clefWidth)
    }

    private func upstreamKeyClefWidth() -> Double {
        Glyph.getWidth(code: "gClef", point: 39)
    }

    private func drawClefKeysTest(context: SVGRenderContext, keys: [String]) throws {
        let widths = upstreamKeySigFontWidths()
        let clefWidth = upstreamKeyClefWidth()
        let accidentalCount = 28.0
        let keySigPadding = 10.0
        let sharpTestWidth = accidentalCount * widths.sharpWidth + clefWidth + Stave.defaultPadding + 6 * keySigPadding
        let flatTestWidth = accidentalCount * widths.flatWidth + clefWidth + Stave.defaultPadding + 6 * keySigPadding

        let clefs: [ClefName] = [
            .treble,
            .soprano,
            .mezzoSoprano,
            .alto,
            .tenor,
            .baritoneF,
            .baritoneC,
            .bass,
            .french,
            .subbass,
            .percussion,
        ]

        let yOffsetForSharpStaves = 10.0 + 80.0 * Double(clefs.count)
        var flatStaves: [Stave] = []
        var sharpStaves: [Stave] = []

        for (index, clef) in clefs.enumerated() {
            let flatStave = Stave(x: 10, y: 10 + 80 * Double(index), width: flatTestWidth).addClef(clef)
            let sharpStave = Stave(x: 10, y: yOffsetForSharpStaves + 10 + 80 * Double(index), width: sharpTestWidth)
                .addClef(clef)

            for flatIx in 0..<8 {
                _ = KeySignature(keySpec: keys[flatIx]).addToStave(flatStave)
            }
            for sharpIx in 8..<keys.count {
                _ = KeySignature(keySpec: keys[sharpIx]).addToStave(sharpStave)
            }

            flatStaves.append(flatStave)
            sharpStaves.append(sharpStave)
        }

        let allStaves = flatStaves + sharpStaves
        Stave.formatBegModifiers(allStaves)

        for index in 0..<clefs.count {
            _ = flatStaves[index].setContext(context)
            _ = sharpStaves[index].setContext(context)
            try flatStaves[index].draw()
            try sharpStaves[index].draw()
        }
    }

    private func expectedSVGURL(module: String, test: String, font: String) -> URL {
        let fileName = "pptr-\(module).\(test).\(font).svg"
        return referenceSVGDirectory().appendingPathComponent(fileName)
    }

    private func referenceSVGDirectory() -> URL {
        if let explicit = ProcessInfo.processInfo.environment[Self.referenceDirEnvKey],
           !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: explicit, isDirectory: true).standardizedFileURL
        }

        let root = packageRoot()
        let candidates = [
            root.appendingPathComponent("../vexmotion/build/images/reference", isDirectory: true).standardizedFileURL,
            root.appendingPathComponent("../vexflow/build/images/reference", isDirectory: true).standardizedFileURL,
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return candidates[1]
    }

    private func packageRoot() -> URL {
        let here = URL(fileURLWithPath: #filePath)
        return here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func artifactsDirectory() -> URL {
        if let explicit = ProcessInfo.processInfo.environment[Self.artifactsDirEnvKey],
           !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: explicit, isDirectory: true).standardizedFileURL
        }
        return packageRoot()
            .appendingPathComponent(".build/upstream-svg-parity/artifacts", isDirectory: true)
            .standardizedFileURL
    }

    private func writeMismatchArtifacts(
        module: String,
        test: String,
        font: String,
        actualSVG: String,
        expectedSVG: String,
        actualSignature: String,
        expectedSignature: String
    ) throws -> (actualSVG: URL, expectedSVG: URL) {
        let dir = artifactsDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = "pptr-\(module).\(test).\(font)"
        let actualSVGURL = dir.appendingPathComponent("\(base).actual.svg")
        let expectedSVGURL = dir.appendingPathComponent("\(base).expected.svg")
        let actualSignatureURL = dir.appendingPathComponent("\(base).actual.signature.txt")
        let expectedSignatureURL = dir.appendingPathComponent("\(base).expected.signature.txt")

        try actualSVG.write(to: actualSVGURL, atomically: true, encoding: .utf8)
        try expectedSVG.write(to: expectedSVGURL, atomically: true, encoding: .utf8)
        try actualSignature.write(to: actualSignatureURL, atomically: true, encoding: .utf8)
        try expectedSignature.write(to: expectedSignatureURL, atomically: true, encoding: .utf8)
        return (actualSVG: actualSVGURL, expectedSVG: expectedSVGURL)
    }

    private func drawingSignature(svg: String) -> String {
        let tagPattern = #"<(path|rect|circle|ellipse|line|polygon|polyline)\b[^>]*>"#
        let regex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive])
        guard let regex else { return normalizedSVGText(svg) }

        let nsRange = NSRange(svg.startIndex..<svg.endIndex, in: svg)
        let matches = regex.matches(in: svg, options: [], range: nsRange)
        guard !matches.isEmpty else { return normalizedSVGText(svg) }

        var rows: [String] = []
        for match in matches {
            guard
                let wholeRange = Range(match.range(at: 0), in: svg),
                let tagRange = Range(match.range(at: 1), in: svg)
            else { continue }

            let tag = String(svg[wholeRange])
            let tagName = String(svg[tagRange]).lowercased()
            let attrs = parseAttributes(in: tag)
            switch tagName {
            case "path":
                rows.append("path:d=\(canonicalizePathData(attrs["d"] ?? ""))")
            case "rect":
                rows.append(
                    "rect:x=\(canonicalizeNumericToken(attrs["x"] ?? "0"))" +
                    ",y=\(canonicalizeNumericToken(attrs["y"] ?? "0"))" +
                    ",w=\(canonicalizeNumericToken(attrs["width"] ?? "0"))" +
                    ",h=\(canonicalizeNumericToken(attrs["height"] ?? "0"))"
                )
            case "circle":
                rows.append(
                    "circle:cx=\(canonicalizeNumericToken(attrs["cx"] ?? "0"))" +
                    ",cy=\(canonicalizeNumericToken(attrs["cy"] ?? "0"))" +
                    ",r=\(canonicalizeNumericToken(attrs["r"] ?? "0"))"
                )
            case "ellipse":
                rows.append(
                    "ellipse:cx=\(canonicalizeNumericToken(attrs["cx"] ?? "0"))" +
                    ",cy=\(canonicalizeNumericToken(attrs["cy"] ?? "0"))" +
                    ",rx=\(canonicalizeNumericToken(attrs["rx"] ?? "0"))" +
                    ",ry=\(canonicalizeNumericToken(attrs["ry"] ?? "0"))"
                )
            case "line":
                rows.append(
                    "line:x1=\(canonicalizeNumericToken(attrs["x1"] ?? "0"))" +
                    ",y1=\(canonicalizeNumericToken(attrs["y1"] ?? "0"))" +
                    ",x2=\(canonicalizeNumericToken(attrs["x2"] ?? "0"))" +
                    ",y2=\(canonicalizeNumericToken(attrs["y2"] ?? "0"))"
                )
            case "polygon", "polyline":
                rows.append("\(tagName):points=\(canonicalizeNumericList(attrs["points"] ?? ""))")
            default:
                break
            }
        }

        return rows.joined(separator: "\n")
    }

    private func parseAttributes(in tag: String) -> [String: String] {
        let attrPattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: attrPattern) else { return [:] }
        let nsRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        let matches = regex.matches(in: tag, options: [], range: nsRange)
        var result: [String: String] = [:]
        for match in matches {
            guard
                let keyRange = Range(match.range(at: 1), in: tag),
                let valueRange = Range(match.range(at: 2), in: tag)
            else { continue }
            result[String(tag[keyRange])] = String(tag[valueRange])
        }
        return result
    }

    private func canonicalizePathData(_ pathData: String) -> String {
        let tokenPattern = #"[A-Za-z]|[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else {
            return pathData.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let nsRange = NSRange(pathData.startIndex..<pathData.endIndex, in: pathData)
        let matches = regex.matches(in: pathData, options: [], range: nsRange)
        let tokens: [String] = matches.compactMap { match in
            guard let range = Range(match.range, in: pathData) else { return nil }
            let token = String(pathData[range])
            if token.count == 1, let scalar = token.unicodeScalars.first, CharacterSet.letters.contains(scalar) {
                return token.uppercased()
            }
            return canonicalizeNumericToken(token)
        }
        return tokens.joined(separator: " ")
    }

    private func canonicalizeNumericList(_ value: String) -> String {
        let tokenPattern = #"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return value }
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = regex.matches(in: value, options: [], range: nsRange)
        let tokens: [String] = matches.compactMap { match in
            guard let range = Range(match.range, in: value) else { return nil }
            return canonicalizeNumericToken(String(value[range]))
        }
        return tokens.joined(separator: " ")
    }

    private func canonicalizeNumericToken(_ token: String) -> String {
        guard let value = Double(token) else {
            return token.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let rounded = (value * 1000).rounded() / 1000
        if abs(rounded.rounded() - rounded) < 0.000_000_1 {
            return String(Int(rounded.rounded()))
        }

        var text = String(format: "%.3f", rounded)
        while text.contains("."), text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }

    private func signaturesMatch(actual: String, expected: String, epsilon: Double) -> Bool {
        if epsilon <= 0 {
            return actual == expected
        }

        let actualRows = actual.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let expectedRows = expected.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard actualRows.count == expectedRows.count else { return false }

        for index in 0..<actualRows.count {
            let lhs = actualRows[index]
            let rhs = expectedRows[index]
            if lhs == rhs { continue }
            if !signatureRowsMatchWithEpsilon(lhs, rhs, epsilon: epsilon) {
                return false
            }
        }

        return true
    }

    private func signatureRowsMatchWithEpsilon(_ lhs: String, _ rhs: String, epsilon: Double) -> Bool {
        let numberPattern = #"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: numberPattern) else {
            return lhs == rhs
        }

        let lhsRange = NSRange(lhs.startIndex..<lhs.endIndex, in: lhs)
        let rhsRange = NSRange(rhs.startIndex..<rhs.endIndex, in: rhs)
        let lhsMatches = regex.matches(in: lhs, options: [], range: lhsRange)
        let rhsMatches = regex.matches(in: rhs, options: [], range: rhsRange)
        guard lhsMatches.count == rhsMatches.count else { return false }

        let lhsSkeleton = regex.stringByReplacingMatches(in: lhs, options: [], range: lhsRange, withTemplate: "#")
        let rhsSkeleton = regex.stringByReplacingMatches(in: rhs, options: [], range: rhsRange, withTemplate: "#")
        guard lhsSkeleton == rhsSkeleton else { return false }

        for index in 0..<lhsMatches.count {
            guard
                let lhsTokenRange = Range(lhsMatches[index].range, in: lhs),
                let rhsTokenRange = Range(rhsMatches[index].range, in: rhs),
                let lhsValue = Double(lhs[lhsTokenRange]),
                let rhsValue = Double(rhs[rhsTokenRange])
            else {
                return false
            }

            if abs(lhsValue - rhsValue) > epsilon {
                return false
            }
        }

        return true
    }

    private func normalizedSVGText(_ svg: String) -> String {
        var text = svg.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #" id="[^"]*""#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
