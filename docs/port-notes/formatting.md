# Port notes: formatting group (VexFlow 5.0.0)

Files: `Formatting/{Beam,Formatter,Tuplet,Voice}.swift`,
`Connectors/{Curve,PedalMarking,StaveLine,StaveTie,TextBracket,Vibrato,VibratoBracket}.swift`.

## Requests to the integrator (foundation)

- `VexElement.drawWithStyle()` must call `applyStyle(context: ctx)` (dynamic
  dispatch), not `Self.apply(style, to:)`. Upstream `drawWithStyle` calls
  `this.applyStyle(ctx)`, and `TextBracket` overrides `applyStyle` to set the
  bracket color, line width and the fonts of its text elements. The override
  exists (`TextBracket.applyStyle(context:style:)`), but it is not called
  until `drawWithStyle` dispatches to it.

## Cross-file assumptions (other groups)

- Modifier: `getWidth()` is the `VexElement` text width (upstream
  `Modifier` has no width field). `Vibrato.setVibratoWidth` sets `text` and
  reads `getWidth()`. `setXShift`, `setTextLine` are `@discardableResult`.
  `checkAttachedNoteThrowing()`, `checkIndex()` are kept.
- Note: `getWidth()` (tickable width, used by `VibratoBracket` and the
  formatter `paddingMaxCalc`), `getGlyphWidth()`, `getYs()`,
  `getTieRightX/LeftX()`, `getStemExtents() -> (topY, baseY)`,
  `getStemDirection() -> StemDirection`, `getLineForRest()`,
  `getModifierStartXY(position:index:)`, `getMetrics()` with
  `modLeftPx/modRightPx`, `getYForTopText(_:)`, `getBeam()`, `hasBeam()`,
  `getTupletStack()`, `setTuplet`/`resetTuplet`.
- Tickable: `getVoiceThrowing()`, `getFormatterMetrics()` (reference type),
  `getAbsoluteX()`, `setCenterXShift`, `getStave()`, `setStave(_:)`.
  `Tickable.getVoice()` uses `Voice()`: `Voice.init(time: VoiceTime? = nil)`
  is kept.
- TickContext: `init(tickID:)`, `addTickable(_:voiceIndex:)`, `move(_:_:_:)`,
  `getDeviationCost()`, `getFormatterMetrics()`, `tContexts`.
- StemmableNote: `keyProps`, `getStem()`, `getStemX()`, `getStemExtension()`,
  `getGlyphProps().beamCount`, `getBeamCount()`, `setStemDirection(_:)`,
  `setBeam(_:)`.
- Stem: `getExtension()`, `setExtension(_:)`, `adjustHeightForBeam()`,
  `setVisibility(_:)`, `setStemlet(_:height:)` (existing Swift label kept;
  upstream `setStemlet(isStemlet, stemletHeight)`), `setNoteHeadXBounds`,
  `drawWithStyle()`.
- StaveNote: `getKeyProps()`, `setKeyLine(_:line:)`.
- Stave: `getYForTopText`, `getYForBottomText`, `getYForLine`,
  `getTieStartX/EndX`, `getNoteStartX/EndX`, `Stave.defaultPadding`,
  `modifiers`, `getX()`, `getWidth()`.
- StaveModifier: `getPosition() == .end`, `getModifierWidth()` (PedalMarking
  VexFlowPatch `setEndStave`).
- `StaveConnector(topStave:bottomStave:)` (used by `Formatter.FormatAndDrawTab`).
- TabSlide/TabTie (tab group) override `StaveTie.renderTie(direction:
  TieDirection, firstX:lastX:firstYs:lastYs:)` and use `notes.firstIndexes`,
  `init(notes:text: String?)`, `direction: TieDirection?`.
- `Metrics` keys used: `Tuplet.yOffset`, `Tuplet.textYOffset`,
  `Stave.padding`, `Stave.endPaddingMin/Max`, `Stave.unalignedNotePadding`,
  `PedalMarking.text`, `fontFamily`.

## Public API changes

- `TieNotes` and `StaveLineNotes`: `firstIndices/lastIndices` renamed to
  `firstIndexes/lastIndexes` (deprecated aliases kept).
- `StaveTie`: `renderTie(direction:firstX:lastX:firstYs:lastYs:)` (was
  `firstXPx/lastXPx`), new `renderTieText`, `getDirection`, `getFirstX/LastX`,
  `getFirstYs/LastYs`, `synchronizeIndexes`; the `text: String?` property is
  gone (use `VexElement.text`). `TieRenderOptions` adds `shortTieCutoff`,
  `cp1Short`, `cp2Short`.
- `StaveLine`: `renderOptions` (was `lineRenderOptions`), text is
  `VexElement.text`, `applyLineStyle()` public.
- `TextBracket`: `position`, `renderOptions`, `textElement`,
  `superscriptElement`; init with `positionString:`. The `text` stored
  property is gone (use `textElement`).
- `PedalMarking`: `type`, `line`, `depressText`, `releaseText`,
  `renderOptions` (old names deprecated), `setType(_ String)`, `typeString`,
  `GLYPHS` keys `pedalDepress/pedalRelease` (SMuFL strings).
- `Vibrato`: glyph based. `VibratoRenderOptions` is now `{code, width}`;
  `setHarsh`, `renderVibrato` removed. `setVibratoCode(_:)` added.
  `VibratoBracket`: `setVibratoCode`, `vibrato`, `line`; `setHarsh` removed.
- `Curve`: `CurveOptions.openingDirection`, `renderCurve(... direction: Double)`.
- `Tuplet`: text drawn with `textElement` (SMuFL tuplet digits);
  `TupletOptions.textYOffset`; `xPos/yPos/tupletWidth`, `Tuplet.metrics`,
  `TupletMetrics` removed (width is `VexElement.width`).
- `Beam`: `getDefaultBeamGroups(_ String)` added (typed overload kept),
  `BeamError.noNotes/.noLastBeamX`, `useUnformattedStemExtentsForTuplets`
  parity hook removed.
- `Voice`: `init(time: String)`, `getBoundingBox()` computed (no cached
  `boundingBox`), `draw()` override, `VoiceError.missingStave`.
- `Formatter`: `modifierContexts` is `[AlignmentModifierContexts]`;
  `lastError` is `Error?`; `durationStats`; `FormatAndDrawTab`;
  `alignRestsThrowing`.

## Behavior changes to check in tests

- `Formatter.formatToStave` no longer sets `options.stave` (upstream). Without
  a stave in the options, `format` does not call `voice.setStave().preFormat()`
  or `postFormat()`. Callers that relied on it must pass `stave`.
- `Formatter.preFormat` with one tick context returns 0 without `evaluate()`
  (upstream).
- Removed the Swift-only "underfilled soft voice" trailing-space hack in
  `Formatter.evaluate()`.
- `Formatter.format` throws (non-throwing variant records `lastError`) for
  an empty voice list (upstream `alignRests` error).
- `shiftToIdealDistances` throws when a context has no earlier tickable in
  the same voice (upstream `defined()`).
