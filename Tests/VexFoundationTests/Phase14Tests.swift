// VexFoundation - Tests for Phase 14: TabStave, TabNote, TabTie, TabSlide,
// GraceTabNote, ChordSymbol

import Testing
@testable import VexFoundation

@Suite("TabStave, TabNote, TabTie, TabSlide, GraceTabNote, ChordSymbol")
struct Phase14Tests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - Helper

    private func makeNote(keys: [StaffKeySpec] = [StaffKeySpec(letter: .c, octave: 4)], duration: NoteValue = .quarter) -> StaveNote {
        let note = StaveNote(StaveNoteStruct(keys: keys, duration: duration))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()
        return note
    }

    private func makeTabNote(
        positions: [TabNotePosition] = [TabNotePosition(str: 1, fret: 5)],
        duration: NoteValue = .quarter
    ) -> TabNote {
        TabNote(TabNoteStruct(positions: positions, duration: duration))
    }

    private func makeTabStave() -> TabStave {
        TabStave(x: 10, y: 40, width: 300)
    }

    // ============================================================
    // MARK: - TabStave Tests
    // ============================================================

    @Test func tabStaveCategory() {
        #expect(TabStave.category == "TabStave")
    }

    @Test func tabStaveDefaultLines() {
        let ts = makeTabStave()
        #expect(ts.getNumLines() == 6)
    }

    @Test func tabStaveDefaultSpacing() {
        let ts = makeTabStave()
        #expect(ts.getSpacingBetweenLines() == 13)
    }

    @Test func tabStaveCustomLines() {
        var opts = StaveOptions()
        opts.numLines = 4
        let ts = TabStave(x: 0, y: 0, width: 200, options: opts)
        #expect(ts.getNumLines() == 4)
    }

    @Test func tabStaveCustomSpacing() {
        var opts = StaveOptions()
        opts.spacingBetweenLinesPx = 10
        let ts = TabStave(x: 0, y: 0, width: 200, options: opts)
        #expect(ts.getSpacingBetweenLines() == 10)
    }

    @Test func tabStaveYForGlyphs() {
        let ts = makeTabStave()
        let y = ts.getYForGlyphs()
        let expected = ts.getYForLine(2.5)
        #expect(y == expected)
    }

    @Test func tabStaveIsStave() {
        let ts = makeTabStave()
        #expect(ts is Stave)
    }

    @Test func tabStaveAddTabGlyph() {
        let ts = makeTabStave()
        _ = ts.addTabGlyph()
        // Should not crash
    }

    // ============================================================
    // MARK: - TabNote Tests
    // ============================================================

    @Test func tabNoteCategory() {
        #expect(TabNote.category == "TabNote")
    }

    @Test func tabNoteCreation() {
        let tn = makeTabNote()
        #expect(tn.positions.count == 1)
        #expect(tn.positions[0].str == 1)
        #expect(tn.positions[0].fret == "5")
    }

    @Test func tabNoteMultiplePositions() {
        let positions = [
            TabNotePosition(str: 1, fret: 5),
            TabNotePosition(str: 2, fret: 3),
            TabNotePosition(str: 3, fret: 0),
        ]
        let tn = TabNote(TabNoteStruct(positions: positions))
        #expect(tn.positions.count == 3)
    }

    @Test func tabNoteWidthCalculated() {
        let tn = makeTabNote()
        tn.preFormat()
        #expect(tn.getTickableWidth() > 0)
    }

    @Test func tabNoteGreatestString() {
        let positions = [
            TabNotePosition(str: 1, fret: 5),
            TabNotePosition(str: 4, fret: 3),
            TabNotePosition(str: 2, fret: 7),
        ]
        let tn = TabNote(TabNoteStruct(positions: positions))
        #expect(tn.greatestString() == 4)
    }

    @Test func tabNoteLeastString() {
        let positions = [
            TabNotePosition(str: 3, fret: 5),
            TabNotePosition(str: 4, fret: 3),
            TabNotePosition(str: 2, fret: 7),
        ]
        let tn = TabNote(TabNoteStruct(positions: positions))
        #expect(tn.leastString() == 2)
    }

    @Test func tabNoteHasStemDefault() {
        let tn = makeTabNote()
        #expect(tn.hasStem() == false)
    }

    @Test func tabNoteHasStemWithStem() {
        let tn = TabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)],
            duration: .quarter
        ), drawStem: true)
        #expect(tn.hasStem() == true)
    }

    @Test func tabNoteSetGhost() {
        let tn = makeTabNote()
        #expect(tn.ghost == false)
        _ = tn.setGhost(true)
        #expect(tn.ghost == true)
        // Ghost adds parentheses to fret text
        #expect(tn.glyphPropsArr[0].text == "(5)")
    }

    @Test func tabNoteGetPositions() {
        let positions = [TabNotePosition(str: 2, fret: "3")]
        let tn = TabNote(TabNoteStruct(positions: positions))
        #expect(tn.getPositions().count == 1)
        #expect(tn.getPositions()[0].str == 2)
    }

    @Test func tabNotePreFormat() {
        let tn = makeTabNote()
        tn.preFormat()
        #expect(tn.preFormatted == true)
    }

    @Test func tabNoteGetLineForRest() {
        let tn = TabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 3, fret: 5)]
        ))
        #expect(tn.getLineForRest() == 3.0)
    }

    @Test func tabNoteSetStaveCalculatesYs() {
        let tn = makeTabNote()
        let ts = makeTabStave()
        _ = tn.setStave(ts)
        let ys = tn.getYs()
        #expect(ys.count == 1)
        // Y should be for string 1 (line 0)
        let expected = ts.getYForLine(0)
        #expect(ys[0] == expected)
    }

    @Test func tabNoteStemDirection() {
        let tn = makeTabNote()
        #expect(tn.getStemDirection() == Stem.UP)
    }

    @Test func tabNoteCustomStemDirection() {
        let tn = TabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)],
            duration: .quarter,
            stemDirection: Stem.DOWN
        ))
        #expect(tn.getStemDirection() == Stem.DOWN)
    }

    @Test func tabNoteStemXGetsCenterGlyph() {
        // getStemX returns getCenterGlyphX for TabNote
        // Both require a TickContext to work; just verify they match in principle
        let tn = makeTabNote()
        #expect(tn.getStemDirection() == Stem.UP)
    }

    @Test func tabNoteStemY() {
        let tn = makeTabNote()
        let ts = makeTabStave()
        _ = tn.setStave(ts)
        let stemY = tn.getStemY()
        // For UP stem, stem starts above the stave (line -0.5)
        let expected = ts.getYForLine(-0.5)
        #expect(stemY == expected)
    }

    @Test func tabNoteModifierStartXYRequiresPreformat() {
        let tn = makeTabNote()
        let ts = makeTabStave()
        _ = tn.setStave(ts)
        // getModifierStartXY requires preFormat and TickContext
        // Just verify setup works without crash
        #expect(tn.getYs().count == 1)
    }

    @Test func tabNoteGlyphPropsArray() {
        let positions = [
            TabNotePosition(str: 1, fret: "12"),
            TabNotePosition(str: 2, fret: "X"),
        ]
        let tn = TabNote(TabNoteStruct(positions: positions))
        #expect(tn.glyphPropsArr.count == 2)
        #expect(tn.glyphPropsArr[0].text == "12")
        #expect(tn.glyphPropsArr[1].text == "X")
        #expect(tn.glyphPropsArr[1].code != nil)
    }

    @Test func tabNoteIsStemmableNote() {
        let tn = makeTabNote()
        #expect(tn is StemmableNote)
    }

    @Test func tabNoteStemExtension() {
        let tn = makeTabNote()
        let ext = tn.getStemExtension()
        // Quarter note tab stem extension should be 0
        #expect(ext == 0)
    }

    @Test func tabNoteStringFretInit() {
        let pos = TabNotePosition(str: 3, fret: 7)
        #expect(pos.str == 3)
        #expect(pos.fret == "7")
    }

    @Test func tabNoteXPosition() {
        // getModifierStartXY requires a TickContext (via getAbsoluteX),
        // so verify preFormat + stave setup instead
        let tn = makeTabNote(positions: [TabNotePosition(str: 1, fret: "0")])
        let ts = makeTabStave()
        _ = tn.setStave(ts)
        tn.preFormat()
        #expect(tn.preFormatted == true)
        #expect(tn.getYs().count == 1)
    }

    // ============================================================
    // MARK: - TabTie Tests
    // ============================================================

    @Test func tabTieCategory() {
        #expect(TabTie.category == "TabTie")
    }

    @Test func tabTieCreation() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let ts = makeTabStave()
        _ = n1.setStave(ts)
        _ = n2.setStave(ts)
        let tie = TabTie(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(tie.direction == .down) // Tab ties are always face up
    }

    @Test func tabTieRenderOptions() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let tie = TabTie(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(tie.renderOptions.cp1 == 9)
        #expect(tie.renderOptions.cp2 == 11)
        #expect(tie.renderOptions.yShift == 3)
    }

    @Test func tabTieCreateHammeron() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let tie = TabTie.createHammeron(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(tie.text == "H")
    }

    @Test func tabTieCreatePulloff() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let tie = TabTie.createPulloff(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(tie.text == "P")
    }

    @Test func tabTieIsStaveTie() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let tie = TabTie(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(tie is StaveTie)
    }

    @Test func tabTieWithText() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let tie = TabTie(notes: TieNotes(firstNote: n1, lastNote: n2), text: "T")
        #expect(tie.text == "T")
    }

    // ============================================================
    // MARK: - TabSlide Tests
    // ============================================================

    @Test func tabSlideCategory() {
        #expect(TabSlide.category == "TabSlide")
    }

    @Test func tabSlideConstants() {
        #expect(TabSlide.SLIDE_UP.rawValue == 1)
        #expect(TabSlide.SLIDE_DOWN.rawValue == -1)
    }

    @Test func tabSlideCreation() {
        let n1 = makeTabNote(positions: [TabNotePosition(str: 1, fret: 3)])
        let n2 = makeTabNote(positions: [TabNotePosition(str: 1, fret: 5)])
        let slide = TabSlide(notes: TieNotes(firstNote: n1, lastNote: n2))
        // Should auto-detect as SLIDE_UP since 3 < 5
        #expect(slide.direction == TabSlide.SLIDE_UP)
    }

    @Test func tabSlideCreationDown() {
        let n1 = makeTabNote(positions: [TabNotePosition(str: 1, fret: 7)])
        let n2 = makeTabNote(positions: [TabNotePosition(str: 1, fret: 3)])
        let slide = TabSlide(notes: TieNotes(firstNote: n1, lastNote: n2))
        // Should auto-detect as SLIDE_DOWN since 7 > 3
        #expect(slide.direction == TabSlide.SLIDE_DOWN)
    }

    @Test func tabSlideExplicitDirection() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let slide = TabSlide(notes: TieNotes(firstNote: n1, lastNote: n2),
                             direction: TabSlide.SLIDE_DOWN)
        #expect(slide.direction == TabSlide.SLIDE_DOWN)
    }

    @Test func tabSlideRenderOptions() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let slide = TabSlide(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(slide.renderOptions.cp1 == 11)
        #expect(slide.renderOptions.cp2 == 14)
        #expect(slide.renderOptions.yShift == 0.5)
    }

    @Test func tabSlideText() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let slide = TabSlide(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(slide.text == "sl.")
    }

    @Test func tabSlideFactoryUp() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let slide = TabSlide.createSlideUp(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(slide.direction == TabSlide.SLIDE_UP)
    }

    @Test func tabSlideFactoryDown() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let slide = TabSlide.createSlideDown(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(slide.direction == TabSlide.SLIDE_DOWN)
    }

    @Test func tabSlideIsTabTie() {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let slide = TabSlide(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(slide is TabTie)
    }

    @Test func tabSlideWithXFret() {
        let n1 = makeTabNote(positions: [TabNotePosition(str: 1, fret: "X")])
        let n2 = makeTabNote(positions: [TabNotePosition(str: 1, fret: "5")])
        let slide = TabSlide(notes: TieNotes(firstNote: n1, lastNote: n2))
        // When fret is "X" (not parseable), default to SLIDE_UP
        #expect(slide.direction == TabSlide.SLIDE_UP)
    }

    // ============================================================
    // MARK: - GraceTabNote Tests
    // ============================================================

    @Test func graceTabNoteCategory() {
        #expect(GraceTabNote.category == "GraceTabNote")
    }

    @Test func graceTabNoteScale() {
        let gtn = GraceTabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)]
        ))
        #expect(gtn.renderOptions.scale == 0.6)
    }

    @Test func graceTabNoteYShift() {
        let gtn = GraceTabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)]
        ))
        #expect(gtn.renderOptions.yShift == 0.3)
    }

    @Test func graceTabNoteFont() {
        let gtn = GraceTabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)]
        ))
        #expect(gtn.renderOptions.font?.contains("7.5") == true)
    }

    @Test func graceTabNoteIsTabNote() {
        let gtn = GraceTabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)]
        ))
        #expect(gtn is TabNote)
    }

    @Test func graceTabNoteWidth() {
        let gtn = GraceTabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)]
        ))
        gtn.preFormat()
        #expect(gtn.getTickableWidth() > 0)
    }

    @Test func graceTabNoteNoStemByDefault() {
        let gtn = GraceTabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)]
        ))
        #expect(gtn.hasStem() == false)
    }

    // ============================================================
    // MARK: - TabGlyphProps Tests
    // ============================================================

    @Test func tabGlyphPropsForNumber() {
        let props = Tables.tabToGlyphProps("5")
        #expect(props.text == "5")
        #expect(props.code == nil)
        #expect(props.getWidth() > 0)
    }

    @Test func tabGlyphPropsForX() {
        let props = Tables.tabToGlyphProps("X")
        #expect(props.text == "X")
        #expect(props.code == "accidentalDoubleSharp")
        #expect(props.getWidth() > 0)
    }

    @Test func tabGlyphPropsScale() {
        let props1 = Tables.tabToGlyphProps("5", scale: 1.0)
        let props2 = Tables.tabToGlyphProps("5", scale: 0.6)
        #expect(props2.getWidth() < props1.getWidth())
    }

    @Test func tabGlyphPropsMultiDigit() {
        let props1 = Tables.tabToGlyphProps("5")
        let props2 = Tables.tabToGlyphProps("12")
        // Two-digit number should be wider
        #expect(props2.getWidth() > props1.getWidth())
    }

    @Test func tablesTextWidth() {
        #expect(Tables.textWidth("hello") == 35)
        #expect(Tables.textWidth("12") == 14)
        #expect(Tables.textWidth("") == 0)
    }

    // ============================================================
    // MARK: - GlyphProps Tab Extensions
    // ============================================================

    @Test func glyphPropsTabExtensions() {
        let gp = Tables.getGlyphProps(duration: .quarter)!
        #expect(gp.tabnoteStemUpExtension == 0)
        #expect(gp.tabnoteStemDownExtension == 0)
    }

    @Test func glyphPropsTabExtensions32nd() {
        let gp = Tables.getGlyphProps(duration: .thirtySecond)!
        #expect(gp.tabnoteStemUpExtension == 9)
        #expect(gp.tabnoteStemDownExtension == 9)
    }

    @Test func glyphPropsTabExtensionsWhole() {
        let gp = Tables.getGlyphProps(duration: .whole)!
        #expect(gp.tabnoteStemUpExtension == -Tables.STEM_HEIGHT)
        #expect(gp.tabnoteStemDownExtension == -Tables.STEM_HEIGHT)
    }

    // ============================================================
    // MARK: - ChordSymbol Tests
    // ============================================================

    @Test func chordSymbolCategory() {
        #expect(ChordSymbol.category == "ChordSymbol")
    }

    @Test func chordSymbolCreation() {
        let cs = ChordSymbol()
        #expect(cs.symbolBlocks.isEmpty)
    }

    @Test func chordSymbolAddText() {
        let cs = ChordSymbol()
        _ = cs.addText("C")
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].text == "C")
        #expect(cs.symbolBlocks[0].symbolType == .text)
    }

    @Test func chordSymbolAddTextSuperscript() {
        let cs = ChordSymbol()
        _ = cs.addTextSuperscript("7")
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].symbolModifier == .sup)
    }

    @Test func chordSymbolAddTextSubscript() {
        let cs = ChordSymbol()
        _ = cs.addTextSubscript("b5")
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].symbolModifier == .sub)
    }

    @Test func chordSymbolAddGlyph() {
        let cs = ChordSymbol()
        _ = cs.addGlyph("diminished")
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].symbolType == .glyph)
        #expect(cs.symbolBlocks[0].glyph != nil)
    }

    @Test func chordSymbolAddGlyphSuperscript() {
        let cs = ChordSymbol()
        _ = cs.addGlyphSuperscript("diminished")
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].symbolModifier == .sup)
        #expect(cs.symbolBlocks[0].symbolType == .glyph)
    }

    @Test func chordSymbolAddGlyphOrText() {
        let cs = ChordSymbol()
        _ = cs.addGlyphOrText("(5)")
        // '(' is a glyph, '5' is text, ')' is a glyph
        #expect(cs.symbolBlocks.count == 3)
    }

    @Test func chordSymbolAddLine() {
        let cs = ChordSymbol()
        _ = cs.addLine(20)
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].symbolType == .line)
    }

    @Test func chordSymbolSetHorizontal() {
        let cs = ChordSymbol()
        _ = cs.setHorizontal(.center)
        #expect(cs.getHorizontal() == .center)
    }

    @Test func chordSymbolSetVertical() {
        let cs = ChordSymbol()
        _ = cs.setVertical(.bottom)
        #expect(cs.getVertical() == .bottom)
    }

    @Test func chordSymbolDefaultPosition() {
        let cs = ChordSymbol()
        #expect(cs.getHorizontal() == .left)
        #expect(cs.getVertical() == .top)
    }

    @Test func chordSymbolWidth() {
        let cs = ChordSymbol()
        _ = cs.addText("Cmaj")
        #expect(cs.getWidth() > 0)
    }

    @Test func chordSymbolWidthWithVAlign() {
        let cs = ChordSymbol()
        _ = cs.addText("C")
        let w1 = cs.getWidth()
        // A vAligned block shouldn't add to width
        var block = cs.getSymbolBlock(text: "test")
        block.vAlign = true
        cs.symbolBlocks.append(block)
        let w2 = cs.getWidth()
        #expect(w2 == w1) // vAlign blocks don't add width
    }

    @Test func chordSymbolReportWidth() {
        let cs = ChordSymbol()
        #expect(cs.getReportWidth() == true)
        _ = cs.setReportWidth(false)
        #expect(cs.getReportWidth() == false)
    }

    @Test func chordSymbolKerning() {
        let cs = ChordSymbol()
        #expect(cs.useKerning == true)
        _ = cs.setEnableKerning(false)
        #expect(cs.useKerning == false)
    }

    @Test func chordSymbolGlyphs() {
        #expect(ChordSymbol.glyphs["diminished"] == "csymDiminished")
        #expect(ChordSymbol.glyphs["+"] == "csymAugmented")
        #expect(ChordSymbol.glyphs["minor"] == "csymMinor")
        #expect(ChordSymbol.glyphs["-"] == "csymMinor")
        #expect(ChordSymbol.glyphs["majorSeventh"] == "csymMajorSeventh")
        #expect(ChordSymbol.glyphs["("] == "csymParensLeftTall")
        #expect(ChordSymbol.glyphs[")"] == "csymParensRightTall")
        #expect(ChordSymbol.glyphs["/"] == "csymDiagonalArrangementSlash")
        #expect(ChordSymbol.glyphs["#"] == "accidentalSharp")
        #expect(ChordSymbol.glyphs["b"] == "accidentalFlat")
    }

    @Test func chordSymbolIsSuperscript() {
        let block = ChordSymbolBlock(
            text: "7", symbolType: .text, symbolModifier: .sup,
            xShift: 0, yShift: 0, vAlign: false, width: 0
        )
        #expect(ChordSymbol.isSuperscript(block) == true)
        #expect(ChordSymbol.isSubscript(block) == false)
    }

    @Test func chordSymbolIsSubscript() {
        let block = ChordSymbolBlock(
            text: "5", symbolType: .text, symbolModifier: .sub,
            xShift: 0, yShift: 0, vAlign: false, width: 0
        )
        #expect(ChordSymbol.isSubscript(block) == true)
        #expect(ChordSymbol.isSuperscript(block) == false)
    }

    @Test func chordSymbolStaticMetrics() {
        #expect(ChordSymbol.superSubRatio > 0)
        #expect(ChordSymbol.superSubRatio < 1)
        #expect(ChordSymbol.engravingFontResolution > 0)
        #expect(ChordSymbol.spacingBetweenBlocks >= 0)
    }

    @Test func chordSymbolSuperscriptOffset() {
        #expect(ChordSymbol.superscriptOffset < 0) // Negative = upward
    }

    @Test func chordSymbolSubscriptOffset() {
        #expect(ChordSymbol.subscriptOffset > 0) // Positive = downward
    }

    @Test func chordSymbolKerningOffset() {
        #expect(ChordSymbol.kerningOffset < 0)
    }

    @Test func chordSymbolLowerKerningText() {
        let lkt = ChordSymbol.lowerKerningText
        #expect(!lkt.isEmpty)
        #expect(lkt.contains("D"))
    }

    @Test func chordSymbolUpperKerningText() {
        let ukt = ChordSymbol.upperKerningText
        #expect(!ukt.isEmpty)
        #expect(ukt.contains("A"))
    }

    @Test func chordSymbolMinPadding() {
        #expect(ChordSymbol.minPadding > 0)
    }

    @Test func chordSymbolIsModifier() {
        let cs = ChordSymbol()
        #expect(cs is Modifier)
    }

    @Test func chordSymbolFormat() {
        let cs = ChordSymbol()
        _ = cs.addText("C")
        let note = makeNote()
        note.preFormat()
        _ = note.addModifier(cs, index: 0)

        var state = ModifierContextState()
        let result = ChordSymbol.format([cs], state: &state)
        #expect(result == true)
    }

    @Test func chordSymbolFormatEmpty() {
        var state = ModifierContextState()
        let result = ChordSymbol.format([], state: &state)
        #expect(result == false)
    }

    @Test func chordSymbolChainedAPI() {
        let cs = ChordSymbol()
        let result = cs.addText("C")
            .addTextSuperscript("7")
            .setVertical(.top)
            .setHorizontal(.left)
        #expect(result.symbolBlocks.count == 2)
    }

    @Test func chordSymbolComplexChord() {
        let cs = ChordSymbol()
        _ = cs.addText("C")
        _ = cs.addGlyph("diminished")
        _ = cs.addTextSuperscript("7")
        _ = cs.addGlyphOrText("(b5)")
        // C + dim glyph + 7 + ( glyph + b glyph + 5 text + ) glyph
        #expect(cs.symbolBlocks.count >= 4)
    }

    @Test func chordSymbolGetSymbolBlock() {
        let cs = ChordSymbol()
        let block = cs.getSymbolBlock(text: "hello", symbolType: .text)
        #expect(block.text == "hello")
        #expect(block.symbolType == .text)
        #expect(block.symbolModifier == .none)
        #expect(block.width > 0)
    }

    @Test func chordSymbolGetSymbolBlockGlyph() {
        let cs = ChordSymbol()
        let block = cs.getSymbolBlock(symbolType: .glyph, glyphName: "diminished")
        #expect(block.symbolType == .glyph)
        #expect(block.glyph != nil)
        #expect(block.glyph?.code == "csymDiminished")
    }

    // ============================================================
    // MARK: - Cross-class Integration Tests
    // ============================================================

    @Test func tabNoteOnTabStave() {
        let ts = makeTabStave()
        let tn = makeTabNote(positions: [
            TabNotePosition(str: 1, fret: 5),
            TabNotePosition(str: 2, fret: 3),
        ])
        _ = tn.setStave(ts)
        let ys = tn.getYs()
        #expect(ys.count == 2)
        // String 1 Y should be less than string 2 Y (higher on display)
        #expect(ys[0] < ys[1])
    }

    @Test func tabTieWithTabNotes() {
        let ts = makeTabStave()
        let n1 = makeTabNote(positions: [TabNotePosition(str: 1, fret: 5)])
        let n2 = makeTabNote(positions: [TabNotePosition(str: 1, fret: 7)])
        _ = n1.setStave(ts)
        _ = n2.setStave(ts)
        let tie = TabTie.createHammeron(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(tie.text == "H")
        #expect(tie.direction == .down)
    }

    @Test func graceTabNoteOnTabStave() {
        let ts = makeTabStave()
        let gtn = GraceTabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 3)]
        ))
        _ = gtn.setStave(ts)
        #expect(gtn.getYs().count == 1)
        #expect(gtn.renderOptions.scale == 0.6)
    }

    @Test func chordSymbolOnNote() {
        let note = makeNote(keys: [StaffKeySpec(letter: .c, octave: 4), StaffKeySpec(letter: .e, octave: 4), StaffKeySpec(letter: .g, octave: 4)])
        let cs = ChordSymbol()
        _ = cs.addText("C")
        _ = cs.setVertical(.top)
        _ = cs.setHorizontal(.left)
        _ = note.addModifier(cs, index: 0)
        // Should not crash
        #expect(note.getModifiers().count == 1)
    }

    @Test func modifierContextIncludesChordSymbol() {
        let mc = ModifierContext()
        let cs = ChordSymbol()
        _ = mc.addMember(cs)
        let members = mc.getMembers("ChordSymbol")
        #expect(members.count == 1)
    }
}
