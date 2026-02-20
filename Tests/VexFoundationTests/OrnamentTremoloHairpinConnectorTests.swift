// VexFoundation - Tests for Phase 10: Ornament, Tremolo, StaveHairpin, StaveConnector

import Testing
@testable import VexFoundation

@Suite("Ornament, Tremolo, Hairpin & Connector")
struct OrnamentTremoloHairpinConnectorTests {

    init() {
        FontLoader.loadDefaultFonts()
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
        #expect(orn.reportedWidth > 0)
        #expect(orn.adjustForStemDirection == true)
        #expect(orn.delayed == false)
    }

    @Test func ornamentMordentCreation() {
        let orn = Ornament("mordent")
        #expect(orn.type == "mordent")
        #expect(orn.reportedWidth > 0)
    }

    @Test func ornamentTurnCreation() {
        let orn = Ornament("turn")
        #expect(orn.type == "turn")
        #expect(orn.reportedWidth > 0)
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

        // tr adjusts for stem direction
        let trill = Ornament("tr")
        #expect(trill.adjustForStemDirection == true)
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

    @Test func ornamentFormatSingle() {
        let note = makeNote()
        let orn = Ornament("tr")
        _ = orn.setNote(note)
        _ = orn.setIndex(0)

        var state = ModifierContextState()
        let result = Ornament.format([orn], state: &state)
        #expect(result == true)
        #expect(state.topTextLine == 1)
    }

    @Test func ornamentFormatMultiple() {
        let note = makeNote()
        let orn1 = Ornament("tr")
        _ = orn1.setNote(note)
        _ = orn1.setIndex(0)

        let orn2 = Ornament("mordent")
        _ = orn2.setNote(note)
        _ = orn2.setIndex(0)

        var state = ModifierContextState()
        Ornament.format([orn1, orn2], state: &state)
        #expect(state.topTextLine == 2)
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

        #expect(mc.formatted == true)
        #expect(!mc.getMembers("Ornament").isEmpty)
    }

    // MARK: - Tremolo

    @Test func tremoloCategory() {
        #expect(Tremolo.category == "Tremolo")
    }

    @Test func tremoloCreation() {
        let trem = Tremolo(3)
        #expect(trem.num == 3)
        #expect(trem.code == "tremolo1")
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

    @Test func tremoloYSpacingScale() {
        let trem = Tremolo(3)
        #expect(trem.ySpacingScale == 1)
        trem.ySpacingScale = 1.5
        #expect(trem.ySpacingScale == 1.5)
    }

    @Test func tremoloExtraStrokeScale() {
        let trem = Tremolo(3)
        #expect(trem.extraStrokeScale == 1)
        trem.extraStrokeScale = 2.0
        #expect(trem.extraStrokeScale == 2.0)
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
        #expect(connector.texts[0].content == "Piano")
        #expect(connector.texts[0].shiftX == 0)
        #expect(connector.texts[0].shiftY == 0)
    }

    @Test func staveConnectorSetTextWithShift() {
        let stave1 = Stave(x: 10, y: 40, width: 300)
        let stave2 = Stave(x: 10, y: 140, width: 300)
        let connector = StaveConnector(topStave: stave1, bottomStave: stave2)

        _ = connector.setText("Vln.", shiftX: 5, shiftY: -3)
        #expect(connector.texts[0].shiftX == 5)
        #expect(connector.texts[0].shiftY == -3)
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

        #expect(connector.connectorWidth == 3)
        #expect(connector.thickness == Tables.STAVE_LINE_THICKNESS)
        #expect(connector.connectorXShift == 0)
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
        let trCode = Tables.ornamentCode("tr")
        #expect(trCode != nil)

        let mordentCode = Tables.ornamentCode("mordent")
        #expect(mordentCode != nil)

        let turnCode = Tables.ornamentCode("turn")
        #expect(turnCode != nil)

        // Unknown type returns nil
        let unknownCode = Tables.ornamentCode("nonexistent")
        #expect(unknownCode == nil)
    }

    @Test func tablesOrnamentCodeVariety() {
        let types = [
            "mordent", "mordent_inverted", "turn", "turn_inverted",
            "tr", "upprall", "downprall", "prallup", "pralldown",
            "upmordent", "downmordent", "lineprall",
            "prallprall", "scoop", "doit", "fall", "doitLong",
            "fallLong", "bend", "plungerClosed", "plungerOpen",
            "flip", "jazzTurn", "smear"
        ]
        for type in types {
            let code = Tables.ornamentCode(type)
            #expect(code != nil, "Ornament code for '\(type)' should exist")
        }
    }
}
