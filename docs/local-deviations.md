# Local deviations from upstream VexFlow

This list holds each local change that must survive an upstream upgrade.
Upstream base before the 5.x upgrade: `a0c4d47a` (4.2.6+, 4.x branch).
Check each item after each milestone. Remove an item only when upstream has the same behavior.

When `VexRuntimeContext.upstreamParityMode` is `true`, the items marked **(gated)** are disabled so that output matches upstream.

## OSMD-derived patches (`VexFlowPatch` comments, commit b7f260a)

- [ ] PedalMarking: extended pedal styles, multi-stave pedals, end-stave width adjustment (`Connectors/PedalMarking.swift`).
- [ ] TextBracket: the bracket does not go backwards and does not overlap the text (`Connectors/TextBracket.swift`).
- [ ] Articulation: breath-mark position at a percentage of the distance to the next note; respect the modifier `yShift` (`Modifiers/Articulation.swift`).
- [ ] Tables and NoteHead: notehead y-shift that does not depend on stem length (`stemUpYShift`, `stemDownYShift`).
- [ ] Tables and Note: `useAlternativeXGlyph`, a classical X notehead for tab notes.
- [ ] Tables: TI (inverted triangle) notehead shift properties **(gated)**.
- [ ] Stave: guard against a NaN modifier width.
- [ ] Stave: do not overwrite `modifier.x` or `startX` when they are already larger (alignment) **(gated)**.
- [ ] Barline: double heavy barline type.
- [ ] TabNote: configurable background color instead of `clearRect`.
- [ ] StaveTempo: SVG groups around the tempo marking and the BPM text.
- [x] StaveNote: `paddingRight`; keep notehead types (for example slash) across a notehead rebuild; ledger-line style; ledger SVG group **(gated)**.
- [ ] Formatter: no tick-mismatch error between voices; guard against zero `totalTicks`; guard against GhostNote in key-props lookups.
- [ ] Tuplet: option to hide the tuplet number.
- [ ] Beam: reset stem extensions to base values before recalculation.

## Other local commits

- [ ] `1af03ba`: `Factory.formatSystems()`; `applyStyle()`/`restoreStyle()` in the `draw()` of `Beam`, `Tuplet` and `Curve`.
- [ ] `252b9a7`: TabStave tracks if `spacingBetweenLinesPx` was given (default 13, explicit value kept). Beam cap `endX + 1` (check upstream 5.x).

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

## Rendering deviations introduced by the VexFlow 5 port

- [x] Missing SMuFL glyphs: when no font in the CSS family list has a glyph, `TextMeasurer` uses bundled Bravura, then the `.notdef` glyph of the first font. Browsers use an arbitrary system font instead, so upstream reference SVGs for Gonville and Petaluma cases with missing glyphs depend on the machine that made them. Such cases are listed as environment-dependent in the parity harness.
