import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Ornament.Ornaments")
    func ornamentOrnamentsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Ornament", test: "Ornaments", width: 750, height: 195) { factory, context in
            let stave = Stave(x: 10, y: 30, width: 700)
            _ = stave.setContext(context)
            try stave.draw()

            let notes = try (0..<13).map { _ in
                try makeOrnamentNote(factory, key: "c/4", stemDirection: .up)
            }
            let types = [
                "mordent",
                "mordentInverted",
                "turn",
                "turnInverted",
                "tr",
                "upprall",
                "downprall",
                "prallup",
                "pralldown",
                "upmordent",
                "downmordent",
                "lineprall",
                "prallprall",
            ]
            for i in notes.indices {
                _ = notes[i].addModifier(Ornament(types[i]), index: 0)
            }

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Ornament.Ornaments_Vertically_Shifted")
    func ornamentOrnamentsVerticallyShiftedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Ornament", test: "Ornaments_Vertically_Shifted", width: 750, height: 195) { factory, context in
            let stave = Stave(x: 10, y: 30, width: 700)
            _ = stave.setContext(context)
            try stave.draw()

            let notes = [
                try makeOrnamentNote(factory, key: "a/5", stemDirection: .down),
                try makeOrnamentNote(factory, key: "a/5", stemDirection: .down),
                try makeOrnamentNote(factory, key: "a/5", stemDirection: .down),
                try makeOrnamentNote(factory, key: "a/5", stemDirection: .down),
                try makeOrnamentNote(factory, key: "a/5", stemDirection: .down),
                try makeOrnamentNote(factory, key: "a/5", stemDirection: .down),
                try makeOrnamentNote(factory, key: "a/5", stemDirection: .down),
                try makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
                try makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
                try makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
                try makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
                try makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
                try makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
            ]
            let types = [
                "mordent",
                "mordentInverted",
                "turn",
                "turnInverted",
                "tr",
                "upprall",
                "downprall",
                "prallup",
                "pralldown",
                "upmordent",
                "downmordent",
                "lineprall",
                "prallprall",
            ]
            for i in notes.indices {
                _ = notes[i].addModifier(Ornament(types[i]), index: 0)
            }
            _ = notes[1].addModifier(Ornament("mordentInverted"), index: 0)

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Ornament.Ornaments___Delayed_turns")
    func ornamentDelayedTurnsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Ornament", test: "Ornaments___Delayed_turns", width: 550, height: 195) { factory, context in
            let (stave, notes) = try makeDelayedTurnCase(factory, context: context)
            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Ornament.Ornaments___Delayed_turns__Multiple_Draws")
    func ornamentDelayedTurnsMultipleDrawsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Ornament",
            test: "Ornaments___Delayed_turns__Multiple_Draws",
            width: 550,
            height: 195
        ) { factory, context in
            let (stave, notes) = try makeDelayedTurnCase(factory, context: context)
            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Ornament.Ornaments___Delayed_turns__Multiple_Voices")
    func ornamentDelayedTurnsMultipleVoicesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Ornament",
            test: "Ornaments___Delayed_turns__Multiple_Voices",
            width: 550,
            height: 195
        ) { factory, context in
            let stave = Stave(x: 10, y: 30, width: 500)
                .addClef(.treble)
                .addKeySignature("C#")
                .addTimeSignature(.meter(4, 4))

            let notes1: [StaveNote] = try [
                makeOrnamentNote(factory, key: "f/5", duration: "2r", stemDirection: nil),
                makeOrnamentNote(factory, key: "c/5", duration: "2", stemDirection: .up),
            ]
            let notes2: [StaveNote] = try [
                makeOrnamentNote(factory, key: "a/4", duration: "4", stemDirection: .down),
                makeOrnamentNote(factory, key: "e/4", duration: "4r", stemDirection: nil),
                makeOrnamentNote(factory, key: "e/4", duration: "2r", stemDirection: nil),
            ]

            _ = notes1[1].addModifier(Ornament("turnInverted").setDelayed(true), index: 0)
            _ = notes2[0].addModifier(Ornament("turn").setDelayed(true), index: 0)

            let voice1 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
            _ = voice1.addTickables(notes1.map { $0 as Tickable })
            let voice2 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
            _ = voice2.addTickables(notes2.map { $0 as Tickable })

            let formatWidth = stave.getNoteEndX() - stave.getNoteStartX()
            let formatter = Formatter()
            _ = formatter.joinVoices([voice1])
            _ = formatter.joinVoices([voice2])
            _ = formatter.format([voice1, voice2], justifyWidth: formatWidth)

            _ = stave.setContext(context)
            try stave.draw()
            try voice1.draw(context: context, stave: stave)
            try voice2.draw(context: context, stave: stave)
        }
    }

    @Test("Ornament.Stacked")
    func ornamentStackedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Ornament", test: "Stacked", width: 550, height: 195) { factory, context in
            let stave = factory.Stave(x: 10, y: 30, width: 500)
            _ = stave.setContext(context)
            try stave.draw()

            let notes: [StaveNote] = try [
                makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
                makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
                makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
                makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
            ]

            _ = notes[0].addModifier(Ornament("mordent"), index: 0)
            _ = notes[1].addModifier(Ornament("turnInverted"), index: 0)
            _ = notes[2].addModifier(Ornament("turn"), index: 0)
            _ = notes[3].addModifier(Ornament("turnInverted"), index: 0)

            _ = notes[0].addModifier(Ornament("turn"), index: 0)
            _ = notes[1].addModifier(Ornament("prallup"), index: 0)
            _ = notes[2].addModifier(Ornament("upmordent"), index: 0)
            _ = notes[3].addModifier(Ornament("lineprall"), index: 0)

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Ornament.With_Upper_Lower_Accidentals")
    func ornamentWithUpperLowerAccidentalsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Ornament", test: "With_Upper_Lower_Accidentals", width: 650, height: 250) { factory, context in
            let stave = factory.Stave(x: 10, y: 60, width: 600)
            _ = stave.setContext(context)
            try stave.draw()

            let notes = try (0..<11).map { _ in
                try makeOrnamentNote(factory, key: "f/4", stemDirection: .up)
            }

            _ = notes[0].addModifier(Ornament("mordent").setLowerAccidental("#").setUpperAccidental("#"), index: 0)
            _ = notes[1].addModifier(Ornament("turnInverted").setLowerAccidental("b").setUpperAccidental("b"), index: 0)
            _ = notes[2].addModifier(Ornament("turn").setUpperAccidental("##").setLowerAccidental("##"), index: 0)
            _ = notes[3].addModifier(Ornament("mordentInverted").setLowerAccidental("db").setUpperAccidental("db"), index: 0)
            _ = notes[4].addModifier(Ornament("turnInverted").setUpperAccidental("++").setLowerAccidental("++"), index: 0)
            _ = notes[5].addModifier(Ornament("tr").setUpperAccidental("n").setLowerAccidental("n"), index: 0)
            _ = notes[6].addModifier(Ornament("prallup").setUpperAccidental("d").setLowerAccidental("d"), index: 0)
            _ = notes[7].addModifier(Ornament("lineprall").setUpperAccidental("db").setLowerAccidental("db"), index: 0)
            _ = notes[8].addModifier(Ornament("upmordent").setUpperAccidental("bbs").setLowerAccidental("bbs"), index: 0)
            _ = notes[9].addModifier(Ornament("prallprall").setUpperAccidental("bb").setLowerAccidental("bb"), index: 0)
            _ = notes[10].addModifier(Ornament("turnInverted").setUpperAccidental("+").setLowerAccidental("+"), index: 0)

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Ornament.Jazz_Ornaments")
    func ornamentJazzMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Ornament", test: "Jazz_Ornaments", width: 950, height: 400) { factory, context in
            let clefWidth = VexElement.measureWidth(Glyphs.gClef)
            let xStart = 10.0
            let width = 300.0
            let yStart = 50.0
            let staffHeight = 70.0
            var curX = xStart
            var curY = yStart

            var mods = [
                factory.Ornament("scoop"),
                factory.Ornament("doit"),
                factory.Ornament("fall"),
                factory.Ornament("doitLong"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["a/5"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: .down,
                clefWidth: clefWidth
            )
            curX += width

            mods = [
                factory.Ornament("fallLong"),
                factory.Ornament("bend"),
                factory.Ornament("plungerClosed"),
                factory.Ornament("plungerOpen"),
                factory.Ornament("bend"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["a/5"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: .down,
                clefWidth: clefWidth
            )
            curX += width

            mods = [
                factory.Ornament("flip"),
                factory.Ornament("jazzTurn"),
                factory.Ornament("smear"),
                factory.Ornament("doit"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["a/5"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: .up,
                clefWidth: clefWidth
            )

            curX = xStart
            curY += staffHeight
            mods = [
                factory.Ornament("scoop"),
                factory.Ornament("doit"),
                factory.Ornament("fall"),
                factory.Ornament("doitLong"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["e/5"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: nil,
                clefWidth: clefWidth
            )
            curX += width

            mods = [
                factory.Ornament("fallLong"),
                factory.Ornament("bend"),
                factory.Ornament("plungerClosed"),
                factory.Ornament("plungerOpen"),
                factory.Ornament("bend"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["e/5"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: nil,
                clefWidth: clefWidth
            )
            curX += width

            mods = [
                factory.Ornament("flip"),
                factory.Ornament("jazzTurn"),
                factory.Ornament("smear"),
                factory.Ornament("doit"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["e/5"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: nil,
                clefWidth: clefWidth
            )

            curX = xStart
            curY += staffHeight
            mods = [
                factory.Ornament("scoop"),
                factory.Ornament("doit"),
                factory.Ornament("fall"),
                factory.Ornament("doitLong"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["e/4"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: nil,
                clefWidth: clefWidth
            )
            curX += width

            mods = [
                factory.Ornament("fallLong"),
                factory.Ornament("bend"),
                factory.Ornament("plungerClosed"),
                factory.Ornament("plungerOpen"),
                factory.Ornament("bend"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["e/4"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: nil,
                clefWidth: clefWidth
            )
            curX += width

            mods = [
                factory.Ornament("flip"),
                factory.Ornament("jazzTurn"),
                factory.Ornament("smear"),
                factory.Ornament("doit"),
            ]
            try drawJazzOrnamentLine(
                factory: factory,
                context: context,
                modifiers: mods,
                keys: ["e/4"],
                x: curX,
                width: width,
                y: curY,
                stemDirection: nil,
                clefWidth: clefWidth
            )
        }
    }

    private func makeOrnamentNote(
        _ factory: Factory,
        key: String,
        duration: String = "4",
        stemDirection: StemDirection? = .up
    ) throws -> StaveNote {
        try factory.StaveNote(
            StaveNoteStruct(
                parsingKeys: [key],
                duration: duration,
                stemDirection: stemDirection
            )
        )
    }

    private func makeDelayedTurnCase(
        _ factory: Factory,
        context: SVGRenderContext
    ) throws -> (stave: Stave, notes: [StaveNote]) {
        let stave = factory.Stave(x: 10, y: 30, width: 500)
        _ = stave.setContext(context)
        try stave.draw()

        let notes: [StaveNote] = try [
            makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
            makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
            makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
            makeOrnamentNote(factory, key: "a/4", stemDirection: .up),
        ]

        _ = notes[0].addModifier(Ornament("turn").setDelayed(true), index: 0)
        _ = notes[1].addModifier(Ornament("turnInverted").setDelayed(true), index: 0)
        _ = notes[2].addModifier(Ornament("turnInverted").setDelayed(true), index: 0)
        _ = notes[3].addModifier(Ornament("turn").setDelayed(true), index: 0)

        return (stave, notes)
    }

    private func drawJazzOrnamentLine(
        factory: Factory,
        context: SVGRenderContext,
        modifiers: [Ornament],
        keys: [String],
        x: Double,
        width: Double,
        y: Double,
        stemDirection: StemDirection?,
        clefWidth: Double
    ) throws {
        func note(duration: String, modifier: Ornament) throws -> StaveNote {
            let n = try factory.StaveNote(
                StaveNoteStruct(
                    parsingKeys: keys,
                    duration: duration,
                    stemDirection: stemDirection
                )
            )
                .addModifier(modifier, index: 0)
                .addModifier(factory.Accidental(type: .flat), index: 0)

            if duration.contains("d") {
                Dot.buildAndAttach([n as Note], all: true)
            }
            return n
        }

        let stave = Stave(x: x, y: y, width: width).addClef(.treble)
        _ = stave.setContext(context)
        try stave.draw()

        let notes = try [
            note(duration: "4d", modifier: modifiers[0]),
            note(duration: "8", modifier: modifiers[1]),
            note(duration: "4d", modifier: modifiers[2]),
            note(duration: "8", modifier: modifiers[3]),
        ]
        if modifiers.count > 4 {
            _ = notes[3].addModifier(modifiers[4], index: 0)
        }

        _ = try Beam.generateBeams(notes.map { $0 as StemmableNote })
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
            .setMode(.soft)
            .addTickables(notes.map { $0 as Tickable })
        let formatter = Formatter().joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: width - Stave.defaultPadding - clefWidth)

        _ = stave.setContext(context)
        try stave.draw()
        try voice.draw(context: context, stave: stave)
    }
}

// MARK: - VexFlow 5.8.0 cases (Opt-in SVG parity cases for the ornament tests added in VexFlow 5.8.0 (tests/ornament_tests.ts).)

extension UpstreamSVGParityTests {
    @Test("Ornament.Parenthesized_editorial_turn")
    func ornamentParenthesizedEditorialTurnMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Ornament", test: "Parenthesized_editorial_turn", width: 300, height: 155
        ) { factory, context in
            let stave = factory.Stave(x: 10, y: 30, width: 280).addClef(.treble)
            let notes = try (0..<2).map { _ in
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "q", stemDirection: .down))
            }
            let bare = Ornament("turn")
            let marked = factory.Ornament("turn", parenthesized: true)
            _ = notes[0].addModifier(bare, index: 0)
            _ = notes[1].addModifier(marked, index: 0)
            let voice = factory.Voice(time: VoiceTime(numBeats: 2, beatValue: 4)).addTickables(notes)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)

            func draw() throws {
                context.clear()
                try stave.draw()
                try voice.draw(context: context, stave: stave)
            }
            // Upstream draws four times and keeps the last drawing.
            try draw()
            try draw()
            marked.setParenthesized(false)
            try draw()
            marked.setParenthesized().setParenthesized()
            try draw()
        }
    }

    @Test("Ornament.Pitched_trill_partners")
    func ornamentPitchedTrillPartnersMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Ornament", test: "Pitched_trill_partners", width: 620, height: 280
        ) { factory, context in
            for (row, width) in [290.0, 170.0].enumerated() {
                for (i, pitch) in ["bb/4", "a/4"].enumerated() {
                    let stave = factory.Stave(x: 12 + Double(i) * width, y: 20 + Double(row) * 130, width: width)
                        .addClef(.treble)
                    let principal = factory.StaveNote(
                        try StaveNoteStruct(parsingKeys: ["g/4"], duration: "h", stemDirection: .down)
                    )
                    let trill = try factory.OrnamentThrowing("tr", auxiliaryPitch: pitch)
                    _ = principal.addModifier(trill, index: 0)
                    let next = factory.StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "q"))
                    let voice = factory.Voice(time: VoiceTime(numBeats: 3, beatValue: 4)).addTickables([principal, next])
                    _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                    try stave.draw()
                    try voice.draw(context: context, stave: stave)
                }
            }
        }
    }

    @Test("Ornament.Changing_a_pitched_trill_partner")
    func ornamentChangingAPitchedTrillPartnerMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Ornament", test: "Changing_a_pitched_trill_partner", width: 300, height: 220
        ) { factory, context in
            let stave = factory.Stave(y: 65).addClef(.treble)
            let principal = factory.StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "h"))
            let trill = factory.Ornament("tr")
            _ = principal.addModifier(trill, index: 0)
            let next = factory.StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "q"))
            let voice = factory.Voice(time: VoiceTime(numBeats: 3, beatValue: 4)).addTickables([principal, next])
            for pitch in [nil, "bb/4", "a/4", "d/6"] as [String?] {
                try trill.setAuxiliaryPitch(pitch)
                _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                context.clear()
                try stave.draw()
                try voice.draw(context: context, stave: stave)
            }
        }
    }
}
