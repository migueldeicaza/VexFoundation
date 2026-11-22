# VexFlow Parity Ledger

Last updated: 2026-02-23 (Phase 8.2 coverage complete; mismatch remediation in progress)
Source audit: `VEXFLOW_PARITY_AUDIT.md`

## Phase 1: Core Behavior Drift

- [x] P1.1 `VexElement` / `Registry` lifecycle parity
  - [x] Auto-register on `VexElement` init when default registry is enabled
  - [x] Track registry reference on element registration
  - [x] Emit registry updates from `setAttribute`, `addClass`, `removeClass`
  - [x] Add parity tests for default registry + id/class mutation
- [x] P1.2 Remove `try!` from reachable rendering/stave hot paths
  - [x] `Sources/VexFoundation/Rendering/Glyph.swift`
  - [x] `Sources/VexFoundation/Stave/Barline.swift`

## Phase 2: High-Value Music Behavior Tests

- [x] P2.1 Auto-beaming parity tests (`auto_beam_formatting`, `crossbeam`)
  - [x] Beam-over-rests behavior (`beamRests`, `beamMiddleOnly`)
  - [x] Stem-direction maintenance behavior (`maintainStemDirections`)
  - [x] Stemlet behavior over rests (`showStemlets`)
  - [x] Cross-staff style beaming baseline test (mixed staves + stem directions)
- [x] P2.2 Rests/rhythm/voice behavior tests (`rests`, `rhythm`, `threevoice`, `unison`)
  - [x] Dotted-rest attachment coverage across core durations
  - [x] Three-voice formatting/tick-context alignment baseline
  - [x] Unison-like two-voice tick-grid alignment baseline
  - [x] String parser coverage for slash duration token (`8s`) at model layer
  - [x] Slash-note rendering parity (`rhythm` slash noteheads): width + drawing + beaming coverage
  - [x] Rest realignment options parity (`alignRests` on/off, beamed rests, tuplet-rest opt-in)
  - [x] Two/three-voice overlapping-rest collision parity (hide duplicate rests in stacked voices)
  - [x] Unison collision parity (`Tables.UNISON`, style/dot-sensitive horizontal shifting)
- [x] P2.3 Percussion notation behavior tests (`percussion`)
  - [x] Percussion clef baseline (`unpitchedPercussionClef1`)
  - [x] Percussion notehead families (`d0..d3`, `t0..t3`, `x0..x3`) glyph-code coverage
  - [x] Compatibility parser support for `x/` shorthand in string constructors
  - [x] Two-voice percussion formatting + beaming baseline

## Phase 3: Rendering/Text Surface Parity

- [x] P3.1 Decide scope and document intentional omissions vs parity goals
  - [x] Core API remains Swift-native via `RenderContext` instead of 1:1 browser renderer modules
  - [x] `renderer/canvascontext/svgcontext/web` documented as intentional out-of-core omissions
  - [x] `TextFormatter` replacement contract documented around `measureText` + `TextMeasure` + `FontInfo`
- [x] P3.2 Implement `TextFormatter` equivalent or replacement contract
  - [x] Added `Rendering/TextFormatter.swift` replacement API (`measure`, width in px/em, y extents, font mutation)
  - [x] Integrated `TextFormatter` into `Annotation`, `ChordSymbol`, and `TextNote` measurement paths
- [x] P3.3 Add rendering/text metric parity tests
  - [x] Added `Tests/VexFoundationTests/TextFormatterParityTests.swift` with deterministic mock-context metric assertions

## Phase 4: Compatibility Layer

- [x] P4.1 Optional compatibility surface (`Flow` / `Vex` aliases, build/version metadata)
  - [x] Added `Sources/VexFoundation/Compatibility/Flow.swift`
  - [x] Added `Sources/VexFoundation/Compatibility/Vex.swift`
  - [x] Added `Sources/VexFoundation/Compatibility/Version.swift`
- [x] P4.2 Compatibility tests and migration notes
  - [x] Added smoke tests in `Tests/VexFoundationTests/CompatibilityLayerTests.swift`
  - [x] Updated migration docs/README with compatibility-layer notes

## Phase 5: Ongoing Governance

- [x] P5.1 Add script to regenerate parity matrix
  - [x] Added `tools/generate_parity_matrix.sh`
  - [x] Supports `--check` mode for CI freshness validation
- [x] P5.2 Commit and maintain `docs/parity-matrix.md`
  - [x] Added `docs/parity-matrix.md` generated from upstream `index.ts` + `*_tests.ts`
- [x] P5.3 CI gate for matrix freshness + full test pass
  - [x] Added `.github/workflows/ci.yml` with pinned upstream checkout + `tools/generate_parity_matrix.sh --check` + `swift test`
- [x] P5.4 Runtime hardening for parity test reliability
  - [x] Lazy default-font bootstrap when glyph lookup happens before explicit font initialization
  - [x] Thread-safe registry index mutation/query to avoid concurrent-test crashes

## Phase 6: Module-Level Parity Closure

- [x] P6.1 Close remaining partial module mappings
  - [x] Add first-class `typeguard` compatibility module with typed predicates
  - [x] Add first-class `timesigglyph` module (`TimeSigGlyph`) instead of "integrated-only" status
  - [x] Update parity matrix generator mapping to reflect implemented status
- [x] P6.2 Replace `nonisolated(unsafe)` mutable globals with runtime context state
  - [x] Added `VexRuntimeContext` + `VexRuntime` context switching APIs
  - [x] Migrated default registry, auto-ID generator, font registry, glyph cache/font stack, chord symbol metric cache, and `Tables.UNISON` into runtime context
  - [x] Added compatibility wrappers in `Flow` (`make/get/set/withRuntimeContext`)
  - [x] Added context-isolation tests and updated flaky unison/registry parity tests to use isolated runtime contexts
- [x] P6.3 Constructor-level context threading for high-level APIs
  - [x] `Factory` now accepts and owns an explicit `runtimeContext`
  - [x] `EasyScoreOptions` and `SystemOptions` accept `runtimeContext` and propagate from `Factory` when omitted
  - [x] `Factory` creation methods execute in factory-owned runtime context
  - [x] Added constructor-threading tests for `Factory` / `EasyScore` / `System` context propagation
- [x] P6.4 String-convenience hardening for accidental creation APIs
  - [x] Added typed `AccidentalType` enum for compile-time accidental selection
  - [x] Replaced trap-based accidental string construction with `throwing` and `nil` parsing APIs
  - [x] Updated `Factory.Accidental` to typed-first + `parsing` / `parsingOrNil` overloads
  - [x] Added coverage for accidental parsing success/failure and factory parsing helpers
- [x] P6.5 String-convenience hardening for `Music` / `KeyManager`
  - [x] Added `MusicError` and safe parse/value APIs (`parsing` + `parsingOrNil`) for note/key/interval/scale-map helpers
  - [x] Refactored `KeyManager` initialization and key/note operations to `throw`/`nil` APIs (no trap-based string parsing)
  - [x] Kept backward-compatible convenience entry points as failable wrappers
  - [x] Updated theory/keymanager tests and DocC examples to use safe parsing paths
- [x] P6.6 EasyScore semantic-parse hardening
  - [x] Removed trap-based parse failures in `EasyScore.Builder` for invalid duration/type/clef/stem/key combinations
  - [x] Added `EasyScoreBuilderError` state propagation so `parse()` returns failure for semantic parse errors
  - [x] Added explicit throwing helpers: `parseThrowing` and `notesThrowing`
  - [x] Added semantic-failure tests (invalid duration/clef/stem) and throwing-helper tests
- [x] P6.7 Parser bad-grammar hardening
  - [x] Replaced parser-internal bad-grammar trap with typed `ParserError`
  - [x] Extended `ParseResult` with `parserError` for explicit diagnostics
  - [x] Added `parseThrowing` + `ParserParseError` for exception-style parser call sites
  - [x] Added malformed-grammar regression tests to ensure safe failure without process crash
- [x] P6.8 `Music` API hardening for remaining validation traps
  - [x] Converted `Music` `get*` helpers (note/key parsing, value lookup, canonical names, relative note math, interval math, scale-map creation) to typed `throws`
  - [x] Removed remaining validation-triggered traps from `Music` by routing through typed error cases
  - [x] Updated theory tests and examples to use explicit `try`
  - [x] Added invalid-direction throw regression test
- [x] P6.9 High-level API trap removal (`Factory` / `EasyScore` / `System`)
  - [x] Replaced `Factory.draw()` missing-context trap with typed `FactoryError.missingRenderContext`
  - [x] Added typed throwing direct initializers for `EasyScore` and `System` (`EasyScoreInitError`, `SystemError`) instead of constructor traps
  - [x] Replaced `System.draw()` pre-format trap with typed `SystemError.drawRequiresFormat`
  - [x] Added regression tests for direct-init failure and draw precondition errors

## Phase 7: Formatting-Layer Type Hardening

- [x] P7.1 Validation errors for `Voice` / `Formatter` / `Beam` / `Tuplet`
  - [x] Added typed error models (`VoiceTimeError`, `VoiceError`, `FormatterError`, `BeamError`, `TupletError`)
  - [x] Removed trap-based validation failures from formatting-layer modules above
  - [x] Added explicit throwing APIs for strict call sites (`...Throwing` methods and validating initializers)
  - [x] Kept non-throwing convenience entry points non-crashing (fallback/optional wrappers) for compatibility
  - [x] Added regression coverage for new throwing validation paths
- [x] P7.2 Precondition hardening for `Tickable` / `Note` / `Glyph`
  - [x] Added typed precondition errors (`TickableError`, `NoteError`, `GlyphError`)
  - [x] Added strict throwing APIs for precondition checks and parsing (`...Throwing` methods, `Note.parseNoteStructThrowing`)
  - [x] Made non-throwing convenience APIs non-crashing with safe fallbacks in `Tickable`, `Note`, and `Glyph`
  - [x] Removed remaining `fatalError` call sites from those three modules
  - [x] Added regression coverage in `NoteTests` and `GlyphTests` for strict validation paths
- [x] P7.3 Precondition hardening for `StemmableNote` / `StaveNote` / `TabNote`
  - [x] Added typed precondition/init errors (`StemmableNoteError`, `StaveNoteError`, `TabNoteError`)
  - [x] Added strict throwing APIs (`checkStemThrowing`, `getStemDirectionThrowing`, `getModifierStartXYThrowing`, `getBoundingBoxThrowing`, `getStemYThrowing`, validating initializers)
  - [x] Made convenience APIs non-crashing with safe fallback behavior for non-throwing call sites
  - [x] Removed remaining `fatalError` call sites from those three modules
  - [x] Added regression coverage in `NoteTests` and `TablatureAndChordSymbolTests` for strict validation paths
- [x] P7.4 Connector / stave / modifier trap-hardening sweep
  - [x] Replaced remaining trap paths in connector modules (`Curve`, `StaveLine`, `StaveTie`, `VibratoBracket`, `TabSlide`) with typed errors + strict throwing APIs
  - [x] Replaced remaining trap paths in modifier/stave modules (`Modifier`, `ModifierContext`, `Accidental`, `Bend`, `FretHandFinger`, `StringNumber`, `GraceNote`, `Stave`, `StaveModifier`, `StaveHairpin`, `MultiMeasureRest`)
  - [x] Kept non-throwing convenience methods non-crashing (safe fallback wrappers) for compatibility
  - [x] Added validating initializers and `...Throwing` APIs for strict call sites
  - [x] Added regression coverage across category suites (`StaveTieCurveTupletTests`, `GraceNoteDynamicsBracketsLinesTests`, `OrnamentTremoloHairpinConnectorTests`, `NoteSubGroupBarNoteVibratoParenthesisMMRTests`, `StaveTests`, `NoteTests`, `TimeSigTuningMusicKeyManagerBendFingerStringStrokeTests`, `TablatureAndChordSymbolTests`)
- [x] P7.5 Remaining core/runtime/tablature trap sweep
  - [x] Replaced remaining trap paths in core/runtime files (`Element`, `Registry`, `Tables`, `TimeSignatureSpec`) with typed errors + strict throwing APIs
  - [x] Replaced remaining trap paths in boundary modules (`FontLoader`, `TextDynamics`, `Tuning`) with typed errors + strict throwing APIs
  - [x] Preserved convenience paths with non-crashing wrappers and added `parsingOrNil`/`...OrNil` helpers where relevant
  - [x] Added regression coverage for throwing/failable APIs in `GlyphTests`, `GraceNoteDynamicsBracketsLinesTests`, `NoteTests`, `RegistryParserFactoryEasyScoreSystemTests`, and `TimeSigTuningMusicKeyManagerBendFingerStringStrokeTests`

## Phase 8: Output Parity Closure

- [x] P8.1 SVG output generator for render validation
  - [x] Added SVG-producing render backend (`SVGRenderContext`) with deterministic serialization controls (`SVGRenderOptions`)
  - [x] Added stable output options for diffability (fixed precision + deterministic ordering/group serialization)
  - [x] Added fixture-based SVG parity tests in `SVGRenderContextTests` with golden snapshot `Tests/VexFoundationTests/Fixtures/svg/simple_score.svg`
  - [x] Added CLI/script workflow `tools/svg_snapshot.sh` (`--regen` / `--check`) for local parity validation
- [ ] P8.2 Remaining non-omitted topic behavior deltas
  - [x] Audit uncovered/weak correspondence topics in `docs/parity-matrix.md`
  - [x] Add or expand category tests to close the highest-value behavior gaps after SVG validation is available
  - [x] Added dedicated `VoiceFormatterTickContextParityTests` with upstream-style strict/ignore/tracking parity assertions (`voice`, `formatter`, `tickcontext`)
  - [x] Added dedicated `ParserFactoryEasyScoreRegistrySystemParityTests` with upstream-style category coverage (`parser` microscore grammar, `factory` draw-tab repeat-begin alignment, `easyscore` category pass samples, `registry` default-registry behavior)
  - [x] Fixed EasyScore single-note chord semantic parity for `(c5)`-style inputs by correcting chord-match shape handling in `Builder.addChord`
  - [x] Added dedicated `MusicKeyManagerTuningParityTests` with upstream-style category coverage (`music`, `keymanager`, `tuning`)
  - [x] Added dedicated `BendStringNumberStrokeParityTests` with upstream-style scenario coverage (`bend`, `stringnumber`, `strokes`)
  - [x] Added dedicated `FretHandFingerParityTests` with upstream-style notation and multi-voice mixed-modifier coverage (`frethandfinger`)
  - [x] Resolved `ModifierContext`/`StringNumber` exclusivity conflict in mixed-modifier multi-voice formatting and restored string-number assertions in `FretHandFingerParityTests`
  - [x] Added dedicated `FractionParityTests` with upstream-style arithmetic/comparison/lcmm-gcd coverage (`fraction`)
  - [x] Deepened `clef` / `keysignature` parity in `KeyClefParityTests` with upstream-style parser, variant-render, end-clef key, and inline clef-change scenarios
  - [x] Added dedicated `TimeSignatureParityTests` with upstream-style parser, additive/alternating/interchangeable/aggregate/complex, multi-stave alignment, and inline change coverage (`timesignature`)
  - [x] Added dedicated `StaveModifierParityTests` with upstream-style `stave` / `stavemodifier` scenarios (sort/open-barline, begin/end mutation, repeat/multi-measure, end-modifier grid, repetition/volta/tempo/text)
  - [x] Added typed-first `Stave` convenience APIs (`setSection`/`setTempo`/`setText`/`setVoltaType`/`setRepetitionType`) with throwing + nil string wrappers; covered in `StaveModifierParityTests.stringConvenienceApisThrowOrNil`
  - [x] Added `Beam` upstream SVG parity slices in `UpstreamSVGParityTests-Beam.swift` (`Simple_Beam`, `Sixteenth_Beam`, `Slopey_Beam`, `Multi_Beam`, `Auto_stemmed_Beam`, `Mixed_Beam_1`, `Mixed_Beam_2`)
  - [x] Added `CrossBeam` upstream SVG parity slices in `UpstreamSVGParityTests-CrossBeam.swift` (`Single_clef_mixed_1`, `Single_clef_mixed_2`, `Mixed_clef_voice_middle`, `Vertical_alignment___cross_stave__beam_up1_` … `up4_`, `down1_` … `down4_`, `middle1_` … `middle4_`)
  - [x] Added `EasyScore` upstream SVG parity slices in `UpstreamSVGParityTests-EasyScore.swift` (`Draw_Basic`, `Draw_Different_KeySignature`, `Draw_Basic_Muted`, `Draw_Basic_Harmonic`, `Draw_Basic_Slash`, `Draw_Accidentals`, `Draw_Beams`, `Draw_Dots`, `Draw_Ghostnote_Basic`, `Draw_Ghostnote_Dotted`, `Draw_Parenthesised`, `Draw_Options`, `Draw_Fingerings`, `Draw_Tuplets`, `Keys`)
  - [x] Added `Grace_Notes` upstream SVG parity slices in `UpstreamSVGParityTests-GraceNotes.swift` (`Grace_Note_Basic`, `With_Articulation_and_Annotation_on_Parent_Note`, `Grace_Note_Basic_with_Slurs`, `Grace_Note_Stem`, `Grace_Note_Stem_with_Beams_1` … `3`, `Grace_Note_Slash`, `Grace_Note_Slash_with_Beams`, `Grace_Notes_Multiple_Voices`, `Grace_Notes_Multiple_Voices_Multiple_Draws`)
  - [x] Added `Tuplet` upstream SVG parity slices in `UpstreamSVGParityTests-Tuplet.swift` (`Simple_Tuplet`, `Beamed_Tuplet`, `Ratioed_Tuplet`, `Bottom_Tuplet`, `Bottom_Ratioed_Tuplet`, `Awkward_Tuplet`, `Complex_Tuplet`, `Mixed_Stem_Direction_Tuplet`, `Mixed_Stem_Direction_Bottom_Tuplet`, `Nested_Tuplets`, `Single_Tuplets`)
  - [x] Added `Unison` upstream SVG parity slices in `UpstreamSVGParityTests-Unison.swift` (`Simple_true_`, `Simple_false_`, `Accidentals_true_`, `Accidentals_false_`, `Dots_true_`, `Dots_false_`, `Breve_true_`, `Breve_false_`, `Style_true_`, `Style_false_`)
  - [x] Added `Percussion` upstream SVG parity slices in `UpstreamSVGParityTests-Percussion.swift` (`Percussion_Clef`, `Percussion_Notes`, `Percussion_Basic0`, `Percussion_Basic1`, `Percussion_Basic2`, `Percussion_Snare0`, `Percussion_Snare1`, `Percussion_Snare2`, `Percussion_Snare3`)
  - [x] Added `Rests` upstream SVG parity slices in `UpstreamSVGParityTests-Rests.swift` (`Outside_Stave`, `Dotted`, `Auto_Align___Beamed_Notes_Stems_Up`, `Auto_Align___Beamed_Notes_Stems_Down`, `Auto_Align___Tuplets_Stems_Up`, `Auto_Align___Tuplets_Stems_Down`, `Auto_Align___Single_Voice__Default_`, `Auto_Align___Single_Voice__Align_All_`, `Auto_Align___Multi_Voice`)
  - [x] Added `StaveTie` upstream SVG parity slices in `UpstreamSVGParityTests-StaveTie.swift` (`Simple_StaveTie`, `Chord_StaveTie`, `Stem_Up_StaveTie`, `No_End_Note_With_Clef`, `No_End_Note`, `No_Start_Note_With_Clef`, `No_Start_Note`, `Set_Direction_Down`, `Set_Direction_Up`)
  - [x] Added `ChordSymbol` upstream SVG parity slices in `UpstreamSVGParityTests-ChordSymbol.swift` (`Chord_Symbol_With_Modifiers`, `Chord_Symbol_Font_Size_Tests`, `Chord_Symbol_Kerning_Tests`, `Top_Chord_Symbols`, `Top_Chord_Symbols_Justified`, `Bottom_Chord_Symbols`, `Bottom_Stem_Down_Chord_Symbols`, `Double_Bottom_Chord_Symbols`)
  - [x] Added `Ornament` upstream SVG parity slices in `UpstreamSVGParityTests-Ornament.swift` (`Ornaments`, `Ornaments_Vertically_Shifted`, `Ornaments___Delayed_turns`, `Ornaments___Delayed_turns__Multiple_Draws`, `Ornaments___Delayed_turns__Multiple_Voices`, `Stacked`, `With_Upper_Lower_Accidentals`, `Jazz_Ornaments`)
  - [x] Added `PedalMarking` upstream SVG parity slices in `UpstreamSVGParityTests-PedalMarking.swift` (`Simple_Pedal_1`, `Simple_Pedal_2`, `Simple_Pedal_3`, `Release_and_Depress_on_Same_Note_1`, `Release_and_Depress_on_Same_Note_2`, `Custom_Text_1`, `Custom_Text_2`)
  - [x] Added `TextNote` upstream SVG parity slices in `UpstreamSVGParityTests-TextNote.swift` (`TextNote_Formatting`, `TextNote_Formatting_2`, `TextNote_Superscript_and_Subscript`, `TextNote_Formatting_With_Glyphs_0`, `TextNote_Formatting_With_Glyphs_1`, `Crescendo`, `Text_Dynamics`)
  - [x] Added `NoteHead` upstream SVG parity slices in `UpstreamSVGParityTests-NoteHead.swift` (`Basic`, `Various_Note_Heads_1`, `Various_Note_Heads_2`, `Various_Heads`, `Drum_Chord_Heads`, `Bounding_Boxes`)
  - [x] Added `TabNote` upstream SVG parity slices in `UpstreamSVGParityTests-TabNote.swift` (`TabNote_Draw`, `TabNote_Stems_Up`, `TabNote_Stems_Down`, `TabNote_Stems_Up_Through_Stave`, `TabNote_Stems_Down_Through_Stave`, `TabNote_Stems_with_Dots`)
  - [x] Added `TabTie` upstream SVG parity slices in `UpstreamSVGParityTests-TabTie.swift` (`Simple_TabTie`, `Hammerons`, `Pulloffs`, `Tapping`, `Continuous`)
  - [x] Added `Three_Voice_Rests` upstream SVG parity slices in `UpstreamSVGParityTests-ThreeVoiceRests.swift` (`Three_Voices____1`, `Three_Voices____2_Complex`, `Three_Voices____3`, `Auto_Adjust_Rest_Positions___Two_Voices`, `Auto_Adjust_Rest_Positions___Three_Voices__1`, `Auto_Adjust_Rest_Positions___Three_Voices__2`)
  - [x] Added `Rhythm` upstream SVG parity slices in `UpstreamSVGParityTests-Rhythm.swift` (`Rhythm_Draw___slash_notes`, `Rhythm_Draw___beamed_slash_notes`, `Rhythm_Draw___beamed_slash_notes__some_rests`, `Rhythm_Draw___16th_note_rhythm_with_scratches`, `Rhythm_Draw___32nd_note_rhythm_with_scratches`)
  - [x] Added `GlyphNote` upstream SVG parity slices in `UpstreamSVGParityTests-GlyphNote.swift` (`GlyphNote_with_ChordSymbols`, `GlyphNote_Positioning`, `GlyphNote_No_Stave_Padding`, `GlyphNote_RepeatNote`)
  - [x] Added `StaveHairpin` upstream SVG parity slices in `UpstreamSVGParityTests-StaveHairpin.swift` (`Simple_StaveHairpin`, `Horizontal_Offset_StaveHairpin`, `Vertical_Offset_StaveHairpin`, `Height_StaveHairpin`)
  - [x] Added `NoteSubGroup` upstream SVG parity slices in `UpstreamSVGParityTests-NoteSubGroup.swift` (`Basic___ClefNote__TimeSigNote_and_BarNote`, `Multi_Voice`, `Multi_Voice_Multiple_Draws`, `Multi_Staff`)
  - [x] Added `Renderer` upstream SVG parity slices in `UpstreamSVGParityTests-Renderer.swift` (`Random`, `Renderer_API_with_element_ID_string`, `Renderer_API_with_canvas_or_div`, `Renderer_API_with_context`, `Factory_API_with_element_ID_string`, `Factory_API_with_canvas_or_div`)
  - [x] Added `Grace_Tab_Notes` upstream SVG parity slices in `UpstreamSVGParityTests-GraceTabNotes.swift` (`Grace_Tab_Note_Simple`, `Grace_Tab_Note_Slurred`)
  - [x] Added `Bach_Demo` upstream SVG parity slice in `UpstreamSVGParityTests-BachDemo.swift` (`Minuet_1`)
  - [x] Added per-category upstream parity files (`UpstreamSVGParityTests-<Category>.swift`) and ported all remaining upstream reference cases
  - [x] Added/maintained coverage reporting via `tools/generate_upstream_svg_coverage.sh` with `docs/upstream-svg-coverage.md` at 428/428 cases covered (100.00%, 0 missing, 0 extra)
  - [ ] Resolve strict upstream SVG rendering mismatches in remaining categories
    - [ ] `Accidental.Sagittal`: currently requires elevated signature epsilon (`54.1`) due accidental-spacing X drift in mixed Sagittal+standard accidental clusters.
    - [x] `Bach_Demo.Minuet_1`: strict parity now passes after `StaveTempo` width accumulation fix (removed elevated epsilon).

## Test Topic Correspondence

Canonical per-topic table lives in `docs/parity-matrix.md` under **Test Topic Parity**.
The grouped correspondence table below is the quick ledger index:

| Local Suite | Test File | Upstream Topics |
|---|---|---|
| Accidental, Beam & Articulation | `AccidentalBeamArticulationTests.swift` | `accidental`, `articulation`, `beam`, `auto_beam_formatting`, `crossbeam` |
| StaveTie, Curve & Tuplet | `StaveTieCurveTupletTests.swift` | `stavetie`, `curve`, `tuplet` |
| Note Types & Annotation | `NoteTypesAnnotationTests.swift` | `annotation`, `ghostnote` |
| Ornament, Tremolo, Hairpin & Connector | `OrnamentTremoloHairpinConnectorTests.swift` | `ornament`, `tremolo`, `stavehairpin`, `staveconnector` |
| GraceNote, Dynamics, Brackets & Lines | `GraceNoteDynamicsBracketsLinesTests.swift` | `gracenote`, `pedalmarking`, `staveline`, `textbracket` |
| NoteSubGroup, BarNote, Vibrato, Parenthesis, Crescendo, MultiMeasureRest | `NoteSubGroupBarNoteVibratoParenthesisMMRTests.swift` | `modifier`, `notesubgroup`, `multimeasurerest`, `vibrato`, `vibratobracket`, `parenthesis` |
| FretHandFinger Parity | `FretHandFingerParityTests.swift` | `frethandfinger` |
| Music, KeyManager, Tuning Parity | `MusicKeyManagerTuningParityTests.swift` | `music`, `keymanager`, `tuning` |
| Bend, StringNumber, Stroke Parity | `BendStringNumberStrokeParityTests.swift` | `bend`, `stringnumber`, `strokes` |
| TabStave, TabNote, TabTie, TabSlide, GraceTabNote, ChordSymbol | `TablatureAndChordSymbolTests.swift` | `tabstave`, `tabnote`, `tabtie`, `tabslide`, `gracetabnote`, `chordsymbol` |
| Registry, Parser, Factory, EasyScore, System | `RegistryParserFactoryEasyScoreSystemTests.swift` | legacy broad coverage / integration checks |
| Parser, Factory, EasyScore, Registry, System Parity | `ParserFactoryEasyScoreRegistrySystemParityTests.swift` | `parser`, `factory`, `easyscore`, `registry`, `system` |
| Voice, Formatter, TickContext Parity | `VoiceFormatterTickContextParityTests.swift` | `voice`, `formatter`, `tickcontext` |
| Time Signature Parity | `TimeSignatureParityTests.swift` | `timesignature` |
| Stave & StaveModifier Parity | `StaveModifierParityTests.swift` | `stave`, `stavemodifier` |
| Fraction Parity | `FractionParityTests.swift` | `fraction` |
| Rests, Rhythm, Three-Voice & Unison | `RestsRhythmThreeVoiceUnisonTests.swift` | `rests`, `rhythm`, `threevoice`, `unison` |
| Percussion | `PercussionParityTests.swift` | `percussion` |
| Text Formatter | `TextFormatterParityTests.swift` | `textformatter`, `textnote` |
| TypeGuard & vf_prefix | `TypeGuardVfPrefixParityTests.swift` | `typeguard`, `vf_prefix` |
| Key Signature & Clef Parity | `KeyClefParityTests.swift` | `clef`, `keysignature`, `key_clef` |
| Style | `StyleParityTests.swift` | `style` |
| Bach Demo | `BachDemoParityTests.swift` | `bach` |

## Current Focus

- Active: `P8.2 strict SVG mismatch remediation (coverage complete: 428/428 reference cases)`

## Known SVG Mismatch Backlog

- [x] `Formatter.StaveNote___Justification` resolved on `2026-02-23`
  - Fixes:
    - Restored upstream stem-direction reset behavior in `StemmableNote.setStemDirection` so stem flips rebuild noteheads/displacements (`Sources/VexFoundation/Notes/StemmableNote.swift`).
    - Corrected formatter parity harness clef-width calculation to upstream formula (removed 2x scaling in `upstreamFormatterGlyphWidth`) so `justifyWidth` matches VexFlow (`Tests/VexFoundationTests/UpstreamSVGParityTests-Formatter.swift`).
  - Validation:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter formatter.*MatchesUpstream`

- [x] `Beam.Auto_stemmed_Beam` / `Beam.Mixed_Beam_1` were resolved on `2026-02-23`
  - Fixes:
    - `Beam` now updates stored beam stem direction when `autoStem` is enabled and mirrors upstream stave/tab auto-stem selection logic.
    - `Beam.Mixed_Beam_1` parity test now creates upper-voice beams before lower-voice beams to match upstream render order.

- [x] `CrossBeam.*` (all 15 Bravura cases) resolved on `2026-02-23`
  - Fixes:
    - Added formatter softmax passthrough on `System` (`SystemFormatterOptions.softmaxFactor`) and wired `System` to use `options.details.softmaxFactor` when constructing `FormatterOptions`.
    - Updated `CrossBeam` parity harness to mirror upstream `details: { softmaxFactor: 100 }`.
  - Validation:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter crossBeam.*MatchesUpstream`

- [x] `Vibrato.Vibrato_with_Bend` tolerance debt reduced on `2026-02-24`
  - Fixes:
    - Updated `TabNote.setStave` to propagate measured fret width into formatter spacing when bend/vibrato modifiers are present (`Sources/VexFoundation/Tablature/TabNote.swift`).
    - Reduced case tolerance from `2.648` to `0.018` and removed `Gonville: 22.849` font-specific override (`Tests/VexFoundationTests/UpstreamSVGParityTests.swift`).
  - Validation:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_SIGNATURE_EPSILON=0.018 VEXFOUNDATION_UPSTREAM_SVG_DISABLE_PER_CASE_EPSILON=1 swift test --filter UpstreamSVGParityTests/vibratoWithBendMatchesUpstream`

- [x] `Grace_Notes.*` (all 11 Bravura cases) resolved on `2026-02-23`
  - Fixes:
    - Added upstream SVG parity suite in `Tests/VexFoundationTests/UpstreamSVGParityTests-GraceNotes.swift`.
    - Restored upstream grace-dot sizing in `Dot.setNote` (scale to half radius and narrower width for `GraceNote`).
    - Corrected ledger-line width parity in `StaveNote.drawLedgerLines` to use unscaled glyph width (upstream `glyphProps.getWidth()` behavior).
    - Corrected grace-note ledger offset wiring in `GraceNoteStruct.toStaveNoteStruct` to use `GraceNote.GRACE_LEDGER_LINE_OFFSET` (2) instead of inherited stave default (3).
  - Validation:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter graceNotes.*MatchesUpstream`

- [ ] `Rests.*` partial mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-Rests.swift` (all 9 upstream `Rests` SVG cases now ported)
  - Current status:
    - Passing: `Rests.Dotted`, `Rests.Auto_Align___Beamed_Notes_Stems_Up`, `Rests.Auto_Align___Beamed_Notes_Stems_Down`
    - Mismatching: `Rests.Outside_Stave`, `Rests.Auto_Align___Tuplets_Stems_Up`, `Rests.Auto_Align___Tuplets_Stems_Down`, `Rests.Auto_Align___Single_Voice__Default_`, `Rests.Auto_Align___Single_Voice__Align_All_`, `Rests.Auto_Align___Multi_Voice`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter rests.*MatchesUpstream`

- [ ] `ChordSymbol.*` mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-ChordSymbol.swift` (all 8 upstream `ChordSymbol` SVG cases now ported)
  - Current status:
    - Mismatching: `ChordSymbol.Chord_Symbol_With_Modifiers`, `ChordSymbol.Chord_Symbol_Font_Size_Tests`, `ChordSymbol.Chord_Symbol_Kerning_Tests`, `ChordSymbol.Top_Chord_Symbols`, `ChordSymbol.Top_Chord_Symbols_Justified`, `ChordSymbol.Bottom_Chord_Symbols`, `ChordSymbol.Bottom_Stem_Down_Chord_Symbols`, `ChordSymbol.Double_Bottom_Chord_Symbols`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter chordSymbol.*MatchesUpstream`

- [ ] `Ornament.*` partial mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-Ornament.swift` (all 8 upstream `Ornament` SVG cases now ported)
  - Current status:
    - Passing: `Ornament.Ornaments`, `Ornament.Ornaments_Vertically_Shifted`, `Ornament.Ornaments___Delayed_turns__Multiple_Voices`
    - Mismatching: `Ornament.Ornaments___Delayed_turns`, `Ornament.Ornaments___Delayed_turns__Multiple_Draws`, `Ornament.Stacked`, `Ornament.With_Upper_Lower_Accidentals`, `Ornament.Jazz_Ornaments`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter ornament.*MatchesUpstream`

- [ ] `PedalMarking.*` partial mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-PedalMarking.swift` (all 7 upstream `PedalMarking` SVG cases now ported)
  - Current status:
    - Passing: `PedalMarking.Simple_Pedal_1`, `PedalMarking.Simple_Pedal_2`, `PedalMarking.Simple_Pedal_3`, `PedalMarking.Release_and_Depress_on_Same_Note_1`, `PedalMarking.Release_and_Depress_on_Same_Note_2`, `PedalMarking.Custom_Text_1`
    - Mismatching: `PedalMarking.Custom_Text_2`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter pedalMarking.*MatchesUpstream`

- [ ] `TextNote.*` partial mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-TextNote.swift` (all 7 upstream `TextNote` SVG cases now ported)
  - Current status:
    - Passing: `TextNote.Text_Dynamics`
    - Mismatching: `TextNote.TextNote_Formatting`, `TextNote.TextNote_Formatting_2`, `TextNote.TextNote_Superscript_and_Subscript`, `TextNote.TextNote_Formatting_With_Glyphs_0`, `TextNote.TextNote_Formatting_With_Glyphs_1`, `TextNote.Crescendo`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter textNote.*MatchesUpstream`

- [ ] `TabNote.*` mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-TabNote.swift` (all 6 upstream `TabNote` SVG cases now ported)
  - Current status:
    - Mismatching: `TabNote.TabNote_Draw`, `TabNote.TabNote_Stems_Up`, `TabNote.TabNote_Stems_Down`, `TabNote.TabNote_Stems_Up_Through_Stave`, `TabNote.TabNote_Stems_Down_Through_Stave`, `TabNote.TabNote_Stems_with_Dots`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter tabNote.*MatchesUpstream`

- [ ] `Three_Voice_Rests.*` partial mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-ThreeVoiceRests.swift` (all 6 upstream `Three_Voice_Rests` SVG cases now ported)
  - Current status:
    - Passing: `Three_Voice_Rests.Three_Voices____1`, `Three_Voice_Rests.Three_Voices____2_Complex`, `Three_Voice_Rests.Three_Voices____3`, `Three_Voice_Rests.Auto_Adjust_Rest_Positions___Three_Voices__1`, `Three_Voice_Rests.Auto_Adjust_Rest_Positions___Three_Voices__2`
    - Mismatching: `Three_Voice_Rests.Auto_Adjust_Rest_Positions___Two_Voices`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter threeVoiceRests.*MatchesUpstream`

- [ ] `GlyphNote.*` mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-GlyphNote.swift` (all 4 upstream `GlyphNote` SVG cases now ported)
  - Current status:
    - Mismatching: `GlyphNote.GlyphNote_with_ChordSymbols`, `GlyphNote.GlyphNote_Positioning`, `GlyphNote.GlyphNote_No_Stave_Padding`, `GlyphNote.GlyphNote_RepeatNote`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter glyphNote.*MatchesUpstream`

- [ ] `StaveHairpin.*` partial mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-StaveHairpin.swift` (all 4 upstream `StaveHairpin` SVG cases now ported)
  - Current status:
    - Passing: `StaveHairpin.Simple_StaveHairpin`, `StaveHairpin.Vertical_Offset_StaveHairpin`, `StaveHairpin.Height_StaveHairpin`
    - Mismatching: `StaveHairpin.Horizontal_Offset_StaveHairpin`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter staveHairpin.*MatchesUpstream`

- [ ] `NoteSubGroup.*` mismatches observed on `2026-02-23`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-NoteSubGroup.swift` (all 4 upstream `NoteSubGroup` SVG cases now ported)
  - Current status:
    - Mismatching: `NoteSubGroup.Basic___ClefNote__TimeSigNote_and_BarNote`, `NoteSubGroup.Multi_Voice`, `NoteSubGroup.Multi_Voice_Multiple_Draws`, `NoteSubGroup.Multi_Staff`
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter noteSubGroup.*MatchesUpstream`

- [x] `Grace_Tab_Notes.*` reduced to tight tolerance on `2026-02-24`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-GraceTabNotes.swift` (all 2 upstream `Grace_Tab_Notes` SVG cases now ported)
  - Current status:
    - Passing with tight signature epsilon:
      - `Grace_Tab_Notes.Grace_Tab_Note_Simple` (`0.011`)
      - `Grace_Tab_Notes.Grace_Tab_Note_Slurred` (`0.008`)
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter graceTabNotes.*MatchesUpstream`

- [x] `Bach_Demo.*` resolved on `2026-02-24`
  - Added coverage:
    - `Tests/VexFoundationTests/UpstreamSVGParityTests-BachDemo.swift` (upstream `Bach_Demo.Minuet_1` SVG case ported)
  - Current status:
    - Passing: `Bach_Demo.Minuet_1` (strict `epsilon=0` with per-case overrides disabled)
  - Validation command:
    - `VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_SVG_FONTS=Bravura swift test --filter bachDemo.*MatchesUpstream`
