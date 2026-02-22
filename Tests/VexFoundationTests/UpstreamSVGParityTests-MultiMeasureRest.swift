import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("MultiMeasureRest.Simple_Test")
    func multiMeasureRestSimpleTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "MultiMeasureRest", test: "Simple_Test", width: 910, height: 300) {
            factory,
            context in
            let width = 910.0
            let lineSpacing15 = StaveOptions(spacingBetweenLinesPx: 15)

            let params: [(StaveOptions?, MultiMeasureRestRenderOptions)] = [
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 2, showNumber: false)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 2)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 2, lineThickness: 8, serifThickness: 3)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 1, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 2, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 3, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 4, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 5, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 6, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 7, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 8, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 9, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 10, useSymbols: true)),
                (nil, MultiMeasureRestRenderOptions(numberOfMeasures: 11, useSymbols: true)),
                (
                    nil,
                    MultiMeasureRestRenderOptions(
                        numberOfMeasures: 11,
                        useSymbols: false,
                        paddingLeft: 20,
                        paddingRight: 20
                    )
                ),
                (
                    nil,
                    MultiMeasureRestRenderOptions(numberOfMeasures: 11, useSymbols: true, symbolSpacing: 5)
                ),
                (
                    nil,
                    MultiMeasureRestRenderOptions(numberOfMeasures: 11, useSymbols: false, numberLine: 2, line: 3)
                ),
                (
                    nil,
                    MultiMeasureRestRenderOptions(numberOfMeasures: 11, useSymbols: true, numberLine: 2, line: 3)
                ),
                (lineSpacing15, MultiMeasureRestRenderOptions(numberOfMeasures: 12)),
                (lineSpacing15, MultiMeasureRestRenderOptions(numberOfMeasures: 9, useSymbols: true)),
                (
                    lineSpacing15,
                    MultiMeasureRestRenderOptions(
                        numberOfMeasures: 12,
                        numberGlyphPoint: 40 * 1.5,
                        spacingBetweenLinesPx: 15
                    )
                ),
                (
                    lineSpacing15,
                    MultiMeasureRestRenderOptions(
                        numberOfMeasures: 9,
                        useSymbols: true,
                        numberGlyphPoint: 40 * 1.5,
                        spacingBetweenLinesPx: 15
                    )
                ),
                (
                    lineSpacing15,
                    MultiMeasureRestRenderOptions(
                        numberOfMeasures: 9,
                        useSymbols: true,
                        numberGlyphPoint: 40 * 1.5,
                        spacingBetweenLinesPx: 15,
                        semibreveRestGlyphScale: Tables.NOTATION_FONT_SCALE * 1.5
                    )
                ),
            ]

            let staveWidth = 100.0
            var x = 0.0
            var y = 0.0
            var mmRests: [MultiMeasureRest] = []

            for (staveOptions, mmrOptions) in params {
                if x + staveWidth * 2 > width {
                    x = 0
                    y += 80
                }

                let stave = factory.Stave(x: x, y: y, width: staveWidth, options: staveOptions)
                x += staveWidth
                let mmRest = factory.MultiMeasureRest(numberOfMeasures: mmrOptions.numberOfMeasures, options: mmrOptions)
                _ = mmRest.setStave(stave)
                mmRests.append(mmRest)
            }

            try factory.draw()

            let xs = mmRests[0].getXs()
            if let stave = mmRests[0].getStave() {
                let textY = stave.getYForLine(-0.5)
                let text = "TACET"

                _ = context.save()
                _ = context.setFont(FontInfo(family: VexFont.SERIF, size: 16, weight: VexFontWeight.bold.rawValue))
                let metrics = context.measureText(text)
                _ = context.fillText(text, xs.left + (xs.right - xs.left) * 0.5 - metrics.width * 0.5, textY)
                _ = context.restore()
            }
        }
    }

    @Test("MultiMeasureRest.Stave_with_modifiers_Test")
    func multiMeasureRestStaveWithModifiersTestMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "MultiMeasureRest",
            test: "Stave_with_modifiers_Test",
            width: 910,
            height: 200
        ) { factory, _ in
            struct StaveModifierSpec {
                var clef: ClefName? = nil
                var timeSig: TimeSignatureSpec? = nil
                var keySig: String? = nil
                var endClef: ClefName? = nil
                var endKeySig: String? = nil
                var endTimeSig: TimeSignatureSpec? = nil
                var width: Double = 150
            }

            let params: [(StaveModifierSpec, MultiMeasureRestRenderOptions)] = [
                (.init(clef: .treble), MultiMeasureRestRenderOptions(numberOfMeasures: 5)),
                (.init(clef: .treble, keySig: "G"), MultiMeasureRestRenderOptions(numberOfMeasures: 5)),
                (
                    .init(clef: .treble, timeSig: .meter(4, 4), keySig: "G"),
                    MultiMeasureRestRenderOptions(numberOfMeasures: 5)
                ),
                (.init(clef: .treble, endClef: .bass), MultiMeasureRestRenderOptions(numberOfMeasures: 5)),
                (.init(clef: .treble, endKeySig: "F"), MultiMeasureRestRenderOptions(numberOfMeasures: 5)),
                (.init(clef: .treble, endTimeSig: .meter(2, 4)), MultiMeasureRestRenderOptions(numberOfMeasures: 5)),
                (
                    .init(clef: .treble, endClef: .bass, endTimeSig: .meter(2, 4)),
                    MultiMeasureRestRenderOptions(numberOfMeasures: 5)
                ),
                (
                    .init(clef: .treble, endClef: .bass, endTimeSig: .meter(2, 4)),
                    MultiMeasureRestRenderOptions(numberOfMeasures: 5, useSymbols: true)
                ),
            ]

            let width = 910.0
            var x = 0.0
            var y = 0.0

            for (staveSpec, mmrOptions) in params {
                if x + staveSpec.width > width {
                    x = 0
                    y += 80
                }

                let stave = factory.Stave(x: x, y: y, width: staveSpec.width)
                x += staveSpec.width

                if let clef = staveSpec.clef {
                    _ = stave.addClef(clef)
                }
                if let timeSig = staveSpec.timeSig {
                    _ = stave.addTimeSignature(timeSig)
                }
                if let keySig = staveSpec.keySig {
                    _ = stave.addKeySignature(keySig)
                }
                if let endClef = staveSpec.endClef {
                    _ = stave.addEndClef(endClef)
                }
                if let endKeySig = staveSpec.endKeySig {
                    _ = stave.setEndKeySignature(endKeySig)
                }
                if let endTimeSig = staveSpec.endTimeSig {
                    _ = stave.setEndTimeSignature(endTimeSig)
                }

                let mmRest = factory.MultiMeasureRest(numberOfMeasures: mmrOptions.numberOfMeasures, options: mmrOptions)
                _ = mmRest.setStave(stave)
            }

            try factory.draw()
        }
    }
}
