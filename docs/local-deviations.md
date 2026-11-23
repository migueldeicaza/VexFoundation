# Local deviations from upstream VexFlow

This list holds each local change that must survive an upstream upgrade.
Upstream base before the 5.x upgrade: `a0c4d47a` (4.2.6+, 4.x branch).
Check each item after each milestone. Remove an item only when upstream has the same behavior.

When `VexRuntimeContext.upstreamParityMode` is `true`, the items marked **(gated)** are disabled so that output matches upstream.

## OSMD-derived patches (`VexFlowPatch` comments, commit b7f260a)

- [ ] PedalMarking: extended pedal styles, multi-stave pedals, end-stave width adjustment (`Connectors/PedalMarking.swift`).
- [ ] TextBracket: the bracket does not go backwards and does not overlap the text (`Connectors/TextBracket.swift`) **(gated)**.
- [ ] Articulation: breath-mark position at a percentage of the distance to the next note; respect the modifier `yShift` (`Modifiers/Articulation.swift`).
- [ ] Tables and NoteHead: notehead y-shift that does not depend on stem length (`stemUpYShift`, `stemDownYShift`).
- [ ] Tables and Note: `useAlternativeXGlyph`, a classical X notehead for tab notes.
- [ ] Tables: TI (inverted triangle) notehead shift properties **(gated)**.
- [ ] Stave: guard against a NaN modifier width.
- [ ] Stave: do not overwrite `modifier.x` or `startX` when they are already larger (alignment) **(gated)**. `Stave.setBoundaryModifiers` (VexFlow 5.4.0) resets `startX` and the begin modifier positions to the stave edge, and `setX` also moves the boundary modifiers, so a continuous layout reflows to the same positions.
- [x] Barline: double heavy barline type. VexFlow 5.8.0 has the same type (`BarlineType.DOUBLE_HEAVY`), so the local patch is replaced by the upstream implementation. The Swift name `.doubleHeavy` and the type string `"doubleHeavy"` stay the same. Changes: the raw value is 10 (was 8; 8 is now `.dashed`, 9 is `.dotted`); the two 3 px strokes are at `x - 7` and `x - 2` (were `x - 5` and `x`), so the mark is 2 px further left and its right edge is at `x + 1`, as for the end bar; the modifier width is 8 (was 5); the layout metrics are `xMin: -7, xMax: 1` (were `-5, 1`); a `BarNote` of this type is 17 px wide (was 0). `drawVerticalBar(_:_:_:)` is again the upstream single/double bar.
- [ ] TabNote: configurable background color instead of `clearRect`.
- [ ] StaveTempo: SVG groups around the tempo marking and the BPM text **(gated)**.
- [x] StaveNote: `paddingRight`; keep notehead types (for example slash) across a notehead rebuild; ledger-line style; ledger SVG group **(gated)**.
- [ ] Formatter: no tick-mismatch error between voices; guard against zero `totalTicks`; guard against GhostNote in key-props lookups.
- [ ] Tuplet: option to hide the tuplet number.
- [ ] Beam: reset stem extensions to base values before recalculation.

## Other local commits

- [ ] `1af03ba`: `Factory.formatSystems()`; `applyStyle()`/`restoreStyle()` in the `draw()` of `Beam`, `Tuplet` and `Curve`.
- [ ] `252b9a7`: TabStave tracks if `spacingBetweenLinesPx` was given (default 13, explicit value kept). Beam cap `endX + 1` (check upstream 5.x).
- [x] `e3325af`: `StaveConnector` adds `xShift` to `singleLeft` and `singleRight` (upstream 5.9.0 ignores it for these types). `PedalMarking` types `bracketOpenBegin`, `bracketOpenEnd`, `bracketOpenBoth` and `mixedOpenEnd` omit the start or end hook, so a pedal line can continue across a system break. No effect on parity: the upstream tests use no x-shift on single connectors and do not have these pedal types.

## 4.x-branch fixes not in upstream 5.9.0

- [ ] `3c5209d0`: banjo tunings `doubleCBanjo`, `doubleDBanjo`, `sawmillBanjo`.
- [ ] `7d9bb0d4`: key signature on a non-treble stave (`setClefLines`); map it to `KeySignature.setClef`/`clefOverride`.
- [ ] `198b8021`: BarNote draws inside `openGroup`/`closeGroup`.
- [ ] `d5d26994`: half-rest dot position (visual check against 5.x `dot.ts`).

## Swift-native design (not upstream)

- [ ] Typed specs: `NoteDurationSpec`, `StaffKeySpec`, `ClefName`, `TimeSignatureSpec`, `NonEmptyArray`.
- [ ] Throwing and failable parsing APIs (`…Throwing`, `init(parsing:)`, `ParserError`).
- [ ] `VexRuntimeContext` and `VexRuntime.withContext` instead of module globals.
- [ ] Render back ends: `SVGRenderContext` (string serializer), `SwiftUICanvasContext`, `VexCanvas`.
- [ ] `Compatibility/` layer: `Flow`, `Vex`, `Version`.
- [ ] EasyScore 5.2.0: string builder options, `Character` source offsets, typed composition specs, non-throwing variants that record `lastError` (see `docs/port-notes/5.2.0.md`).
- [ ] Engraving 5.3.0: bundled SMuFL metadata subsets for Bravura, Petaluma and Leland (`Resources/smufl`, `EngravingProfile.bundledMetadata(for:)`, `EngravingProfile.bundled(...)`); upstream takes the metadata from the caller only. Typed `MeasuredSpacing` and `TupletOptions.displayRatio`; a negative `NoteHeadStruct.displacementColumn` is clamped to 0; `Beam` skips the multi-voice clearance for notes without a tick context (see `docs/port-notes/5.3.0.md`).
- [ ] Instruments and phrase layout 5.4.0: typed `GuitarStroke` (enums for finger, direction, arrows), `TimedStringBend` phases as `(Int, Int)` tuples, `FrettedPosition` (`.fret`/`.dead`), `FretDiagramString` (`.muted`/`.fret`), `PercussionInstrument.Head`/`.Stem` enums, `StaveBarlineSpan`, `SystemRowLayout`, `PhraseMark`/`PhraseRoute` protocols, `PhraseLayoutError` (upstream `RangeError`). An invalid timed bend in `notation` sets `Note.initError`/`TabNote.tabInitError` (`.invalidNotation`) instead of throwing from the constructor. `CurveOptions.authoredControls` records an explicit `cps` argument (see `docs/port-notes/5.4.0-part1.md`).
- [ ] VexFlow 5.7.0: `splitstem.ts` and `chordspacing.ts` keep module `WeakMap`/`WeakSet` registries; Swift stores a weak `SplitStemLink` on each `StaveNote` and an `isLeadChord` flag on `Annotation`. `Beam` is no longer `final` (`ContinuousBeam` subclasses it); `BeamContinuation` is a struct held in `Beam.continuation`. Typed `FeatheredBeamDirection`, `NienteSide`, `ChordHarmony`, `TiedBend` (phases as `(Int, Int)` tuples). `EasyScoreLeadMark` has an optional `harmony` (literal `text` empty) instead of a union. `ChordSymbol.getHorizontalInk()` and `NotationSpelling.chordText(_:)` throw (see `docs/port-notes/5.7.0.md`).
- [ ] VexFlow 5.8.0: the `automaticAccidentals` WeakSet is an internal `Accidental.isAutomatic` flag. `meterPositions` is keyed by `ObjectIdentifier`. `PublicationCondense.players`/`.measures` are arrays (upstream tuples). `Beam.postFormat()` does not throw: a bad slope option is kept in `Beam.slopeError` and `draw()` throws it. Invalid laissez-vibrer or dash input on non-throwing APIs sets `initError` or is ignored; the `…Throwing` variants throw. `SVGRenderContext` writes `path.style.filter` as the serialized browser string `style="filter: drop-shadow(<color> 0px 0px <blur>px);"` (see `docs/port-notes/5.8.0.md`).

## Rendering deviations introduced by the VexFlow 5 port

- [x] Missing SMuFL glyphs: when no font in the CSS family list has a glyph, `TextMeasurer` uses bundled Bravura, then the `.notdef` glyph of the first font. Browsers use an arbitrary system font instead, so upstream reference SVGs for Gonville and Petaluma cases with missing glyphs depend on the machine that made them. Such cases are listed as environment-dependent in the parity harness.
