// VexFoundation - Tests for Phase 10: Ornament, Tremolo, StaveHairpin, StaveConnector

import Testing
@testable import VexFoundation

@Suite("Ornament, Tremolo, Hairpin & Connector")
struct OrnamentTremoloHairpinConnectorTests {

    init() {
        Flow.setFonts("Bravura", "Academico")
    }

    @Test(arguments: [false, true])
    func shiftedSingleConnectorDrawsAtShiftedX(right: Bool) throws {
        let type: ConnectorType = right ? .singleRight : .singleLeft
        let context = SVGRenderContext(width: 500, height: 300)
        let top = Stave(x: 25, y: 10, width: 300)
        let bottom = Stave(x: 25, y: 120, width: 300)
        let connector = StaveConnector(topStave: top, bottomStave: bottom)
        _ = connector.setType(type).setXShift(47).setContext(context)
        try connector.draw()
        let x = type == .singleLeft ? 72 : 372
        #expect(context.getSVG().contains("x=\"\(x)\""))
        #expect(!context.getSVG().contains("x=\"25\""))
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

    // MARK: - Ornament Creation

    @Test func ornamentCategory() {
        #expect(Ornament.category == "Ornament")
    }

    @Test func ornamentTrillCreation() {
        let orn = Ornament("tr")
        #expect(orn.type == "tr")
        #expect(orn.getText() == Glyphs.ornamentTrill)
        #expect(orn.getWidth() > 0)
        // Upstream 5.0 constructor always sets adjustForStemDirection = false.
        #expect(orn.adjustForStemDirection == false)
        #expect(orn.delayed == false)
    }

    @Test func ornamentMordentCreation() {
        let orn = Ornament("mordent")
        #expect(orn.type == "mordent")
        #expect(orn.getWidth() > 0)
    }

    @Test func ornamentTurnCreation() {
        let orn = Ornament("turn")
        #expect(orn.type == "turn")
        #expect(orn.getWidth() > 0)
    }

    // MARK: - Ornament Type Lists

    @Test func ornamentDelayedTypes() {
        // flip, jazzTurn, smear are delayed (note transition types)
        let flip = Ornament("flip")
        #expect(flip.delayed == true)

        let jazzTurn = Ornament("jazzTurn")
        #expect(jazzTurn.delayed == true)

        let smear = Ornament("smear")
        #expect(smear.delayed == true)

        // trill is not delayed
        let trill = Ornament("tr")
        #expect(trill.delayed == false)
    }

    @Test func ornamentAlignWithNoteHead() {
        // doit aligns with note head, so adjustForStemDirection should be false
        let doit = Ornament("doit")
        #expect(doit.adjustForStemDirection == false)

        let fall = Ornament("fall")
        #expect(fall.adjustForStemDirection == false)

        let scoop = Ornament("scoop")
        #expect(scoop.adjustForStemDirection == false)

        // Upstream 5.0: tr does not align with the note head and does not adjust for stem direction.
        let trill = Ornament("tr")
        #expect(trill.adjustForStemDirection == false)
    }

    @Test func ornamentAttackTypes() {
        #expect(Ornament.attackTypes.contains("scoop"))
        #expect(!Ornament.attackTypes.contains("tr"))
    }

    @Test func ornamentReleaseTypes() {
        #expect(Ornament.releaseTypes.contains("doit"))
        #expect(Ornament.releaseTypes.contains("fall"))
        #expect(Ornament.releaseTypes.contains("jazzTurn"))
        #expect(!Ornament.releaseTypes.contains("tr"))
    }

    @Test func ornamentArticulationTypes() {
        #expect(Ornament.articulationTypes.contains("bend"))
        #expect(Ornament.articulationTypes.contains("plungerClosed"))
        #expect(Ornament.articulationTypes.contains("plungerOpen"))
    }

    // MARK: - Ornament Setters

    @Test func ornamentSetDelayed() {
        let orn = Ornament("tr")
        #expect(orn.delayed == false)
        _ = orn.setDelayed(true)
        #expect(orn.delayed == true)
        _ = orn.setDelayed(false)
        #expect(orn.delayed == false)
    }

    @Test func ornamentSetUpperAccidental() {
        let orn = Ornament("tr")
        _ = orn.setUpperAccidental("#")
        // Should not crash; accidental is set internally
    }

    @Test func ornamentSetLowerAccidental() {
        let orn = Ornament("tr")
        _ = orn.setLowerAccidental("b")
        // Should not crash; accidental is set internally
    }

    @Test func ornamentSetBothAccidentals() {
        let orn = Ornament("tr")
        _ = orn.setUpperAccidental("#")
        _ = orn.setLowerAccidental("b")
        // Both set without error
    }

    // MARK: - Ornament Format

    @Test func ornamentFormatEmpty() {
        var state = ModifierContextState()
        let result = Ornament.format([], state: &state)
        #expect(result == false)
    }

    /// A stem-up C4 note built the normal way (the constructor builds the stem,
    /// then setStemDirection sets its direction), as upstream code does.
    private func makeStemUpNote() -> StaveNote {
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        _ = note.setStave(Stave(x: 10, y: 40, width: 300))
        _ = note.setStemDirection(Stem.UP)
        return note
    }

    @Test func ornamentFormatSingle() {
        let note = makeStemUpNote()
        let orn = Ornament("tr")
        _ = orn.setNote(note)
        _ = orn.setIndex(0)

        var state = ModifierContextState()
        let result = Ornament.format([orn], state: &state)
        #expect(result == true)
        // Upstream 5.0 (node build): "tr" is ABOVE; curTop = line 0 + stem 35/10 = 3.5 < 5 lines,
        // so topTextLine moves to 1.5, then + 2.
        #expect(orn.textLine == 1.5)
        #expect(state.textLine == 0)
        #expect(state.topTextLine == 3.5)
    }

    @Test func ornamentFormatStemWithoutDirection() {
        // Upstream 5.0: buildStem() after setStemDirection() gives a Stem with direction 0,
        // whose getHeight() is 0, so curTop = 0 and topTextLine moves to 5 (then + 2).
        // See docs/port-notes/unit-test-findings.md (Stem default direction).
        let note = makeNote()
        let orn = Ornament("tr")
        _ = orn.setNote(note)
        _ = orn.setIndex(0)
        var state = ModifierContextState()
        Ornament.format([orn], state: &state)
        withKnownIssue("Swift Stem() defaults to direction UP; upstream defaults to 0 (see unit-test-findings.md)") {
            #expect(note.getStem()?.getHeight() == 0)
            #expect(orn.textLine == 5)
            #expect(state.topTextLine == 7)
        }
    }

    @Test func ornamentFormatMultiple() {
        let note = makeStemUpNote()
        let orn1 = Ornament("tr")
        _ = orn1.setNote(note)
        _ = orn1.setIndex(0)

        let orn2 = Ornament("mordent")
        _ = orn2.setNote(note)
        _ = orn2.setIndex(0)

        var state = ModifierContextState()
        Ornament.format([orn1, orn2], state: &state)
        // Upstream 5.0 values (node build): both ornaments stack above the staff.
        #expect(orn1.textLine == 1.5)
        #expect(orn2.textLine == 3.5)
        #expect(state.textLine == 0)
        #expect(state.topTextLine == 5.5)
    }

    @Test func ornamentFormatAttackShiftsLeft() {
        let note = makeNote()
        let scoop = Ornament("scoop")
        _ = scoop.setNote(note)
        _ = scoop.setIndex(0)

        var state = ModifierContextState()
        Ornament.format([scoop], state: &state)
        #expect(state.leftShift > 0)
    }

    @Test func ornamentFormatReleaseShiftsRight() {
        let note = makeNote()
        let doit = Ornament("doit")
        _ = doit.setNote(note)
        _ = doit.setIndex(0)

        var state = ModifierContextState()
        Ornament.format([doit], state: &state)
        #expect(state.rightShift > 0)
    }

    // MARK: - Ornament in ModifierContext

    @Test func ornamentModifierContext() {
        let note = makeNote()
        let orn = Ornament("tr")
        _ = note.addModifier(orn, index: 0)

        let mc = ModifierContext()
        _ = note.addToModifierContext(mc)
        mc.preFormat()

        #expect(mc.preFormatted) // upstream 5.0 preFormat() sets preFormatted, never formatted
        #expect(!mc.getMembers("Ornament").isEmpty)
    }

    // MARK: - Tremolo

    @Test func tremoloCategory() {
        #expect(Tremolo.category == "Tremolo")
    }

    @Test func tremoloCreation() {
        let trem = Tremolo(3)
        #expect(trem.num == 3)
        #expect(trem.getText() == Glyphs.tremolo1)
        #expect(trem.position == .center)
    }

    @Test func tremoloSingleStroke() {
        let trem = Tremolo(1)
        #expect(trem.num == 1)
    }

    @Test func tremoloDoubleStroke() {
        let trem = Tremolo(2)
        #expect(trem.num == 2)
    }

    // MARK: - Hairpin Type

    @Test func hairpinTypeEnum() {
        #expect(HairpinType.crescendo.rawValue == 1)
        #expect(HairpinType.decrescendo.rawValue == 2)
    }

    // MARK: - Hairpin Render Options

    @Test func hairpinRenderOptionsDefaults() {
        let opts = HairpinRenderOptions()
        #expect(opts.leftShiftPx == 0)
        #expect(opts.rightShiftPx == 0)
        #expect(opts.height == 10)
        #expect(opts.yShift == 0)
    }

    @Test func hairpinRenderOptionsCustom() {
        let opts = HairpinRenderOptions(
            leftShiftPx: 5,
            rightShiftPx: 10,
            height: 15,
            yShift: 3
        )
        #expect(opts.leftShiftPx == 5)
        #expect(opts.rightShiftPx == 10)
        #expect(opts.height == 15)
        #expect(opts.yShift == 3)
    }

    // MARK: - StaveHairpin

    @Test func staveHairpinCategory() {
        #expect(StaveHairpin.category == "StaveHairpin")
    }

    @Test func staveHairpinCrescendo() {
        let note1 = makeNote()
        let note2 = makeNote()
        let hairpin = StaveHairpin(firstNote: note1, lastNote: note2, type: .crescendo)
        #expect(hairpin.hairpinType == .crescendo)
        #expect(hairpin.hairpinPosition == .below) // default
    }

    @Test func staveHairpinDecrescendo() {
        let note1 = makeNote()
        let note2 = makeNote()
        let hairpin = StaveHairpin(firstNote: note1, lastNote: note2, type: .decrescendo)
        #expect(hairpin.hairpinType == .decrescendo)
    }

    @Test func staveHairpinSetPosition() {
        let note1 = makeNote()
        let note2 = makeNote()
        let hairpin = StaveHairpin(firstNote: note1, lastNote: note2, type: .crescendo)

        _ = hairpin.setPosition(.above)
        #expect(hairpin.hairpinPosition == .above)

        _ = hairpin.setPosition(.below)
        #expect(hairpin.hairpinPosition == .below)

        // Left/right are ignored
        _ = hairpin.setPosition(.left)
        #expect(hairpin.hairpinPosition == .below) // unchanged
    }

    @Test func staveHairpinSetRenderOptions() {
        let note1 = makeNote()
        let note2 = makeNote()
        let hairpin = StaveHairpin(firstNote: note1, lastNote: note2, type: .crescendo)

        let opts = HairpinRenderOptions(leftShiftPx: 5, rightShiftPx: 10, height: 20, yShift: 3)
        _ = hairpin.setRenderOptions(opts)
        #expect(hairpin.renderOptions.leftShiftPx == 5)
        #expect(hairpin.renderOptions.height == 20)
    }

    @Test func staveHairpinSetNotes() {
        let note1 = makeNote()
        let note2 = makeNote()
        let note3 = makeNote()
        let hairpin = StaveHairpin(firstNote: note1, lastNote: note2, type: .crescendo)

        _ = hairpin.setNotes(firstNote: note3, lastNote: note2)
        #expect(hairpin.firstNote === note3)
        #expect(hairpin.lastNote === note2)
    }

    @Test func staveHairpinValidatingInitAndThrowingSetNotes() throws {
        do {
            _ = try StaveHairpin(validating: nil, lastNote: nil, type: .crescendo)
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveHairpinError == .requiresStartOrEndNote)
        }

        let note = makeNote()
        let hairpin = StaveHairpin(firstNote: note, lastNote: note, type: .decrescendo)
        do {
            _ = try hairpin.setNotesThrowing(firstNote: nil, lastNote: nil)
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveHairpinError == .requiresStartOrEndNote)
        }
    }

    // MARK: - Connector Type

    @Test func connectorTypeEnum() {
        #expect(ConnectorType.singleRight.rawValue == 0)
        #expect(ConnectorType.singleLeft.rawValue == 1)
        #expect(ConnectorType.double.rawValue == 2)
        #expect(ConnectorType.brace.rawValue == 3)
        #expect(ConnectorType.bracket.rawValue == 4)
        #expect(ConnectorType.boldDoubleLeft.rawValue == 5)
        #expect(ConnectorType.boldDoubleRight.rawValue == 6)
        #expect(ConnectorType.thinDouble.rawValue == 7)
        #expect(ConnectorType.none.rawValue == 8)
    }

    // MARK: - StaveConnector

    @Test func staveConnectorCategory() {
        #expect(StaveConnector.category == "StaveConnector")
    }

    @Test func staveConnectorCreation() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)
        let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
        #expect(connector.topStave === stave1)
        #expect(connector.bottomStave === stave2)
        #expect(connector.connectorType == .double) // default
    }

    @Test func staveConnectorSetType() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)
        let connector = StaveConnector(topStave: stave1, bottomStave: stave2)

        _ = connector.setType(.brace)
        #expect(connector.getType() == .brace)

        _ = connector.setType(.bracket)
        #expect(connector.getType() == .bracket)

        _ = connector.setType(.singleLeft)
        #expect(connector.getType() == .singleLeft)
    }

    @Test func staveConnectorSetXShift() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)
        let connector = StaveConnector(topStave: stave1, bottomStave: stave2)

        _ = connector.setXShift(5)
        #expect(connector.getXShift() == 5)
    }

    @Test func staveConnectorSetText() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)
        let connector = StaveConnector(topStave: stave1, bottomStave: stave2)

        _ = connector.setText("Piano")
        #expect(connector.texts.count == 1)
        #expect(connector.texts[0].getText() == "Piano")
        #expect(connector.texts[0].getXShift() == 0)
        #expect(connector.texts[0].getYShift() == 0)
    }

    @Test func staveConnectorSetTextWithShift() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)
        let connector = StaveConnector(topStave: stave1, bottomStave: stave2)

        _ = connector.setText("Vln.", shiftX: 5, shiftY: -3)
        #expect(connector.texts[0].getXShift() == 5)
        #expect(connector.texts[0].getYShift() == -3)
    }

    @Test func staveConnectorMultipleTexts() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)
        let connector = StaveConnector(topStave: stave1, bottomStave: stave2)

        _ = connector.setText("I")
        _ = connector.setText("II")
        #expect(connector.texts.count == 2)
    }

    @Test func staveConnectorDefaults() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)
        let connector = StaveConnector(topStave: stave1, bottomStave: stave2)

        #expect(connector.thickness == Tables.STAVE_LINE_THICKNESS)
        #expect(connector.getXShift() == 0)
        #expect(connector.getType() == .double)
        #expect(connector.texts.isEmpty)
    }

    @Test func staveConnectorAllTypes() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)

        let types: [ConnectorType] = [
            .singleRight, .singleLeft, .double, .brace,
            .bracket, .boldDoubleLeft, .boldDoubleRight, .thinDouble, .none
        ]

        for type in types {
            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector.setType(type)
            #expect(connector.getType() == type)
        }
    }

    // MARK: - Ornament Codes in Tables

    @Test func tablesOrnamentCodeLookup() {
        // Known ornament types should resolve to codes
        #expect(Tables.ornamentCodes("tr") == Glyphs.ornamentTrill)
        #expect(Tables.ornamentCodes("mordent") == Glyphs.ornamentShortTrill)
        #expect(Tables.ornamentCodes("turn") == Glyphs.ornamentTurn)

        // Unknown type: no table entry, and the lookup returns the input (upstream)
        #expect(!Tables.hasOrnamentCode("nonexistent"))
        #expect(Tables.ornamentCodes("nonexistent") == "nonexistent")
    }

    @Test func tablesOrnamentCodeVariety() {
        let types = [
            "mordent", "mordentInverted", "turn", "turnInverted",
            "tr", "upprall", "downprall", "prallup", "pralldown",
            "upmordent", "downmordent", "lineprall",
            "prallprall", "scoop", "doit", "fall", "doitLong",
            "fallLong", "bend", "plungerClosed", "plungerOpen",
            "flip", "jazzTurn", "smear"
        ]
        for type in types {
            #expect(Tables.hasOrnamentCode(type), "Ornament code for '\(type)' should exist")
        }
    }
}
