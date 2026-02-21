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

                if actualSignature != expectedSignature {
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
                        """
                    )
                }
            }
        }
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

    private func normalizedSVGText(_ svg: String) -> String {
        var text = svg.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #" id="[^"]*""#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
