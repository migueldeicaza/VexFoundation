# Parity status against VexFlow 5.4.0

This file records the opt-in SVG parity results against the upstream 5.4.0 reference SVGs (`vexflow-5.4.0/build/images/reference/svg_<Module>.<Test>.<Font>.svg`).

## How to run

```sh
VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_TAG=5.4.0 \
VEXFOUNDATION_UPSTREAM_SVG_DISABLE_PER_CASE_EPSILON=1 \
VEXFOUNDATION_UPSTREAM_SVG_ARTIFACTS_DIR=$PWD/.build/upstream-svg-parity/artifacts-gate \
swift test --scratch-path .build-port --filter UpstreamSVGParityTests > /tmp/gate.log 2>&1
tools/parity_report.py --artifacts .build/upstream-svg-parity/artifacts-gate --min 0.1 --rows
```

## Results

| | Before | After |
|---|---|---|
| Parity cases (each runs Bravura, Gonville, Petaluma) | 445 | 461 (all 461 upstream SVG cases) |
| "Missing upstream reference" issues | 54 (18 cases) | 0 |
| Font runs over 0.1 px | 127 | 125 |
| Row-count (`ROWS`) mismatches | 6 | 0 |
| Structure (`STRUCT`) mismatches | 14 | 8 (all Gonville, missing glyphs) |
| Over 0.1 px, not caused by a missing glyph | 26 (plus the 20 `ROWS`/`STRUCT`) | 23, all at or below 0.36 px |

## Test changes

Renamed to the 5.4.0 names (the drawing code was already the same as 5.4.0):

- `Articulation.Articulation___<X>` to `Articulation.<X>` (12 cases): `Vertical_Placement`, `Vertical_Placement__Glyph_codes_`, `Staccato_Staccatissimo`, `Accent_Tenuto`, `Marcato_L_H__Pizzicato`, `Snap_Pizzicato_Fermata`, `Up_stroke_Down_Stroke`, `Fermata_Above_Below`, `Fermata_Short_Above_Below`, `Fermata_Long_Above_Below`, `Fermata_Very_Long_Above_Below`, `Inline_Multiple`.
- `Strokes.Strokes___Brush_Roll_Rasquedo` to `Strokes.Brush_Roll_Rasgueado` (now uses `.rasgueadoDown`/`.rasgueadoUp`).
- `Strokes.Strokes___<X>` to `Strokes.<X>`: `Arpeggio_directionless__without_arrows_`, `Multi_Voice`, `Notation_and_Tab`, `Multi_Voice_Notation_and_Tab`.

Removed (upstream removed the test before 5.0.0): `KeySignature.Key_Signature_with_without_clef_symbol`.

Changed to mirror the 5.4.0 test code:

- `Rests.Dotted`: adds the `mr`, `lr`, `1/2r` rests before `wr` and the `256r`, `512r`, `1024r` rests after `128r`.
- `Stave.Stave_End_Modifiers_Test`: the third row uses `RepeatBracketType.straight` and the fourth row uses `RepeatBracketType.curved` on the begin and end bar lines.
- `Tuplet.Nested_Tuplets`: the inner 5:4 tuplet is made before the outer 3:2 tuplet.
- `Tuplet.Single_Tuplets`: the big 4:3 tuplet is made last.

Added (upstream has a reference SVG, the suite had no case):

- Bounding-box variants: `Accidental.Bounding_Box`, `Annotation.Bounding_Box`, `Articulation.Bounding_Box`, `ChordSymbol.Bounding_Box`, `Clef.Bounding_Box`, `Clef.Bounding_Box_Clef_Change`, `GlyphNote.Bounding_Box`. They share the drawing code of the base case and use the new helper `drawUpstreamBoundingBoxes` (upstream `VexFlowTests.drawBoundingBox`).
- `ChordSymbol.Wide_Chord_Symbols`, `Curve.Opening_Direction___up`, `Curve.Opening_Direction___down`, `StaveTie.Tie_Algorithms`.
- `PedalMarking.Simple_Pedal_1b`, `_2b`, `_3b`, `PedalMarking.Release_and_Depress_on_Same_Note_1b`, `_2b` (upstream `createTest2`, two voices on each stave).
- `Demo___Petzold.Minuet_in_G` (new file `UpstreamSVGParityTests-DemoPetzold.swift`; this is the old `Bach_Demo.Minuet_1` case, removed in commit 8648b8e, with the 5.4.0 name).

No other visual test changed between 5.0.0 and 5.4.0. The other diffs in `tests/` add QUnit assertions only, or rename local variables.

## Library fix

- `Rendering/TextMetrics.swift`: glyph ink bounds (`actualBoundingBox*`) now come from the glyph outline (`CTFontCreatePathForGlyph(...).boundingBoxOfPath`). `CTFontGetBoundingRectsForGlyphs` returns bounds that are rounded outward for CFF fonts: for example 0.44 px below the Gonville short fermata (U+E4C4) and 0.12 px above the Petaluma tenuto (U+E4A5). The browser reports the outline bounds. For Bravura the two values are the same. Result: 18 fewer font runs between 0.1 and 1 px (for example `Articulation.Fermata_Short_Above_Below.Gonville` 0.48 to 0.02, `Articulation.Bounding_Box.Petaluma` 0.30 to 0.07, the `Percussion.*.Gonville` cases 0.12-0.16 to 0.03 or less). Some Petaluma noteheads change from 0.08 to 0.099 px (Chromium rounds some Petaluma bounds to whole font units; rounding in Swift made Gonville worse, so it is not done).

## Remaining mismatches over 0.1 px

Classes:

- Environment: the music font has no glyph for the code point. Chromium then uses an arbitrary system font, so the reference depends on the machine that made it (see `docs/local-deviations.md`). Not fixable. 102 font runs (92 Gonville, 10 Petaluma).
- CoreText glyph bounds (Bravura): Chromium bounds are larger than the outline (fermata 0.36 px, clefs and time signatures 0.12 px).
- Fake-bold outset: Petaluma Script has no bold face; Chromium makes a synthetic bold.
- Glyph bounds and advances (Gonville, Petaluma, grace noteheads): differences of 0.1 to 0.23 px.

| Case | Max delta (px) | Classification |
|---|---|---|
| `Annotation.Fingerpicking.Gonville` | STRUCT | Environment: Gonville has no glyph for U+EAB0; the browser used an arbitrary fallback font. |
| `Demo___High_Wire.High_Wire.Gonville` | STRUCT | Environment: Gonville has no glyph for U+EAB0, U+ECA5; the browser used an arbitrary fallback font. |
| `Vibrato.Harsh_Vibrato.Gonville` | STRUCT | Environment: Gonville has no glyph for U+EAC0, U+EAE2; the browser used an arbitrary fallback font. |
| `Vibrato.Simple_Vibrato.Gonville` | STRUCT | Environment: Gonville has no glyph for U+EAB0; the browser used an arbitrary fallback font. |
| `Vibrato.Vibrato_with_Bend.Gonville` | STRUCT | Environment: Gonville has no glyph for U+EAB0, U+EAE2; the browser used an arbitrary fallback font. |
| `VibratoBracket.Harsh_VibratoBracket_Without_End_Note.Gonville` | STRUCT | Environment: Gonville has no glyph for U+EAE2; the browser used an arbitrary fallback font. |
| `VibratoBracket.Harsh_VibratoBracket_Without_Start_Note.Gonville` | STRUCT | Environment: Gonville has no glyph for U+EAE2; the browser used an arbitrary fallback font. |
| `VibratoBracket.Simple_VibratoBracket.Gonville` | STRUCT | Environment: Gonville has no glyph for U+EAB0; the browser used an arbitrary fallback font. |
| `Accidental.Sagittal.Petaluma` | 412.560 | Environment: Petaluma has no glyph for U+E303, U+E305, U+E30A, U+E30D, U+E30F, U+E321; the browser used an arbitrary fallback font. |
| `EasyScore.Draw_Parenthesised.Gonville` | 150.064 | Environment: Gonville has no glyph for U+E0F5, U+E0F6; the browser used an arbitrary fallback font. |
| `Accidental.Cautionary_Accidental.Petaluma` | 146.659 | Environment: Petaluma has no glyph for U+E2A0, U+E2A1, U+E2A2, U+E2A3, U+E2A4, U+E2A5, U+E2B0, U+E2B1, U+E2B2, U+E2B3, U+E2B4, U+E2B5, U+E2B6, U+E2B7, U+E300, U+E301, U+E302, U+E303, U+E304, U+E305, U+E306, U+E307, U+E308, U+E309, U+E30A, U+E30B, U+E30C, U+E30D, U+E30E, U+E30F, U+E310, U+E311, U+E312, U+E313, U+E314, U+E315, U+E316, U+E317, U+E318, U+E319, U+E31C, U+E31D, U+E320, U+E321, U+E322, U+E323, U+E324, U+E325, U+E326, U+E327, U+E328, U+E329, U+E32A, U+E32B, U+E32C, U+E32D, U+E32E, U+E32F, U+E330, U+E331, U+E332, U+E333, U+E334, U+E335, U+E340, U+E341, U+E342, U+E343, U+E344, U+E345, U+E346, U+E347, U+E348, U+E349, U+E34A, U+E34B, U+E34C, U+E34D, U+E34E, U+E34F, U+E350, U+E351, U+E352, U+E353, U+E354, U+E355, U+E356, U+E357, U+E358, U+E359, U+E35A, U+E35B, U+E35C, U+E35D, U+E35E, U+E35F, U+E360, U+E361, U+E362, U+E363, U+E364, U+E365, U+E366, U+E367, U+E370, U+E371, U+E372, U+E373, U+E374, U+E375, U+E376, U+E377, U+E378, U+E379, U+E37A, U+E37B, U+E37C, U+E37D, U+E37E, U+E37F, U+E380, U+E381, U+E382, U+E383, U+E384, U+E385, U+E386, U+E387, U+E390, U+E391, U+E392, U+E393, U+E394, U+E395, U+E396, U+E397, U+E398, U+E399, U+E39A, U+E39B, U+E39C, U+E39D, U+E39E, U+E39F, U+E3A0, U+E3A1, U+E3A2, U+E3A3, U+E3A4, U+E3A5, U+E3A6, U+E3A7, U+E3A8, U+E3A9, U+E3AA, U+E3AB, U+E3AC, U+E3AD, U+E3B0, U+E3B1, U+E3B2, U+E3B3, U+E3B4, U+E3B5, U+E3B6, U+E3B7, U+E3B8, U+E3B9, U+E3BA, U+E3BB, U+E3BC, U+E3BD, U+E3BE, U+E3BF, U+E3C0, U+E3C1, U+E3C2, U+E3C3, U+E3C4, U+E3C5, U+E3C6, U+E3C7, U+E3C8, U+E3C9, U+E3CA, U+E3CB, U+E3CC, U+E3CD, U+E3CE, U+E3CF, U+E3D0, U+E3D1, U+E3D2, U+E3D3, U+E3D4, U+E3D5, U+E3D6, U+E3D7, U+E3D8, U+E3D9, U+E3DA, U+E3DB, U+E3DC, U+E3DD, U+E3DE, U+E3DF, U+E3E0, U+E3E1, U+E3E2, U+E3E3, U+E3E4, U+E3E5, U+E3E6, U+E3E7, U+E3E8, U+E3E9, U+E3EA, U+E3EB, U+E3EC, U+E3ED, U+E3EE, U+E3EF, U+E3F0, U+E3F1, U+E3F2, U+E3F3, U+E3F4, U+E3F5, U+E3F6, U+E3F7, U+E420, U+E421, U+E422, U+E423, U+E424, U+E425, U+E426, U+E427, U+E428, U+E429, U+E42A, U+E42B, U+E42C, U+E42D, U+E42E, U+E42F, U+E430, U+E431, U+E432, U+E433, U+E434, U+E435; the browser used an arbitrary fallback font. |
| `Strokes.Notation_and_Tab.Petaluma` | 68.040 | Environment: Petaluma has no glyph for U+EB78, U+EB7C; the browser used an arbitrary fallback font. |
| `Strokes.Brush_Roll_Rasgueado___bounding_box.Petaluma` | 68.040 | Environment: Petaluma has no glyph for U+EB78, U+EB7C; the browser used an arbitrary fallback font. |
| `GlyphNote.GlyphNote_No_Stave_Padding.Gonville` | 57.360 | Environment: Gonville has no glyph for U+E500, U+E501, U+E502, U+E504; the browser used an arbitrary fallback font. |
| `Accidental.Sagittal.Gonville` | 56.400 | Environment: Gonville has no glyph for U+E303, U+E305, U+E30A, U+E30D, U+E30F, U+E321; the browser used an arbitrary fallback font. |
| `Clef.Bounding_Box.Gonville` | 52.480 | Environment: Gonville has no glyph for U+E052, U+E053, U+E064; the browser used an arbitrary fallback font. |
| `Strokes.Brush_Roll_Rasgueado.Petaluma` | 45.000 | Environment: Petaluma has no glyph for U+EB78, U+EB7C; the browser used an arbitrary fallback font. |
| `Strokes.Multi_Voice.Petaluma` | 45.000 | Environment: Petaluma has no glyph for U+EB78, U+EB7C; the browser used an arbitrary fallback font. |
| `Strokes.Multi_Voice_Notation_and_Tab.Petaluma` | 45.000 | Environment: Petaluma has no glyph for U+EB78, U+EB7C; the browser used an arbitrary fallback font. |
| `StaveNote.StaveNote_Draw___Slash.Gonville` | 41.508 | Environment: Gonville has no glyph for U+E100, U+E102, U+E103, U+E10A; the browser used an arbitrary fallback font. |
| `Clef.Clef_End_Test.Gonville` | 37.080 | Environment: Gonville has no glyph for U+E052, U+E053, U+E064; the browser used an arbitrary fallback font. |
| `Clef.Clef_Test.Gonville` | 37.080 | Environment: Gonville has no glyph for U+E052, U+E053, U+E064; the browser used an arbitrary fallback font. |
| `Clef.Bounding_Box_Clef_Change.Gonville` | 34.991 | Environment: Gonville has no glyph for U+E052, U+E053; the browser used an arbitrary fallback font. |
| `Tuplet.Awkward_Tuplet.Gonville` | 25.600 | Environment: Gonville has no glyph for U+E881, U+E882, U+E883, U+E884, U+E88A; the browser used an arbitrary fallback font. |
| `Clef.Small_Clef_End_Test.Gonville` | 24.773 | Environment: Gonville has no glyph for U+E052, U+E053, U+E064; the browser used an arbitrary fallback font. |
| `Clef.Small_Clef_Test.Gonville` | 24.769 | Environment: Gonville has no glyph for U+E052, U+E053, U+E064; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___beamed_slash_notes__some_rests.Gonville` | 24.640 | Environment: Gonville has no glyph for U+E100, U+E102; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___slash_notes.Gonville` | 24.640 | Environment: Gonville has no glyph for U+E100, U+E102, U+E103; the browser used an arbitrary fallback font. |
| `NoteHead.Drum_Chord_Heads.Gonville` | 21.640 | Environment: Gonville has no glyph for U+E0B8, U+E0B9; the browser used an arbitrary fallback font. |
| `NoteHead.Various_Heads.Gonville` | 21.640 | Environment: Gonville has no glyph for U+E0B8, U+E0B9; the browser used an arbitrary fallback font. |
| `NoteHead.Various_Note_Heads_1.Gonville` | 21.640 | Environment: Gonville has no glyph for U+E0A1, U+E0A6, U+E0B0, U+E0B1, U+E0B2, U+E0B8, U+E0B9, U+E0BA, U+E0C3, U+E0C4, U+E0C5, U+E0C7, U+E0CF, U+E0D0, U+E0D1, U+E0D2, U+E0D3, U+E0D4, U+E0D5, U+E0D6, U+E0E4, U+E0E5, U+E0E6, U+E0E7; the browser used an arbitrary fallback font. |
| `NoteHead.Various_Note_Heads_2.Gonville` | 21.640 | Environment: Gonville has no glyph for U+E0B9, U+E0C0, U+E0C2, U+E0CB, U+E0CD; the browser used an arbitrary fallback font. |
| `GlyphNote.GlyphNote_RepeatNote.Gonville` | 20.740 | Environment: Gonville has no glyph for U+E500, U+E501, U+E502, U+E504; the browser used an arbitrary fallback font. |
| `Ornament.Jazz_Ornaments.Gonville` | 20.520 | Environment: Gonville has no glyph for U+E5D0, U+E5D2, U+E5D5, U+E5D7, U+E5DE, U+E5E1, U+E5E2, U+E5E3, U+E5E4, U+E5E5, U+E5E7; the browser used an arbitrary fallback font. |
| `StaveNote.StaveNote_Draw___Harmonic_And_Muted.Gonville` | 20.440 | Environment: Gonville has no glyph for U+E0A6, U+E0D7; the browser used an arbitrary fallback font. |
| `Demo___Pocket_Change.Pocket_Change.Gonville` | 19.420 | Environment: Gonville has no glyph for U+E0F5, U+E0F6, U+E883, U+ECA5; the browser used an arbitrary fallback font. |
| `Tuplet.Bottom_Ratioed_Tuplet.Gonville` | 17.560 | Environment: Gonville has no glyph for U+E881, U+E882, U+E883, U+E88A; the browser used an arbitrary fallback font. |
| `EasyScore.Draw_Basic_Slash.Gonville` | 16.800 | Environment: Gonville has no glyph for U+E100, U+E103; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___16th_note_rhythm_with_scratches.Gonville` | 16.688 | Environment: Gonville has no glyph for U+E100; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___beamed_slash_notes.Gonville` | 16.688 | Environment: Gonville has no glyph for U+E100; the browser used an arbitrary fallback font. |
| `GlyphNote.Bounding_Box.Gonville` | 15.480 | Environment: Gonville has no glyph for U+E504, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `Style.TabNote_modifiers_Style.Petaluma` | 15.442 | Environment: Petaluma has no glyph for U+EB78; the browser used an arbitrary fallback font. |
| `StringNumber.Multi_Voice_With_Strokes__String___Finger_Numbers.Petaluma` | 15.440 | Environment: Petaluma has no glyph for U+EB78, U+EB7C; the browser used an arbitrary fallback font. |
| `StaveNote.Center_Aligned_Note_with_Multiple_Modifiers.Petaluma` | 15.438 | Environment: Petaluma has no glyph for U+EB7C; the browser used an arbitrary fallback font. |
| `Tuplet.Bounding_Box_Above.Gonville` | 15.280 | Environment: Gonville has no glyph for U+E882, U+E883, U+E88A, U+ECA5; the browser used an arbitrary fallback font. |
| `Tuplet.Bounding_Box_Below.Gonville` | 15.280 | Environment: Gonville has no glyph for U+E882, U+E883, U+E88A, U+ECA5; the browser used an arbitrary fallback font. |
| `Tuplet.Ratioed_Tuplet.Gonville` | 15.280 | Environment: Gonville has no glyph for U+E882, U+E883, U+E884, U+E88A; the browser used an arbitrary fallback font. |
| `Beam.TabNote_Beams_Up.Gonville` | 14.640 | Environment: Gonville has no glyph for U+E882, U+E883, U+E88A; the browser used an arbitrary fallback font. |
| `Tuplet.Single_Tuplets.Gonville` | 14.640 | Environment: Gonville has no glyph for U+E882, U+E883, U+E884, U+E88A; the browser used an arbitrary fallback font. |
| `Tuplet.Beamed_Tuplet.Gonville` | 14.360 | Environment: Gonville has no glyph for U+E882, U+E883, U+E887, U+E88A; the browser used an arbitrary fallback font. |
| `Tuplet.Bottom_Suffixed_Tuplet.Gonville` | 14.160 | Environment: Gonville has no glyph for U+E881, U+E882, U+E883, U+E88A, U+ECA5, U+ECA7; the browser used an arbitrary fallback font. |
| `EasyScore.Keys.Gonville` | 13.480 | Environment: Gonville has no glyph for U+E460, U+E461; the browser used an arbitrary fallback font. |
| `Accidental.Microtonal__Iranian_.Gonville` | 13.472 | Environment: Gonville has no glyph for U+E460, U+E461; the browser used an arbitrary fallback font. |
| `Accidental.Cautionary_Accidental.Gonville` | 12.509 | Environment: Gonville has no glyph for U+E265, U+E266, U+E267, U+E268, U+E269, U+E276, U+E277, U+E278, U+E279, U+E27A, U+E27B, U+E284, U+E285, U+E290, U+E291, U+E292, U+E293, U+E294, U+E295, U+E296, U+E297, U+E298, U+E299, U+E29A, U+E29B, U+E29C, U+E2A0, U+E2A1, U+E2A2, U+E2A3, U+E2A4, U+E2A5, U+E2B0, U+E2B1, U+E2B2, U+E2B3, U+E2B4, U+E2B5, U+E2B6, U+E2B7, U+E2C0, U+E2C1, U+E2C2, U+E2C3, U+E2C4, U+E2C5, U+E2C6, U+E2C7, U+E2C8, U+E2C9, U+E2CA, U+E2CB, U+E2CC, U+E2CD, U+E2CE, U+E2CF, U+E2D0, U+E2D1, U+E2D2, U+E2D3, U+E2D4, U+E2D5, U+E2D6, U+E2D7, U+E2D8, U+E2D9, U+E2DA, U+E2DB, U+E2DC, U+E2DD, U+E2DE, U+E2DF, U+E2E0, U+E2E1, U+E2E2, U+E2E3, U+E2E4, U+E2E5, U+E2E6, U+E2E7, U+E2E8, U+E2E9, U+E2EA, U+E2EB, U+E2EC, U+E2ED, U+E2EE, U+E2EF, U+E2F0, U+E2F1, U+E2F2, U+E2F3, U+E2F4, U+E2F5, U+E2F6, U+E2F7, U+E2F8, U+E2F9, U+E2FA, U+E2FB, U+E300, U+E301, U+E302, U+E303, U+E304, U+E305, U+E306, U+E307, U+E308, U+E309, U+E30A, U+E30B, U+E30C, U+E30D, U+E30E, U+E30F, U+E310, U+E311, U+E312, U+E313, U+E314, U+E315, U+E316, U+E317, U+E318, U+E319, U+E31C, U+E31D, U+E320, U+E321, U+E322, U+E323, U+E324, U+E325, U+E326, U+E327, U+E328, U+E329, U+E32A, U+E32B, U+E32C, U+E32D, U+E32E, U+E32F, U+E330, U+E331, U+E332, U+E333, U+E334, U+E335, U+E340, U+E341, U+E342, U+E343, U+E344, U+E345, U+E346, U+E347, U+E348, U+E349, U+E34A, U+E34B, U+E34C, U+E34D, U+E34E, U+E34F, U+E350, U+E351, U+E352, U+E353, U+E354, U+E355, U+E356, U+E357, U+E358, U+E359, U+E35A, U+E35B, U+E35C, U+E35D, U+E35E, U+E35F, U+E360, U+E361, U+E362, U+E363, U+E364, U+E365, U+E366, U+E367, U+E370, U+E371, U+E372, U+E373, U+E374, U+E375, U+E376, U+E377, U+E378, U+E379, U+E37A, U+E37B, U+E37C, U+E37D, U+E37E, U+E37F, U+E380, U+E381, U+E382, U+E383, U+E384, U+E385, U+E386, U+E387, U+E390, U+E391, U+E392, U+E393, U+E394, U+E395, U+E396, U+E397, U+E398, U+E399, U+E39A, U+E39B, U+E39C, U+E39D, U+E39E, U+E39F, U+E3A0, U+E3A1, U+E3A2, U+E3A3, U+E3A4, U+E3A5, U+E3A6, U+E3A7, U+E3A8, U+E3A9, U+E3AA, U+E3AB, U+E3AC, U+E3AD, U+E3B0, U+E3B1, U+E3B2, U+E3B3, U+E3B4, U+E3B5, U+E3B6, U+E3B7, U+E3B8, U+E3B9, U+E3BA, U+E3BB, U+E3BC, U+E3BD, U+E3BE, U+E3BF, U+E3C0, U+E3C1, U+E3C2, U+E3C3, U+E3C4, U+E3C5, U+E3C6, U+E3C7, U+E3C8, U+E3C9, U+E3CA, U+E3CB, U+E3CC, U+E3CD, U+E3CE, U+E3CF, U+E3D0, U+E3D1, U+E3D2, U+E3D3, U+E3D4, U+E3D5, U+E3D6, U+E3D7, U+E3D8, U+E3D9, U+E3DA, U+E3DB, U+E3DC, U+E3DD, U+E3DE, U+E3DF, U+E3E0, U+E3E1, U+E3E2, U+E3E3, U+E3E4, U+E3E5, U+E3E6, U+E3E7, U+E3E8, U+E3E9, U+E3EA, U+E3EB, U+E3EC, U+E3ED, U+E3EE, U+E3EF, U+E3F0, U+E3F1, U+E3F2, U+E3F3, U+E3F4, U+E3F5, U+E3F6, U+E3F7, U+E420, U+E421, U+E422, U+E423, U+E424, U+E425, U+E426, U+E427, U+E428, U+E429, U+E42A, U+E42B, U+E42C, U+E42D, U+E42E, U+E42F, U+E430, U+E431, U+E432, U+E433, U+E434, U+E435, U+E441, U+E443, U+E445, U+E450, U+E451, U+E452, U+E453, U+E454, U+E455, U+E456, U+E457, U+E460, U+E461, U+E470, U+E471, U+E472, U+E473, U+E474, U+E475, U+E476, U+E477, U+E478, U+E479, U+E47A, U+E47B, U+E47C, U+E47D, U+E47E, U+E47F, U+E480, U+E481, U+E482, U+E483, U+E484, U+E485, U+E486, U+E487, U+E488, U+E489, U+E48A, U+E48B, U+E48C, U+E48D, U+E48E, U+E48F; the browser used an arbitrary fallback font. |
| `Demo___Greensleeves.Greensleeves.Gonville` | 12.000 | Environment: Gonville has no glyph for U+E052; the browser used an arbitrary fallback font. |
| `Stave.Tempo_Test.Gonville` | 11.929 | Environment: Gonville has no glyph for U+ECA2, U+ECA3, U+ECA5, U+ECA7, U+ECA9, U+ECAB, U+ECB7; the browser used an arbitrary fallback font. |
| `ChordSymbol.Chord_Symbol_Kerning_Tests.Gonville` | 11.593 | Environment: Gonville has no glyph for U+E870, U+E871, U+E872, U+E874, U+E87C, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `Auto_Beaming.Simple_Tuplet_Auto_Beaming.Gonville` | 11.400 | Environment: Gonville has no glyph for U+E883, U+E885; the browser used an arbitrary fallback font. |
| `Tuplet.Complex_Tuplet.Gonville` | 11.400 | Environment: Gonville has no glyph for U+E883, U+E885, U+E887; the browser used an arbitrary fallback font. |
| `Tuplet.Nested_Tuplets.Gonville` | 11.400 | Environment: Gonville has no glyph for U+E883, U+E885; the browser used an arbitrary fallback font. |
| `Auto_Beaming.Duration_Based_Secondary_Beam_Breaks_2.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Auto_Beaming.Flat_Beams_Up.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Auto_Beaming.Flat_Beams_Up_Bounds.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Auto_Beaming.Flat_Beams_Up__uniform_.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Beam.TabNote_Beams_Down.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `EasyScore.Draw_Tuplets.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Formatter.Mixtime.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Rests.Auto_Align___Tuplets_Stems_Down.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Tuplet.Bottom_Tuplet.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Tuplet.Nested_Tuplets_Only_Tuplet_Children.Gonville` | 11.320 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `GlyphNote.GlyphNote_Positioning.Gonville` | 11.300 | Environment: Gonville has no glyph for U+E500, U+E501, U+E502, U+E504; the browser used an arbitrary fallback font. |
| `Tuplet.Suffixed_Tuplet.Gonville` | 11.240 | Environment: Gonville has no glyph for U+E1D5, U+E1D7, U+E882, U+E883, U+E884, U+E88A; the browser used an arbitrary fallback font. |
| `ChordSymbol.Bottom_Chord_Symbols.Gonville` | 10.337 | Environment: Gonville has no glyph for U+E874, U+E87C; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___32nd_note_rhythm_with_scratches.Gonville` | 10.042 | Environment: Gonville has no glyph for U+E100; the browser used an arbitrary fallback font. |
| `Demo___Petzold.Minuet_in_G.Gonville` | 9.529 | Environment: Gonville has no glyph for U+ECA3, U+ECB7; the browser used an arbitrary fallback font. |
| `Strokes.Arpeggio_directionless__without_arrows_.Gonville` | 9.210 | Environment: Gonville has no glyph for U+E053; the browser used an arbitrary fallback font. |
| `ChordSymbol.Bounding_Box.Gonville` | 9.050 | Environment: Gonville has no glyph for U+E5D5, U+E5D7, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `ChordSymbol.Chord_Symbol_With_Modifiers.Gonville` | 9.050 | Environment: Gonville has no glyph for U+E5D5, U+E5D7, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `Formatter.Vertical_alignment___many_mixed_elements.Gonville` | 7.660 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Beam.Auto_stemmed_tuplets_across_middle_line.Gonville` | 7.500 | Environment: Gonville has no glyph for U+E884, U+E887, U+E88A; the browser used an arbitrary fallback font. |
| `Formatter.Strict_proportional_spacing.Gonville` | 7.500 | Environment: Gonville has no glyph for U+E883, U+E884, U+E887, U+E88A; the browser used an arbitrary fallback font. |
| `ChordSymbol.Double_Bottom_Chord_Symbols.Gonville` | 7.452 | Environment: Gonville has no glyph for U+E874, U+E87C; the browser used an arbitrary fallback font. |
| `Formatter.Proportional_Formatting__20_iterations_.Gonville` | 7.340 | Environment: Gonville has no glyph for U+E883, U+E885, U+E887; the browser used an arbitrary fallback font. |
| `Formatter.Proportional_Formatting___No_Justification.Gonville` | 7.340 | Environment: Gonville has no glyph for U+E883, U+E885, U+E887; the browser used an arbitrary fallback font. |
| `Formatter.Proportional_Formatting___No_Tuning.Gonville` | 7.340 | Environment: Gonville has no glyph for U+E883, U+E885, U+E887; the browser used an arbitrary fallback font. |
| `Auto_Beaming.More_Simple_Tuplet_Auto_Beaming.Gonville` | 7.300 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Rests.Auto_Align___Single_Voice__Align_All_.Gonville` | 7.300 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Rests.Auto_Align___Single_Voice__Default_.Gonville` | 7.300 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Rests.Auto_Align___Tuplets_Stems_Up.Gonville` | 7.300 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Tuplet.Simple_Tuplet.Gonville` | 7.300 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Tuplet.Mixed_Stem_Direction_Bottom_Tuplet.Gonville` | 7.260 | Environment: Gonville has no glyph for U+E882; the browser used an arbitrary fallback font. |
| `Tuplet.Mixed_Stem_Direction_Tuplet.Gonville` | 7.260 | Environment: Gonville has no glyph for U+E882; the browser used an arbitrary fallback font. |
| `Demo___Narrow_Steps.Narrow_Steps.Gonville` | 5.721 | Environment: Gonville has no glyph for U+ECA7; the browser used an arbitrary fallback font. |
| `GlyphNote.GlyphNote_with_ChordSymbols.Gonville` | 5.363 | Environment: Gonville has no glyph for U+E504, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `ChordSymbol.Bottom_Stem_Down_Chord_Symbols.Gonville` | 3.476 | Environment: Gonville has no glyph for U+E870, U+E874; the browser used an arbitrary fallback font. |
| `ChordSymbol.Wide_Chord_Symbols.Gonville` | 2.697 | Environment: Gonville has no glyph for U+E873, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `ChordSymbol.Top_Chord_Symbols.Gonville` | 2.697 | Environment: Gonville has no glyph for U+E873, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `ChordSymbol.Top_Chord_Symbols_Justified.Gonville` | 2.697 | Environment: Gonville has no glyph for U+E873, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `MultiMeasureRest.Stave_with_modifiers_Test.Gonville` | 2.360 | Environment: Gonville has no glyph for U+E4EF, U+E4F0, U+E4F1; the browser used an arbitrary fallback font. |
| `MultiMeasureRest.Simple_Test.Gonville` | 1.640 | Environment: Gonville has no glyph for U+E4EF, U+E4F0, U+E4F1; the browser used an arbitrary fallback font. |
| `ChordSymbol.Chord_Symbol_Font_Size_Tests.Gonville` | 1.316 | Environment: Gonville has no glyph for U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `Demo___Prelude_in_C_major.Prelude_in_C_major.Gonville` | 1.010 | Environment: Gonville has no glyph for U+ECA5; the browser used an arbitrary fallback font. |
| `Articulation.Bounding_Box.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `Articulation.Fermata_Above_Below.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `Articulation.Inline_Multiple.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `Articulation.Vertical_Placement.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `Articulation.Vertical_Placement__Glyph_codes_.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `Demo___Narrow_Steps.Narrow_Steps.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `Grace_Notes.With_Articulation_and_Annotation_on_Parent_Note.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `StaveNote.Center_Aligned_Note_with_Articulation.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `Formatter.Vertical_alignment___many_mixed_elements.Bravura` | 0.360 | CoreText glyph bounds: Chromium fermata U+E4C0/U+E4C1 bounds are 0.36 px larger than the outline. |
| `Grace_Notes.Grace_Note_Slash_with_Beams.Gonville` | 0.228 | Glyph advance: 20pt grace notehead U+E0A4 is 7.865 px in Chromium and 7.8667 px in the font; the difference accumulates. |
| `Stave.Multiple_Stave_Barline_Test__14pt_Section_.Petaluma` | 0.192 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `Demo___The_Kesh_Jig.The_Kesh_Jig.Petaluma` | 0.178 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `Stave.Multiple_Stave_Barline_Test.Petaluma` | 0.178 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `Stave.Multiple_Staves_Volta_Test.Petaluma` | 0.178 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `Stave.Volta___Modifier_Measure_Test.Petaluma` | 0.178 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `NoteHead.Various_Note_Heads_1.Petaluma` | 0.142 | Glyph bounds: Chromium reports Petaluma ink bounds rounded to whole font units (0.04 px); the outline bounds differ by up to 0.142 px. |
| `StaveNote.StaveNote_Draw___Slash.Petaluma` | 0.130 | Glyph bounds: Chromium reports Petaluma ink bounds rounded to whole font units (0.04 px); the outline bounds differ by up to 0.130 px. |
| `Clef.Bounding_Box.Bravura` | 0.120 | CoreText glyph bounds: Chromium Bravura clef/time-signature bounds are 0.12 px larger than the outline. |
| `TimeSignature.Bounding_Box_Test.Bravura` | 0.120 | CoreText glyph bounds: Chromium Bravura clef/time-signature bounds are 0.12 px larger than the outline. |
| `Ornament.With_Upper_Lower_Accidentals.Gonville` | 0.112 | Glyph bounds: Gonville accidental bounds differ by 0.04 px; Ornament stacks them. |
| `Grace_Notes.Grace_Note_Slash_with_Beams.Bravura` | 0.107 | Glyph advance: 20pt grace notehead U+E0A4 is 7.865 px in Chromium and 7.8667 px in the font; the difference accumulates. |
| `Grace_Notes.Grace_Note_Slash_with_Beams.Petaluma` | 0.107 | Glyph advance: 20pt grace notehead U+E0A4 is 7.865 px in Chromium and 7.8667 px in the font; the difference accumulates. |
| `TimeSignature.Bounding_Box_Test.Petaluma` | 0.100 | Glyph bounds: Chromium reports Petaluma ink bounds rounded to whole font units (0.04 px); the outline bounds differ by up to 0.100 px. |
