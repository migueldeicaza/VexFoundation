# Parity notes: changes needed in files owned by other groups

## Stave / connectors / tablature group

### `Compatibility/Flow.swift`: `Flow.STAVE_LINE_THICKNESS` setter

- Upstream 5.0.0 `VexFlow.STAVE_LINE_THICKNESS = x` sets only `MetricsDefaults.Stave.lineWidth` and `MetricsDefaults.TabStave.lineWidth`. It does not change `Tables.STAVE_LINE_THICKNESS` (always 1).
- The Swift setter also calls `context.setStaveLineThickness(newValue)`, so `Tables.STAVE_LINE_THICKNESS` becomes 4. `StaveConnector` and `Barline` read `Tables.STAVE_LINE_THICKNESS` (as upstream does), and the connector becomes 3px too long.
- Needed change: remove `context.setStaveLineThickness(newValue)` from the setter (keep the metrics updates).
- Affected case: `StaveConnector.Single_Draw_Test__4px_Stave_Line_Thickness` (3.0px, all fonts).

### `Rendering/TextMetrics.swift`: synthetic bold glyph bounds

- `StaveSection` text is bold. With Petaluma, the family is `Petaluma,Petaluma Script`, which has no bold face. Chromium makes a synthetic bold, and its `actualBoundingBoxAscent/Descent` is approximately 0.4-0.6px larger than the CoreText value (the advance width is the same).
- Affected cases (Petaluma only): `Stave.Multiple_Stave_Barline_Test` (0.62), `Stave.Multiple_Stave_Barline_Test__14pt_Section_` (0.87), `Stave.Multiple_Staves_Volta_Test` (0.62), `Stave.Volta___Modifier_Measure_Test` (0.62).

### Remaining sub-0.1px differences (text measurement)

- Gonville/Petaluma glyph bounds differ by 0.04 or 0.08px (for example, the flag height that sets the TabNote stem extension, notehead bounding rectangles).
- Text advance widths differ by up to 0.03px (stave text, tab tie text, connector text).
- Small clefs (20pt) advance by approximately 0.0045px more for each clef than in Chromium (`Clef.Small_Clef_*`, max 0.065px).

## Modifiers group (Accidental, Annotation, Articulation, Ornament, ChordSymbol, Strokes, StringNumber, Bend, Vibrato, VibratoBracket, Tremolo, TextNote)

### `Rendering/TextMetrics.swift`: OpenType features on Bravura SMuFL strings

- Chromium measures multi-glyph SMuFL strings in Bravura as the plain sum of the glyph advances. It applies neither the GSUB `liga`/`ccmp` ligatures nor the GPOS `kern` pairs (both are registered under `DFLT`). CoreText applies both.
- Evidence:
  - Cautionary accidentals: `U+E26A U+E261 U+E26B` (parenthesized natural) is the ligature `uniF5E1` (14.40px at 20pt) in CoreText. The Chromium width is 12.00px (3.76 + 4.48 + 3.76). Also `(#)` 14.96 vs 14.16, `(b)` 13.49 vs 13.55, `(##)` 13.28 vs 14.19.
  - `TextNote.Text_Dynamics` (Bravura): `sfz` is 29.28px kerned (CoreText) and 33.48px in Chromium (sum of advances). `rfz` 29.76 vs 35.40.
- This conflicts with the `DFLT` rule in `FontKerning.appliesKerning` (commit ce11af1) for PUA text. Check which case needed `DFLT` kerning before you change it. A possible rule: for text in U+E000...U+F8FF, disable kerning and ligatures (`kCTKernAttributeName: 0` is already used; note that `kCTLigatureAttributeName: 0` had no effect in a quick test, so a font feature setting that turns off `liga`/`ccmp` is necessary).
- Affected cases (Bravura): `Accidental.Basic` (0.86), `Accidental.Factory_API` (0.86), `Accidental.Accidental_Arrangement_Special_Cases` (2.55), `Accidental.Microtonal__Iranian_` (3.0), `Accidental.Cautionary_Accidental` (2.4, also environment-dependent: Bravura has no U+E3DE/U+E3DF), `StringNumber.String_Number_In_Notation` and `..._no_circle` (0.80), `TextNote.Text_Dynamics` (20.4).

### `Rendering/FontRegistry.swift`: bold italic Academico

- `Stroke.text` is `bold italic`. Academico has regular and bold faces only. Chromium uses the bold face with a synthetic italic (`R` advance 9.933px at 10pt). The Swift lookup uses the regular face (9.627px), so the rasgueado `R` is 0.152px too far right.
- Needed change: when bold+italic is requested and the family has no bold-italic face, use the bold face.
- Affected cases (Bravura, Gonville; 0.15px): `Strokes.Multi_Voice`, `Strokes.Notation_and_Tab`, `Strokes.Multi_Voice_Notation_and_Tab`, `StringNumber.Multi_Voice_With_Strokes__String___Finger_Numbers`.

### `Rendering/TextMetrics.swift`: synthetic bold bounds (same cause as the Stave item above)

- `FretHandFinger` text is bold 9pt. With Petaluma the text font is Petaluma Script (no bold face). The Chromium `actualBoundingBoxAscent` is 0.188px larger than the CoreText value, which changes the note bounding rectangle.
- Affected cases (Petaluma, 0.188px): `StringNumber.Fret_Hand_Finger_In_Notation`, `StringNumber.Complex_Measure_With_String___Finger_Numbers`.

### Gonville glyph bounds

- Gonville glyph bounds differ by approximately 0.04px. `Ornament` stacks the upper/lower accidental positions on these bounds, so the difference grows to 0.2px in `Ornament.With_Upper_Lower_Accidentals.Gonville`.

### Environment-dependent cases (SMuFL glyph missing from the music font; not fixable)

- Gonville: `Accidental.Sagittal`, `Accidental.Cautionary_Accidental`, `Accidental.Microtonal__Iranian_` (U+E460/E461), `Annotation.Fingerpicking` (U+EAB0), `ChordSymbol.*` (all 8 cases: U+E870-E87C, U+ED60/ED62, U+E5D5/E5D7), `Ornament.Jazz_Ornaments` (U+E5D0-E5E7), `Strokes.Arpeggio_directionless__without_arrows_` (U+E053), `Vibrato.Simple_Vibrato`, `Vibrato.Harsh_Vibrato`, `Vibrato.Vibrato_with_Bend` (U+EAB0, U+EAC0, U+EAE2), `VibratoBracket.*` (3 cases).
- Petaluma: `Accidental.Sagittal`, `Accidental.Cautionary_Accidental`, `Strokes.Multi_Voice`, `Strokes.Notation_and_Tab`, `Strokes.Multi_Voice_Notation_and_Tab`, `StringNumber.Multi_Voice_With_Strokes__String___Finger_Numbers` (arrowheads U+EB78/EB7C).

## Notes group (StaveNote, NoteHead, Percussion, Rests, Rhythm, Dot, GhostNote, GlyphNote, Grace_Notes, Unison, Three_Voice_Rests, Beam, Auto_Beaming, CrossBeam, Tuplet, Formatter, Voice, EasyScore)

### `Rendering/FontRegistry.swift`: bold italic Academico (same cause as the Modifiers item above)

- `Annotation` text in `bold italic` 14pt uses the regular Academico face in Swift (`L` 12.451px) and the bold face in Chromium (12.913px).
- Affected cases: `Percussion.Percussion_Snare0` (0.29-0.46px, all fonts), `Beam.Complex_Beams_with_Annotations` (0.29-0.46px, all fonts).

### `Rendering/TextMetrics.swift`: synthetic bold bounds (same cause as the items above)

- Affected cases (Petaluma, 0.188px): `Three_Voice_Rests.Three_Voices____1`, `..._2_Complex`, `..._3`, `EasyScore.Draw_Fingerings`, `Formatter.Vertical_alignment___many_mixed_elements`.

### `Rendering/TextMetrics.swift`: glyph ink bounds and 20pt advances

- Bravura fermata (`U+E4C0`/`U+E4C1`, 30pt): the Chromium bounds are 0.36px larger than the font outline bounds (13.16px ascent in the font, CoreText and fontTools). Affected: `StaveNote.Center_Aligned_Note_with_Articulation.Bravura` (0.36), `Formatter.Vertical_alignment___many_mixed_elements.Bravura` (0.36).
- Grace noteheads (20pt): Chromium gives 7.865px for `U+E0A4` (font: 295/1000 em = 7.8667px). The difference accumulates along the grace-note group: `Grace_Notes.Grace_Note_Slash_with_Beams` (0.11-0.23px).
- Gonville/Petaluma notehead and flag bounds differ by 0.04-0.24px: `NoteHead.Various_Note_Heads_1.Petaluma` (0.24), `Percussion.Percussion_Basic0/1/2`, `Percussion_Snare1`, `Percussion_Notes` (Gonville, 0.12-0.16), `EasyScore.Draw_Basic_Muted.Gonville` (0.16), `EasyScore.Draw_Options.Petaluma`, `StaveNote.StaveNote_Draw___Slash.Petaluma`, `StaveNote.StaveNote_Draw___Harmonic_And_Muted.Petaluma` (0.12).

### Changes made in the notes group that other groups can see

- `NoteStruct.durationToken` / `StaveNoteStruct.durationToken` / `Note.durationToken`: the duration as written (upstream `Note.duration`, for example `"w"`, `"h"`). Upstream `StaveNote.format()` compares this string (`'8' < 'w'`), so `"w"` and `"1"` give different results.
- `StaveNoteStruct.rawKeys`: a key without an octave (the `"x/"` shorthand) stays as written. `Tables.keyProperties` gives it a NaN line (upstream `parseInt('')`), and `NoteHead` puts it on line 0 (upstream `line || 0`).
