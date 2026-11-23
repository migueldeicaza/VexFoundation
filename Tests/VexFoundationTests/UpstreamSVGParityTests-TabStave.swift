import Testing
@testable import VexFoundation

// Ports of upstream `tests/tabstave_tests.ts` (VexFlow 5.6.1).
extension UpstreamSVGParityTests {
    @Test("TabStave.TabStave_Draw_Test")
    func tabStaveDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabStave", test: "TabStave_Draw_Test", width: 400, height: 160) { _, context in
            let stave = TabStave(x: 10, y: 10, width: 300)
            _ = stave.setMeasure(1)
            _ = stave.setNumLines(6)
            _ = stave.setContext(context)
            try stave.drawWithStyle()
        }
    }

    /// Compare full and courtesy clefs at two string spacings, with six strings as the control. (VexFlow 5.6.1)
    @Test("TabStave.Four_string_TAB_clefs")
    func tabStaveFourStringClefsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabStave", test: "Four_string_TAB_clefs", width: 500, height: 160) { _, context in
            for (index, spacing) in [13.0, 9.0].enumerated() {
                // Upstream `{ spacingBetweenLinesPx }` keeps the TabStave default of six strings.
                let stave = TabStave(
                    x: 10 + Double(index) * 160, y: 10, width: 145,
                    options: StaveOptions(spacingBetweenLinesPx: spacing, numLines: 6)
                )
                _ = stave.setContext(context)
                _ = stave.setStyle(ElementStyle(lineWidth: Double(index + 1)))
                    .addClef(.tab)
                    .addEndClef(.tab, size: .small)
                let sixStartX = stave.getNoteStartX()
                _ = stave.setNumLines(4)
                let clefs = stave.getModifiers(category: Clef.category).compactMap { $0 as? Clef }
                #expect(clefs.count == 2)
                #expect(clefs.allSatisfy { $0.code == Glyphs.fourStringTabClef })
                #expect(stave.getNoteStartX() < sixStartX)
                try stave.drawWithStyle()
                let inline = ClefNote(type: .tab).setStave(stave)
                #expect(inline.getClef().code == clefs[0].code)
                _ = stave.setNumLines(6)
                #expect(clefs[0].code == Glyphs.sixStringTabClef)
                #expect(stave.getNoteStartX() == sixStartX)
            }
            let six = TabStave(x: 330, y: 10, width: 150)
            _ = six.setContext(context)
            _ = six.addClef(.tab)
            try six.draw()
            let clef = six.getModifiers(category: Clef.category).first as? Clef
            #expect(clef?.line == 2.5)
        }
    }

    /// Show standard and courtesy clefs on the same string spacing for direct comparison. (VexFlow 5.6.1)
    @Test("TabStave.TAB_clef_by_string_count")
    func tabStaveClefByStringCountMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabStave", test: "TAB_clef_by_string_count", width: 470, height: 250) { _, context in
            for (index, strings) in [4, 5, 6, 7].enumerated() {
                let x = 12 + Double(index % 2) * 230
                let y = 25 + Double(index / 2) * 115
                let stave = TabStave(
                    x: x, y: y, width: 210, options: StaveOptions(spaceAboveStaffLn: 0, numLines: strings)
                )
                _ = stave.setContext(context)
                _ = stave.addClef(.tab).addEndClef(.tab, size: .small)
                _ = context.save()
                _ = context.setFont("Arial", 10, nil, nil)
                _ = context.fillText("\(strings) strings", x, y - 9)
                _ = context.restore()
                try stave.draw()
                for clef in stave.getModifiers(category: Clef.category).compactMap({ $0 as? Clef }) {
                    let ink = try clef.getInkBounds()
                    let above = ink.y - (stave.getYForDrawnLine(0) + 0.5)
                    let below = stave.getYForDrawnLine(Double(strings - 1)) - 0.5 - ink.y - ink.h
                    #expect(abs(above - below) < 0.01)
                }
            }
        }
    }

    /// Compare stacked, single-row, common and cut meters against the midpoint of the drawn strings.
    /// (VexFlow 5.6.1)
    @Test("TabStave.Time_signatures_by_string_count")
    func tabStaveTimeSignaturesByStringCountMatchesUpstream() throws {
        func meter(_ raw: String) throws -> TimeSignatureSpec {
            if let spec = TimeSignatureSpec(parsing: raw) { return spec }
            // Upstream `'3'`: a single numeric row.
            guard let digits = TimeSignatureDigits(rawValue: raw) else { throw VexError("BadArguments", raw) }
            return .topOnly(digits)
        }
        try runCategorySVGParityCase(
            module: "TabStave", test: "Time_signatures_by_string_count", width: 490, height: 250
        ) { _, context in
            for (index, strings) in [4, 5, 6, 7].enumerated() {
                let x = 12 + Double(index % 2) * 245
                let y = 25 + Double(index / 2) * 115
                let stave = TabStave(
                    x: x, y: y, width: 225, options: StaveOptions(spaceAboveStaffLn: 0, numLines: strings)
                )
                _ = stave.setContext(context)
                _ = stave.addClef(.tab)
                    .addTimeSignature(try meter("4/4"))
                    .addTimeSignature(try meter("6/8"))
                    .addTimeSignature(try meter("3"))
                    .addTimeSignature(try meter("C"))
                    .addEndTimeSignature(try meter("C|"))
                _ = context.save()
                _ = context.setFont("Arial", 10, nil, nil)
                _ = context.fillText("\(strings) strings", x, y - 9)
                _ = context.restore()
                try stave.draw()
                for time in stave.getModifiers(category: TimeSignature.category).compactMap({ $0 as? TimeSignature }) {
                    let ink = try time.getInkBounds()
                    let center = stave.getYForDrawnLine(Double(strings - 1) / 2)
                    #expect(ink.h > 0 && abs(ink.y + ink.h / 2 - center) < 0.01)
                }
            }
        }
    }
}
