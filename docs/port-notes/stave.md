# Port notes: stave group (VexFlow 5.0.0)

Files: `Stave/*.swift` (Stave, StaveModifier, Barline, Clef, KeySignature, TimeSignature,
MultiMeasureRest, StaveConnector, StaveHairpin, StaveRepetition, StaveSection, StaveTempo,
StaveText, Volta, Crescendo).

## Assumptions about other groups

- `Tables.accidentalCodes(_ acc: String) -> String` (upstream 5.0 static function; returns the
  glyph string, or `acc` when unknown). Used by `KeySignature.convertToGlyph`.
- `Tables.keySignature(_:) throws -> [(type: String, line: Double)]` (unchanged).
- `Tables.STAVE_LINE_THICKNESS`, `Tables.STAVE_LINE_DISTANCE` (unchanged).
- `Note.checkStaveThrowing()`, `Note.getModifierStartXY(position:index:)`,
  `Tickable.checkTickContextThrowing()`, `Tickable.preFormat()` (no return value),
  `TickContext.getNextContext(_:)`, `Note.preFormatted`, `NoteStruct.line`.
- `Crescendo` uses the `height` of `VexElement`. `Note` must not redeclare `height`.
- `TextJustification` (TextNote) has LEFT=1, CENTER=2, RIGHT=3. `StaveTextJustification` uses
  the same values.

## API changes the other groups must use

- `StaveModifier` no longer stores `modifierWidth` / `modifierX`. Use the `VexElement`
  `width` / `x`, `getWidth()` / `setWidth(_:)`, `getX()` / `setX(_:)`. Deprecated shims remain.
- Drawing a stave modifier: `mod.setStave(stave); mod.setContext(ctx); try mod.drawWithStyle()`
  (or `try mod.draw()`). `drawStave(stave:xShift:)` is a deprecated shim. `placeGlyphOnLine`
  is removed.
  - BarNote: `barline.setX(absX); barline.setStave(stave); barline.setContext(ctx); try barline.drawWithStyle()`.
  - KeySigNote: same with `keySignature`; width from `keySignature.getWidth()`.
  - TimeSigNote: `timeSig.drawAt(ctx, stave, absX)`; width from `timeSig.getWidth()`.
  - ClefNote: `clef.setX(absX); clef.setY(stave.getYForLine(clef.line)); clef.renderText(ctx, xPos: 0, yPos: 0)`.
- `StaveModifier.init()` is the designated init (calls `VexElement.init(category: nil)`).
  `setStave`, `getPadding`, `getPosition`, `setPosition` are `open`.
- `Stave`: `staveX`/`staveY`/`staveWidth`/`staveHeight`, `setStaveX`/`setStaveY`/`setStaveWidth`,
  `getBBox()` are deprecated. Use `x`/`y`/`width`/`height`, `setX`/`setY`/`setWidth`,
  `getBoundingBox()` (non-nil for Stave). `setX(_:)` and `setWidth(_:)` override VexElement.
- `Stave.setText(_:position:options:)` was renamed `setStaveText` (upstream). A deprecated shim
  remains for the typed variant only; the parsing variants are now `setStaveText(_:parsingPosition:...)`.
- `StaveOptions.fillStyle` was removed (upstream removed `fill_style`; style comes from
  `Metrics` `Stave.strokeStyle`). `Stave.getStyle()` no longer adds defaults.
- `Stave.getTopLineTopY()` is `getYForLine(0)`; `getBottomLineBottomY()` adds the style
  line width (5.0 behavior).
- `Stave.draw()` offsets the lines by 0.5 when the line width is odd (5.0 behavior).
- `Barline`: `getType()` / `setType(_:)` (upstream names); `getBarlineType` / `setBarlineType`
  kept as aliases. `init(parsing:)` and `setType(_ : String)` take type strings.
- `Clef`: properties `code`, `line`, `size`, `type`; `setType(_:size:annotation:)`
  (`setClefType` kept as alias). `clefDef`, `annotation`, `attachment`, `clefTypeName`,
  `annotationSmufl` removed. `Clef.getPoint(_:)` reads `Metrics` `fontSize`.
- `TimeSignature`: `init(timeSpec:customPadding:validateArgs:)`, `init?(parsing:...)`,
  `topText`/`botText` elements, `line`, `drawAt(_:_:_:)`, static `getTimeSigCode(_:smallSig:)`.
  `tsPoint`, `tsLine`, `getGlyph()` removed.
- `KeySignature`: children are `VexElement` glyphs (`children`); `glyphs`, `xPositions`,
  `getGlyphs()`, `glyphFontScale` removed. `format()` creates a dummy stave when none is set.
- `MultiMeasureRest`: `renderOptions` (`renderOpts` deprecated); `stave` (was `mmrStave`);
  `drawLine(_:_:_:_:) throws` and `drawSymbols(_:_:_:_:)` use the 5.0 glyph-text algorithm.
  `MultiMeasureRestRenderOptions.semibreveRestGlyphScale` and `numberGlyphPoint` are now
  optional parameters that default to `Metrics` (`fontSize`, `MultiMeasureRest.fontSize`).
- `StaveConnector`: `type` (was `connectorType`, deprecated alias), `xShift` from VexElement
  (`connectorXShift` removed), `texts: [VexElement]`, `setType(_ : String)`,
  `ConnectorType.single`. `setText(_:)` overrides VexElement and adds a text.
- `StaveHairpin`: `hairpin` (was `hairpinType`), `position` (was `hairpinPosition`), both
  with deprecated aliases. `HairpinRenderOptions` gains `leftShiftTicks`/`rightShiftTicks`
  (`StaveHairpinRenderOptions` typealias). New static
  `FormatByTicksAndDraw(_:pixelsPerTick:firstNote:lastNote:type:position:options:)`:
  upstream takes `formatter: { pixelsPerTick }`; the caller passes the number.
- `StaveRepetition` (typealias `Repetition`), `StaveSection`, `StaveTempo`, `StaveText`, `Volta`:
  shifts use `VexElement.xShift`/`yShift`; label text uses `VexElement.text`.
  `setShiftX`/`setShiftY`/`setStaveSection`/`setStaveText` on those classes are deprecated
  (except `StaveRepetition.setShiftX/Y`, which upstream keeps).
  `StaveSection.init(section:x:shiftY:drawRect:)` now has defaults for `x`/`shiftY`.
  `Volta.type` (was `voltaType`).
- `StaveTempoOptions` gains `parenthesis`, `bpmText` (upstream string `bpm`, e.g. "80-90"),
  `duration2`, `dots2`.
- `Stave.setRepetitionType`, `setVoltaType`, `setTempo`, `setStaveText` append to `modifiers`
  without `addModifier` (as upstream). `setSection` uses `addModifier`.

## Kept local deviations

- Stave NaN modifier width guard (VexFlowPatch).
- Stave: do not overwrite `modifier.x` / `startX` when larger (VexFlowPatch, gated by
  `upstreamParityMode`).
- `StaveOptions.spacingBetweenLinesPxWasSpecified` (commit 252b9a7) for TabStave.
- `Stave.setClefLines(_:)` (4.x fix 7d9bb0d4; not in 5.0.0).
- Barline `doubleHeavy` (VexFlowPatch).
- StaveTempo `stavetempo` and `bpm` SVG groups (VexFlowPatch, not gated). In 5.0 the `bpm`
  group wraps the "=" through ")" texts.
- Removed 4.x parity corrections in StaveRepetition and StaveSection (5.0 algorithms replace them).

## Upstream behavior not ported exactly

- `KeySignature.format()` does not throw for an unknown key spec (empty signature instead).
- `Stave.getModifierXShift(index)` checks the index range; upstream would throw a TypeError.
- `TimeSignature.getTimeSigCode` returns `Glyphs.null` for non-digit characters (upstream
  `String.fromCodePoint(NaN)` throws).
- Debug logging (`Clef.DEBUG`, `Crescendo.DEBUG`) uses `print`.

## Verification

Smoke-rendered with the foundation and a Tables stub, compared with
`vexflow-5.0.0/build/images/reference/svg_*.Bravura.svg`:
TimeSignature "Basic Time Signatures" is identical. KeySignature "Cancelled key test",
Stave "Stave Text Test", "Tempo Test", "Stave Repetition (CODA) Positioning" and
MultiMeasureRest "Simple Test" differ only by text-measurement rounding (0.001 to about 1 px
for bold text), which comes from `TextMetrics`.
