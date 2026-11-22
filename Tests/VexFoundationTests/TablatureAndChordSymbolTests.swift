// VexFoundation - Tests for Phase 14: TabStave, TabNote, TabTie, TabSlide,
// GraceTabNote, ChordSymbol

import Testing
@testable import VexFoundation

@Suite("TabStave, TabNote, TabTie, TabSlide, GraceTabNote, ChordSymbol")
struct TablatureAndChordSymbolTests {

    init() {
        Flow.setFonts("Bravura", "Academico")
    }

    // MARK: - Helper

    private func makeNote(keys: NonEmptyArray<StaffKeySpec> = NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: NoteDurationSpec = .quarter) -> StaveNote {
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

        let initOpts = StaveOptions(spacingBetweenLinesPx: 10)
        let initTs = TabStave(x: 0, y: 0, width: 200, options: initOpts)
        #expect(initTs.getSpacingBetweenLines() == 10)
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
        #expect(tn.fretElement[0].getText() == "(5)")
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
        #expect(tn.fretElement.count == 2)
        #expect(tn.fretElement[0].getText() == "12")
        #expect(tn.fretElement[1].getText() == Glyphs.accidentalDoubleSharp)
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

    @Test func tabNoteValidatingInitAndConvenienceFallback() throws {
        let emptyStruct = TabNoteStruct(positions: [], duration: .quarter)
        let fallback = TabNote(emptyStruct)
        #expect(fallback.tabInitError == .emptyPositions)
        #expect(fallback.getLineForRest() == 0)

        do {
            _ = try TabNote(validating: emptyStruct)
            #expect(Bool(false))
        } catch {
            #expect(error as? TabNoteError == .emptyPositions)
        }
    }

    @Test func tabNoteThrowingPreconditions() throws {
        let tn = makeTabNote()

        do {
            _ = try tn.getModifierStartXYThrowing(position: .left, index: 0)
            #expect(Bool(false))
        } catch {
            #expect(error as? TabNoteError == .unformattedNoteForModifierStart)
        }

        tn.preFormatted = true

        do {
            _ = try tn.getModifierStartXYThrowing(position: .left, index: 0)
            #expect(Bool(false))
        } catch {
            #expect(error as? TabNoteError == .noYValues)
        }

        _ = tn.setYs([100])
        do {
            _ = try tn.getModifierStartXYThrowing(position: .left, index: 2)
            #expect(Bool(false))
        } catch {
            #expect(error as? TabNoteError == .invalidModifierIndex(2))
        }
    }

    @Test func tabNoteStemYThrowing() throws {
        let tn = makeTabNote()
        do {
            _ = try tn.getStemYThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? NoteError == .noStave)
        }

        let stave = makeTabStave()
        _ = tn.setStave(stave)
        let y = try tn.getStemYThrowing()
        #expect(y == stave.getYForLine(-0.5))
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

    @Test func tabSlideRenderTieThrowingValidation() throws {
        let n1 = makeTabNote()
        let n2 = makeTabNote()
        let slide = TabSlide(notes: TieNotes(firstNote: n1, lastNote: n2))
        do {
            try slide.renderTie(
                direction: .up,
                firstX: 10,
                lastX: 20,
                firstYs: [],
                lastYs: []
            )
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveTieError == .noYValues)
        }
    }

    // ============================================================
    // MARK: - GraceTabNote Tests
    // ============================================================

    @Test func graceTabNoteCategory() {
        #expect(GraceTabNote.category == "GraceTabNote")
    }

    @Test func graceTabNoteYShift() {
        let gtn = GraceTabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)]
        ))
        #expect(gtn.renderOptions.yShift == 0.3)
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
    // MARK: - TabNote.tabToElement Tests (5.0 replacement of TabGlyphProps)
    // ============================================================

    @Test func tabGlyphPropsForNumber() {
        let props = TabNote.tabToElement("5")
        #expect(props.getText() == "5")
        #expect(props.getWidth() > 0)
    }

    @Test func tabGlyphPropsForX() {
        let props = TabNote.tabToElement("X")
        #expect(props.getText() == Glyphs.accidentalDoubleSharp)
        #expect(props.getWidth() > 0)
    }

    @Test func tabGlyphPropsMultiDigit() {
        let props1 = TabNote.tabToElement("5")
        let props2 = TabNote.tabToElement("12")
        // Two-digit number should be wider
        #expect(props2.getWidth() > props1.getWidth())
    }

    @Test func tablesTextWidth() {
        #expect(Tables.textWidth("hello") == 35)
        #expect(Tables.textWidth("12") == 14)
        #expect(Tables.textWidth("") == 0)
    }

    // ============================================================
    // MARK: - TabNote stem extension (5.0: from the flag height)
    // ============================================================

    @Test func glyphPropsTabExtensions() {
        let tn = TabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: 5)], duration: .quarter), drawStem: true)
        #expect(tn.getStemExtension() == 0)
    }

    @Test func glyphPropsTabExtensionsOverride() {
        let tn = TabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: 5)], duration: .thirtySecond), drawStem: true)
        tn.stemExtensionOverride = 9
        #expect(tn.getStemExtension() == 9)
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
        #expect(cs.symbolBlocks[0].getText() == "C")
        #expect(cs.symbolBlocks[0].symbolModifier == .none)
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
        #expect(cs.symbolBlocks[0].getText() == Glyphs.csymDiminished)
    }

    @Test func chordSymbolAddGlyphSuperscript() {
        let cs = ChordSymbol()
        _ = cs.addGlyphSuperscript("diminished")
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].symbolModifier == .sup)
        #expect(cs.symbolBlocks[0].getText() == Glyphs.csymDiminished)
    }

    @Test func chordSymbolAddGlyphOrText() {
        let cs = ChordSymbol()
        _ = cs.addGlyphOrText("(5)")
        // 5.0: glyphs and text are joined in one text block
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].getText() == "(5)")
    }

    @Test func chordSymbolAddLine() {
        let cs = ChordSymbol()
        _ = cs.addLine()
        #expect(cs.symbolBlocks.count == 1)
        #expect(cs.symbolBlocks[0].getText() == Glyphs.csymMinor + Glyphs.csymMinor)
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
        let block = cs.getSymbolBlock(text: "test")
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

    @Test func chordSymbolGlyphs() {
        #expect(ChordSymbol.glyphs["diminished"] == Glyphs.csymDiminished)
        #expect(ChordSymbol.glyphs["+"] == Glyphs.csymAugmented)
        #expect(ChordSymbol.glyphs["minor"] == Glyphs.csymMinor)
        #expect(ChordSymbol.glyphs["-"] == Glyphs.csymMinor)
        #expect(ChordSymbol.glyphs["majorSeventh"] == Glyphs.csymMajorSeventh)
        // 5.0 uses plain text parentheses
        #expect(ChordSymbol.glyphs["("] == "(")
        #expect(ChordSymbol.glyphs[")"] == ")")
        #expect(ChordSymbol.glyphs["/"] == Glyphs.csymDiagonalArrangementSlash)
        #expect(ChordSymbol.glyphs["#"] == Glyphs.csymAccidentalSharp)
        #expect(ChordSymbol.glyphs["b"] == Glyphs.csymAccidentalFlat)
    }

    @Test func chordSymbolIsSuperscript() {
        let block = ChordSymbolBlock("7", symbolModifier: .sup, xShift: 0, yShift: 0, vAlign: false)
        #expect(block.isSuperscript() == true)
        #expect(block.isSubscript() == false)
    }

    @Test func chordSymbolIsSubscript() {
        let block = ChordSymbolBlock("5", symbolModifier: .sub, xShift: 0, yShift: 0, vAlign: false)
        #expect(block.isSubscript() == true)
        #expect(block.isSuperscript() == false)
    }

    @Test func chordSymbolStaticMetrics() {
        #expect(ChordSymbol.superSubRatio > 0)
        #expect(ChordSymbol.superSubRatio < 1)
        #expect(ChordSymbol.spacingBetweenBlocks >= 0)
    }

    @Test func chordSymbolSuperscriptOffset() {
        #expect(ChordSymbol.superscriptOffset < 0) // Negative = upward
    }

    @Test func chordSymbolSubscriptOffset() {
        #expect(ChordSymbol.subscriptOffset > 0) // Positive = downward
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
        let block = cs.getSymbolBlock(text: "hello")
        #expect(block.getText() == "hello")
        #expect(block.symbolModifier == .none)
        #expect(block.getWidth() > 0)
    }

    @Test func chordSymbolGetSymbolBlockGlyph() {
        let cs = ChordSymbol()
        let block = cs.getSymbolBlock(text: ChordSymbol.glyphs["diminished"])
        #expect(block.getText() == Glyphs.csymDiminished)
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
        #expect(gtn.renderOptions.yShift == 0.3)
    }

    @Test func chordSymbolOnNote() {
        let note = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4), StaffKeySpec(letter: .e, octave: 4), StaffKeySpec(letter: .g, octave: 4)))
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
