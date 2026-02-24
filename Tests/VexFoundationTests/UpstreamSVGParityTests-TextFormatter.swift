import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("TextFormatter.Accuracy")
    func textFormatterAccuracyMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "TextFormatter",
            test: "Accuracy",
            width: 600,
            height: 500,
            referenceFontsOverride: ["Bravura"]
        ) { _, context in
            let lineHeight = 30.0
            let startX = 50.0
            var startY = 20.0

            let fonts = [
                FontInfo(
                    family: VexFont.SERIF,
                    size: 14,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.normal.rawValue
                ),
                FontInfo(
                    family: "Roboto Slab",
                    size: 14,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.normal.rawValue
                ),
                FontInfo(
                    family: VexFont.SANS_SERIF,
                    size: 14,
                    weight: VexFontWeight.bold.rawValue,
                    style: VexFontStyle.normal.rawValue
                ),
            ]

            let texts = [
                "AVo(i)a",
                "bghjIVex1/2",
                "@@@@@@@@",
                "a very long String with Mixed Case Text,(0123456789)",
            ]

            for font in fonts {
                let textFormatter = TextFormatter.create(font: font)
                _ = context.setFont(font)
                for text in texts {
                    _ = context.setFillStyle("black")
                    _ = context.fillText(text, startX, startY)

                    startY += 5
                    _ = context.setFillStyle("#3a2")
                    _ = context.fillRect(startX, startY, textFormatter.getWidthForTextInPx(text), 2)

                    _ = context.setFillStyle("#32a")
                    startY += 5
                    let measured = context.measureText(text)
                    _ = context.fillRect(startX, startY, measured.width, 2)

                    startY += lineHeight
                }
            }
        }
    }

    @Test("TextFormatter.Box_Text")
    func textFormatterBoxTextMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "TextFormatter",
            test: "Box_Text",
            width: 600,
            height: 800,
            referenceFontsOverride: ["Bravura"]
        ) { _, context in
            var startY = 35.0
            let boxBorder = 2.0
            let boxPadding = 3.0
            let startX = 50.0

            let fonts = [
                FontInfo(
                    family: VexFont.SERIF,
                    size: 14,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.normal.rawValue
                ),
                FontInfo(
                    family: "Roboto Slab",
                    size: 14,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.normal.rawValue
                ),
                FontInfo(
                    family: VexFont.SANS_SERIF,
                    size: 14,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.normal.rawValue
                ),
            ]

            let texts = ["AVID", "bghjIVex1/2", "@@@@@@@@"]

            for font in fonts {
                let textFormatter = TextFormatter.create(font: font)
                _ = context.save()
                _ = context.setFont(font)

                for text in texts {
                    let textY = textFormatter.getYForStringInPx(text)
                    let height = textY.height + 2 * boxPadding
                    let headroom = -1 * textY.yMin
                    let width = textFormatter.getWidthForTextInPx(text) + 2 * boxPadding

                    _ = context.setFillStyle("black")
                    _ = context.fillText(text, startX + boxPadding, startY - boxPadding)
                    _ = context.setLineWidth(boxBorder)
                    _ = context.setStrokeStyle("#3a2")
                    _ = context.setFillStyle("#3a2")
                    _ = context.beginPath()
                    _ = context.rect(startX, startY - height + headroom, width, height)
                    _ = context.stroke()

                    startY += height * 1.5 + boxBorder * 3

                    let measureBox = context.measureText(text)
                    let measuredWidth = measureBox.width + boxBorder * 2
                    let measuredHeight = measureBox.height + boxBorder * 2

                    _ = context.setFillStyle("black")
                    _ = context.fillText(text, startX + boxPadding, startY - boxPadding)
                    _ = context.setStrokeStyle("#32a")
                    _ = context.setFillStyle("#32a")
                    _ = context.beginPath()
                    _ = context.rect(startX, startY - measuredHeight, measuredWidth, measuredHeight)
                    _ = context.stroke()

                    startY += measuredHeight * 1.5 + boxBorder * 3
                }

                _ = context.restore()
            }
        }
    }
}
