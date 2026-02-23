import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    private struct CrossBeamNoteChunk {
        var notestring: String
        var clef: ClefName
    }

    private struct CrossBeamVoiceSpec {
        var notes: [CrossBeamNoteChunk]
        var staveMask: [Int]
        var beamMask: [Int]
        var clef: ClefName
    }

    private struct CrossBeamCaseSpec {
        var time: TimeSignatureSpec
        var voices: [CrossBeamVoiceSpec]
    }

    private func drawCrossBeamCase(_ spec: CrossBeamCaseSpec, factory: Factory, context: SVGRenderContext) throws {
        context.scale(0.8, 0.8)

        let score = factory.EasyScore()
        let system = factory.System(options: SystemOptions(
            factory: factory,
            debugFormatter: false,
            autoWidth: true,
            width: nil,
            details: SystemFormatterOptions(softmaxFactor: 100)
        ))

        var staveMap: [Stave] = []
        for voiceSpec in spec.voices {
            let stave = system.addStave(SystemStave(voices: []))
            _ = stave.addClef(voiceSpec.clef).addTimeSignature(spec.time)
            staveMap.append(stave)
        }

        for voiceSpec in spec.voices {
            var scoreNotes: [StemmableNote] = []
            for chunk in voiceSpec.notes where !chunk.notestring.isEmpty {
                scoreNotes += score.notes(chunk.notestring, options: ["clef": chunk.clef.rawValue])
            }

            #expect(scoreNotes.count == voiceSpec.staveMask.count)
            #expect(scoreNotes.count == voiceSpec.beamMask.count)

            var beamGroups: [[StemmableNote]] = []
            var currentGroup: [StemmableNote] = []

            for index in 0..<scoreNotes.count {
                let note = scoreNotes[index]
                _ = note.setStave(staveMap[voiceSpec.staveMask[index]])

                let beamDirection = voiceSpec.beamMask[index]
                if beamDirection != 0 {
                    _ = note.setStemDirection(beamDirection > 0 ? .up : .down)
                    currentGroup.append(note)
                } else if !currentGroup.isEmpty {
                    beamGroups.append(currentGroup)
                    currentGroup = []
                }
            }

            if !currentGroup.isEmpty {
                beamGroups.append(currentGroup)
            }

            for group in beamGroups {
                _ = score.beam(group)
            }

            if !scoreNotes.isEmpty {
                let voice = score.voice(scoreNotes.map { $0 as Note }, time: spec.time)
                system.addVoices([voice])
            }
        }

        try factory.draw()
    }

    private func crossBeamVerticalAlignmentCase(
        topNotes: [CrossBeamNoteChunk],
        topBeamMask: [Int],
        topStaveMask: [Int]
    ) -> CrossBeamCaseSpec {
        CrossBeamCaseSpec(
            time: .meter(4, 4),
            voices: [
                CrossBeamVoiceSpec(
                    notes: topNotes,
                    staveMask: topStaveMask,
                    beamMask: topBeamMask,
                    clef: .treble
                ),
                CrossBeamVoiceSpec(
                    notes: [CrossBeamNoteChunk(notestring: "", clef: .bass)],
                    staveMask: [],
                    beamMask: [],
                    clef: .bass
                ),
            ]
        )
    }

    private var crossBeamSingleClefMixed1: CrossBeamCaseSpec {
        CrossBeamCaseSpec(
            time: .meter(3, 4),
            voices: [
                CrossBeamVoiceSpec(
                    notes: [CrossBeamNoteChunk(
                        notestring: "g4/16, f4/16, a6/16, g6/16, b4/4/r, g6/8, g4/8",
                        clef: .treble
                    )],
                    staveMask: [0, 0, 0, 0, 0, 0, 0],
                    beamMask: [1, 1, -1, -1, 0, -1, 1],
                    clef: .treble
                ),
            ]
        )
    }

    private var crossBeamSingleClefMixed2: CrossBeamCaseSpec {
        CrossBeamCaseSpec(
            time: .meter(3, 4),
            voices: [
                CrossBeamVoiceSpec(
                    notes: [CrossBeamNoteChunk(
                        notestring: "g4/16, f6/16, a4/16, g6/16, b4/4/r, g6/8, g4/8",
                        clef: .treble
                    )],
                    staveMask: [0, 0, 0, 0, 0, 0, 0],
                    beamMask: [1, -1, 1, -1, 0, -1, 1],
                    clef: .treble
                ),
            ]
        )
    }

    private var crossBeamMixedClefVoiceMiddle: CrossBeamCaseSpec {
        CrossBeamCaseSpec(
            time: .meter(2, 4),
            voices: [
                CrossBeamVoiceSpec(
                    notes: [CrossBeamNoteChunk(
                        notestring: "e#5/4, b4/16/r, b4/16, d5/16., c5/32",
                        clef: .treble
                    )],
                    staveMask: [0, 0, 0, 0, 0],
                    beamMask: [0, 0, 1, 1, 1],
                    clef: .treble
                ),
                CrossBeamVoiceSpec(
                    notes: [
                        CrossBeamNoteChunk(notestring: "c3/16, b3/16, c4/16", clef: .bass),
                        CrossBeamNoteChunk(notestring: "e#4/16", clef: .treble),
                        CrossBeamNoteChunk(notestring: "c4/4", clef: .bass),
                    ],
                    staveMask: [1, 1, 1, 0, 1],
                    beamMask: [1, 1, 1, -1, 0],
                    clef: .bass
                ),
            ]
        )
    }

    private var crossBeamVerticalUp1: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, b4/q, a4/8, e4/8", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/8, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 1, 1, 1, 1],
            topStaveMask: [0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalUp2: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/16, b4/q, a4/8, e4/16", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/8, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, 1, 1, 1, 1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalUp3: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/16, b4/q, a4/8, e4/8", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/16, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, 1, 1, 1, 1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalUp4: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/8, b4/q, a4/8, e4/16", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/16, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, 1, 1, 1, 1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalDown1: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, b4/q, a4/8, e4/8", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/8, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, -1, -1, -1, -1],
            topStaveMask: [0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalDown2: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/16, b4/q, a4/8, e4/16", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/8, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, -1, -1, -1, -1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalDown3: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/16, b4/q, a4/8, e4/8", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/16, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, -1, -1, -1, -1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalDown4: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/8, b4/q, a4/8, e4/16", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/16, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, -1, -1, -1, -1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalMiddle1: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, b4/q, a4/8, e4/8", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/8, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, -1, -1, 1, 1],
            topStaveMask: [0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalMiddle2: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/16, b4/q, a4/8, e4/16", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/8, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, -1, -1, 1, 1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalMiddle3: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/16, b4/q, a4/8, e4/8", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/16, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, -1, -1, 1, 1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    private var crossBeamVerticalMiddle4: CrossBeamCaseSpec {
        crossBeamVerticalAlignmentCase(
            topNotes: [
                CrossBeamNoteChunk(notestring: "c#5/q, c5/8, b4/q, a4/8, e4/16", clef: .treble),
                CrossBeamNoteChunk(notestring: "c4/16, d4/8", clef: .bass),
            ],
            topBeamMask: [0, 0, 0, -1, -1, 1, 1],
            topStaveMask: [0, 0, 0, 0, 0, 1, 1]
        )
    }

    @Test("CrossBeam.Single_clef_mixed_1")
    func crossBeamSingleClefMixed1MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "CrossBeam", test: "Single_clef_mixed_1", width: 422, height: 250) { factory, context in
            try drawCrossBeamCase(crossBeamSingleClefMixed1, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Single_clef_mixed_2")
    func crossBeamSingleClefMixed2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "CrossBeam", test: "Single_clef_mixed_2", width: 422, height: 250) { factory, context in
            try drawCrossBeamCase(crossBeamSingleClefMixed2, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Mixed_clef_voice_middle")
    func crossBeamMixedClefVoiceMiddleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "CrossBeam", test: "Mixed_clef_voice_middle", width: 422, height: 250) { factory, context in
            try drawCrossBeamCase(crossBeamMixedClefVoiceMiddle, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_up1_")
    func crossBeamVerticalAlignmentBeamUp1MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_up1_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalUp1, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_up2_")
    func crossBeamVerticalAlignmentBeamUp2MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_up2_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalUp2, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_up3_")
    func crossBeamVerticalAlignmentBeamUp3MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_up3_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalUp3, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_up4_")
    func crossBeamVerticalAlignmentBeamUp4MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_up4_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalUp4, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_down1_")
    func crossBeamVerticalAlignmentBeamDown1MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_down1_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalDown1, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_down2_")
    func crossBeamVerticalAlignmentBeamDown2MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_down2_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalDown2, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_down3_")
    func crossBeamVerticalAlignmentBeamDown3MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_down3_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalDown3, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_down4_")
    func crossBeamVerticalAlignmentBeamDown4MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_down4_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalDown4, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_middle1_")
    func crossBeamVerticalAlignmentBeamMiddle1MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_middle1_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalMiddle1, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_middle2_")
    func crossBeamVerticalAlignmentBeamMiddle2MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_middle2_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalMiddle2, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_middle3_")
    func crossBeamVerticalAlignmentBeamMiddle3MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_middle3_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalMiddle3, factory: factory, context: context)
        }
    }

    @Test("CrossBeam.Vertical_alignment___cross_stave__beam_middle4_")
    func crossBeamVerticalAlignmentBeamMiddle4MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "CrossBeam",
            test: "Vertical_alignment___cross_stave__beam_middle4_",
            width: 422,
            height: 250
        ) { factory, context in
            try drawCrossBeamCase(crossBeamVerticalMiddle4, factory: factory, context: context)
        }
    }
}
