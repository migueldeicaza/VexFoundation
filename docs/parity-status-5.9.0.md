# Parity status against VexFlow 5.9.0 (final gate)

This file records the opt-in SVG parity results against the upstream 5.9.0 reference SVGs (`vexflow-5.9.0/build/images/reference/svg_<Module>.<Test>.<Font>.svg`). 5.9.0 is the last upstream release, so this is the final gate. The port is described in `docs/port-notes/5.9.0.md`.

## How to run

```sh
VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_TAG=5.9.0 \
VEXFOUNDATION_UPSTREAM_SVG_DISABLE_PER_CASE_EPSILON=1 \
VEXFOUNDATION_UPSTREAM_SVG_ARTIFACTS_DIR=$PWD/.build/upstream-svg-parity/artifacts-port \
swift test --scratch-path .build-port --filter UpstreamSVGParityTests > gate.log 2>&1
tools/parity_report.py --artifacts .build/upstream-svg-parity/artifacts-port --min 0.1
```

## Results

"Before" is the 5.8.0 port (with the 5.8.0 parity cases) against the 5.9.0 references. "After" is this pass.

| | Before | After |
|---|---|---|
| Parity cases | 480 | 495 (every `svg_*` case in the 5.9.0 reference set) |
| "Missing upstream reference" issues | 0 (15 reference cases had no parity case) | 0 (0 reference cases without a parity case) |
| Row-count (`ROWS`) mismatches | 0 | 0 |
| Structure (`STRUCT`) mismatches | 8 (all Gonville) | 8 (all Gonville, the same cases) |
| Font runs at or over 0.1 px | 139 | 145 |
| Report buckets | `{'<=0.01': 318, '<=0.1': 541, '<=1': 33, '>1': 98, 'struct': 8}` | `{'<=0.01': 324, '<=0.1': 546, '<=1': 33, '>1': 104, 'struct': 8}` |

No existing case changed: the per-case maximum deltas of the 480 old cases are identical before and after. The 15 new cases add 31 font runs. 25 of these are within 0.1 px. The other 6 are all "Environment" (the font has no glyph): Petaluma German lute (59.36), Petaluma accordion (8.72), and Gonville German lute (6.00), four-shape notes (22.04), accordion (18.68) and Sabâ signature (5.40).

### New cases (from `git diff 5.8.0 5.9.0 -- tests/`)

| Case | Fonts | Max delta Bravura / Petaluma / Gonville |
|---|---|---|
| `AccordionRegister.Active_reed_ranks_follow_their_entrances` | 3 | 0 / 8.720 / 18.680 |
| `ChantPhrase.Lu_mi_na_keeps_each_neume_with_its_syllable` | Bravura | 0 |
| `Clef.Chant_clefs_and_divisions` | Bravura | 0.001 |
| `FrenchLuteNote.French_fret_letters_and_open_bass_courses` | Bravura | 0.001 |
| `GermanLuteNote.Principal_courses_on_one_staffless_row` | 3 | 0 / 59.360 / 6.000 |
| `Grace_Notes.Named_Highland_grip_and_taorluath` | 3 | 0.008 / 0.009 / 0.018 |
| `KeySignature.Edition_defined_Sab__signatures` | 3 | 0 / 0 / 5.400 |
| `KeySignature.Written_key_signs_follow_the_active_clef` | 3 | 0 / 0 / 0.020 |
| `KievanNote.Synodal_half_notes_on_lines_and_spaces` | Bravura | 0 |
| `Ornament.Moving_flute_trill_key` | 3 | 0 / 0 / 0.020 |
| `PedalMarking.Harp_pedal_changes_at_a_rest_and_entrance` | 3 | 0.009 / 0.008 / 0.020 |
| `StaveConnector.Mensurstriche_in_a_three_measure_duet` | Bravura | 0 |
| `StaveConnector.Mensurstriche_in_a_three_staff_group` | Bravura | 0 |
| `StaveNote.Movable_four_shape_major_scales` | 3 | 0 / 0.040 / 22.040 |
| `TimeSignature.White_mensural_long_values_and_signs` | Bravura | 0 |

No upstream case was renamed in 5.9.0, and no existing upstream test code changed (the upstream test diff only adds cases). The demo scores in `tests/scores/` did not change.

## Remaining mismatches over 0.1 px

Classes:

- Environment: the music font has no glyph for the code point. Chromium then uses an arbitrary system font, so the reference depends on the machine that made it (see `docs/local-deviations.md`). Not fixable. 112 font runs (100 Gonville, 12 Petaluma). All 8 `STRUCT` mismatches are in this class.
- Rounded label (`Bend.*`): `Note.plotMetrics` prints `Math.round(width)`; a 0.004 px fret-text width difference flips the printed integer. The geometry matches within 0.02 px.
- CoreText glyph bounds (Bravura): Chromium bounds are larger than the outline (fermata 0.36 px, clefs and time signatures 0.12 px).
- Fake-bold outset: Petaluma Script has no bold face; Chromium makes a synthetic bold (0.12–0.13 px).
- Glyph bounds and advances (Petaluma, grace noteheads): differences of 0.1 to 0.23 px.
- Text measurement: CoreText and node-canvas text widths differ by about 0.1 px.

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
| `GermanLuteNote.Principal_courses_on_one_staffless_row.Petaluma` | 59.360 | Environment: Petaluma has no glyph for U+EBA9, U+EC00, U+EC01, U+EC05, U+EC09; the browser used an arbitrary fallback font. |
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
| `FiguredBass.Independent_figured_bass_continuations.Gonville` | 32.840 | Environment: Gonville has no glyph for U+EA54, U+EA55, U+EA57, U+EA5B; the browser used an arbitrary fallback font. |
| `Tuplet.Awkward_Tuplet.Gonville` | 25.600 | Environment: Gonville has no glyph for U+E881, U+E882, U+E883, U+E884, U+E88A; the browser used an arbitrary fallback font. |
| `Clef.Small_Clef_End_Test.Gonville` | 24.773 | Environment: Gonville has no glyph for U+E052, U+E053, U+E064; the browser used an arbitrary fallback font. |
| `Clef.Small_Clef_Test.Gonville` | 24.769 | Environment: Gonville has no glyph for U+E052, U+E053, U+E064; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___beamed_slash_notes__some_rests.Gonville` | 24.640 | Environment: Gonville has no glyph for U+E100, U+E102; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___slash_notes.Gonville` | 24.640 | Environment: Gonville has no glyph for U+E100, U+E102, U+E103; the browser used an arbitrary fallback font. |
| `StaveNote.Movable_four_shape_major_scales.Gonville` | 22.040 | Environment: Gonville has no glyph for U+E1B1, U+E1B3, U+E1B5, U+E1B7, U+E1B9; the browser used an arbitrary fallback font. |
| `NoteHead.Drum_Chord_Heads.Gonville` | 21.640 | Environment: Gonville has no glyph for U+E0B8, U+E0B9; the browser used an arbitrary fallback font. |
| `NoteHead.Various_Heads.Gonville` | 21.640 | Environment: Gonville has no glyph for U+E0B8, U+E0B9; the browser used an arbitrary fallback font. |
| `NoteHead.Various_Note_Heads_1.Gonville` | 21.640 | Environment: Gonville has no glyph for U+E0A1, U+E0A6, U+E0B0, U+E0B1, U+E0B2, U+E0B8, U+E0B9, U+E0BA, U+E0C3, U+E0C4, U+E0C5, U+E0C7, U+E0CF, U+E0D0, U+E0D1, U+E0D2, U+E0D3, U+E0D4, U+E0D5, U+E0D6, U+E0E4, U+E0E5, U+E0E6, U+E0E7; the browser used an arbitrary fallback font. |
| `NoteHead.Various_Note_Heads_2.Gonville` | 21.640 | Environment: Gonville has no glyph for U+E0B9, U+E0C0, U+E0C2, U+E0CB, U+E0CD; the browser used an arbitrary fallback font. |
| `GlyphNote.GlyphNote_RepeatNote.Gonville` | 20.740 | Environment: Gonville has no glyph for U+E500, U+E501, U+E502, U+E504; the browser used an arbitrary fallback font. |
| `Ornament.Jazz_Ornaments.Gonville` | 20.520 | Environment: Gonville has no glyph for U+E5D0, U+E5D2, U+E5D5, U+E5D7, U+E5DE, U+E5E1, U+E5E2, U+E5E3, U+E5E4, U+E5E5, U+E5E7; the browser used an arbitrary fallback font. |
| `StaveNote.StaveNote_Draw___Harmonic_And_Muted.Gonville` | 20.440 | Environment: Gonville has no glyph for U+E0A6, U+E0D7; the browser used an arbitrary fallback font. |
| `Demo___Pocket_Change.Pocket_Change.Gonville` | 19.420 | Environment: Gonville has no glyph for U+E0F5, U+E0F6, U+E883, U+ECA5; the browser used an arbitrary fallback font. |
| `AccordionRegister.Active_reed_ranks_follow_their_entrances.Gonville` | 18.680 | Environment: Gonville has no glyph for U+E8A1, U+E8A9, U+E8AE; the browser used an arbitrary fallback font. |
| `Tuplet.Bottom_Ratioed_Tuplet.Gonville` | 17.560 | Environment: Gonville has no glyph for U+E881, U+E882, U+E883, U+E88A; the browser used an arbitrary fallback font. |
| `EasyScore.Draw_Basic_Slash.Gonville` | 16.800 | Environment: Gonville has no glyph for U+E100, U+E103; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___16th_note_rhythm_with_scratches.Gonville` | 16.688 | Environment: Gonville has no glyph for U+E100; the browser used an arbitrary fallback font. |
| `Rhythm.Rhythm_Draw___beamed_slash_notes.Gonville` | 16.688 | Environment: Gonville has no glyph for U+E100; the browser used an arbitrary fallback font. |
| `Accidental.Square_editorial_enclosures.Gonville` | 16.633 | Environment: Gonville has no glyph for U+E26C, U+E26D; the browser used an arbitrary fallback font. |
| `GlyphNote.Bounding_Box.Gonville` | 15.480 | Environment: Gonville has no glyph for U+E504, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `Style.TabNote_modifiers_Style.Petaluma` | 15.454 | Environment: Petaluma has no glyph for U+EB78; the browser used an arbitrary fallback font. |
| `StringNumber.Multi_Voice_With_Strokes__String___Finger_Numbers.Petaluma` | 15.440 | Environment: Petaluma has no glyph for U+EB78, U+EB7C; the browser used an arbitrary fallback font. |
| `StaveNote.Center_Aligned_Note_with_Multiple_Modifiers.Petaluma` | 15.438 | Environment: Petaluma has no glyph for U+EB7C; the browser used an arbitrary fallback font. |
| `Tuplet.Bounding_Box_Above.Gonville` | 15.280 | Environment: Gonville has no glyph for U+E882, U+E883, U+E88A, U+ECA5; the browser used an arbitrary fallback font. |
| `Tuplet.Bounding_Box_Below.Gonville` | 15.280 | Environment: Gonville has no glyph for U+E882, U+E883, U+E88A, U+ECA5; the browser used an arbitrary fallback font. |
| `Tuplet.Ratioed_Tuplet.Gonville` | 15.280 | Environment: Gonville has no glyph for U+E882, U+E883, U+E884, U+E88A; the browser used an arbitrary fallback font. |
| `Beam.TabNote_Beams_Up.Gonville` | 14.640 | Environment: Gonville has no glyph for U+E882, U+E883, U+E88A; the browser used an arbitrary fallback font. |
| `Tuplet.Single_Tuplets.Gonville` | 14.640 | Environment: Gonville has no glyph for U+E882, U+E883, U+E884, U+E88A; the browser used an arbitrary fallback font. |
| `Tuplet.Beamed_Tuplet.Gonville` | 14.360 | Environment: Gonville has no glyph for U+E882, U+E883, U+E887, U+E88A; the browser used an arbitrary fallback font. |
| `Tuplet.Bottom_Suffixed_Tuplet.Gonville` | 14.160 | Environment: Gonville has no glyph for U+E881, U+E882, U+E883, U+E88A, U+ECA5, U+ECA7; the browser used an arbitrary fallback font. |
| `ChordSymbol.Chord_Symbol_Kerning_Tests.Gonville` | 13.537 | Environment: Gonville has no glyph for U+E870, U+E871, U+E872, U+E874, U+E87C, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `EasyScore.Keys.Gonville` | 13.480 | Environment: Gonville has no glyph for U+E460, U+E461; the browser used an arbitrary fallback font. |
| `Accidental.Microtonal__Iranian_.Gonville` | 13.472 | Environment: Gonville has no glyph for U+E460, U+E461; the browser used an arbitrary fallback font. |
| `Ornament.Parenthesized_editorial_turn.Gonville` | 13.320 | Environment: Gonville has no glyph for U+E0F5, U+E0F6; the browser used an arbitrary fallback font. |
| `Clef.Double_octave_clefs.Gonville` | 12.955 | Environment: Gonville has no glyph for U+E051, U+E054, U+E063, U+E066; the browser used an arbitrary fallback font. |
| `Accidental.Cautionary_Accidental.Gonville` | 12.509 | Environment: Gonville has no glyph for U+E265, U+E266, U+E267, U+E268, U+E269, U+E276, U+E277, U+E278, U+E279, U+E27A, U+E27B, U+E284, U+E285, U+E290, U+E291, U+E292, U+E293, U+E294, U+E295, U+E296, U+E297, U+E298, U+E299, U+E29A, U+E29B, U+E29C, U+E2A0, U+E2A1, U+E2A2, U+E2A3, U+E2A4, U+E2A5, U+E2B0, U+E2B1, U+E2B2, U+E2B3, U+E2B4, U+E2B5, U+E2B6, U+E2B7, U+E2C0, U+E2C1, U+E2C2, U+E2C3, U+E2C4, U+E2C5, U+E2C6, U+E2C7, U+E2C8, U+E2C9, U+E2CA, U+E2CB, U+E2CC, U+E2CD, U+E2CE, U+E2CF, U+E2D0, U+E2D1, U+E2D2, U+E2D3, U+E2D4, U+E2D5, U+E2D6, U+E2D7, U+E2D8, U+E2D9, U+E2DA, U+E2DB, U+E2DC, U+E2DD, U+E2DE, U+E2DF, U+E2E0, U+E2E1, U+E2E2, U+E2E3, U+E2E4, U+E2E5, U+E2E6, U+E2E7, U+E2E8, U+E2E9, U+E2EA, U+E2EB, U+E2EC, U+E2ED, U+E2EE, U+E2EF, U+E2F0, U+E2F1, U+E2F2, U+E2F3, U+E2F4, U+E2F5, U+E2F6, U+E2F7, U+E2F8, U+E2F9, U+E2FA, U+E2FB, U+E300, U+E301, U+E302, U+E303, U+E304, U+E305, U+E306, U+E307, U+E308, U+E309, U+E30A, U+E30B, U+E30C, U+E30D, U+E30E, U+E30F, U+E310, U+E311, U+E312, U+E313, U+E314, U+E315, U+E316, U+E317, U+E318, U+E319, U+E31C, U+E31D, U+E320, U+E321, U+E322, U+E323, U+E324, U+E325, U+E326, U+E327, U+E328, U+E329, U+E32A, U+E32B, U+E32C, U+E32D, U+E32E, U+E32F, U+E330, U+E331, U+E332, U+E333, U+E334, U+E335, U+E340, U+E341, U+E342, U+E343, U+E344, U+E345, U+E346, U+E347, U+E348, U+E349, U+E34A, U+E34B, U+E34C, U+E34D, U+E34E, U+E34F, U+E350, U+E351, U+E352, U+E353, U+E354, U+E355, U+E356, U+E357, U+E358, U+E359, U+E35A, U+E35B, U+E35C, U+E35D, U+E35E, U+E35F, U+E360, U+E361, U+E362, U+E363, U+E364, U+E365, U+E366, U+E367, U+E370, U+E371, U+E372, U+E373, U+E374, U+E375, U+E376, U+E377, U+E378, U+E379, U+E37A, U+E37B, U+E37C, U+E37D, U+E37E, U+E37F, U+E380, U+E381, U+E382, U+E383, U+E384, U+E385, U+E386, U+E387, U+E390, U+E391, U+E392, U+E393, U+E394, U+E395, U+E396, U+E397, U+E398, U+E399, U+E39A, U+E39B, U+E39C, U+E39D, U+E39E, U+E39F, U+E3A0, U+E3A1, U+E3A2, U+E3A3, U+E3A4, U+E3A5, U+E3A6, U+E3A7, U+E3A8, U+E3A9, U+E3AA, U+E3AB, U+E3AC, U+E3AD, U+E3B0, U+E3B1, U+E3B2, U+E3B3, U+E3B4, U+E3B5, U+E3B6, U+E3B7, U+E3B8, U+E3B9, U+E3BA, U+E3BB, U+E3BC, U+E3BD, U+E3BE, U+E3BF, U+E3C0, U+E3C1, U+E3C2, U+E3C3, U+E3C4, U+E3C5, U+E3C6, U+E3C7, U+E3C8, U+E3C9, U+E3CA, U+E3CB, U+E3CC, U+E3CD, U+E3CE, U+E3CF, U+E3D0, U+E3D1, U+E3D2, U+E3D3, U+E3D4, U+E3D5, U+E3D6, U+E3D7, U+E3D8, U+E3D9, U+E3DA, U+E3DB, U+E3DC, U+E3DD, U+E3DE, U+E3DF, U+E3E0, U+E3E1, U+E3E2, U+E3E3, U+E3E4, U+E3E5, U+E3E6, U+E3E7, U+E3E8, U+E3E9, U+E3EA, U+E3EB, U+E3EC, U+E3ED, U+E3EE, U+E3EF, U+E3F0, U+E3F1, U+E3F2, U+E3F3, U+E3F4, U+E3F5, U+E3F6, U+E3F7, U+E420, U+E421, U+E422, U+E423, U+E424, U+E425, U+E426, U+E427, U+E428, U+E429, U+E42A, U+E42B, U+E42C, U+E42D, U+E42E, U+E42F, U+E430, U+E431, U+E432, U+E433, U+E434, U+E435, U+E441, U+E443, U+E445, U+E450, U+E451, U+E452, U+E453, U+E454, U+E455, U+E456, U+E457, U+E460, U+E461, U+E470, U+E471, U+E472, U+E473, U+E474, U+E475, U+E476, U+E477, U+E478, U+E479, U+E47A, U+E47B, U+E47C, U+E47D, U+E47E, U+E47F, U+E480, U+E481, U+E482, U+E483, U+E484, U+E485, U+E486, U+E487, U+E488, U+E489, U+E48A, U+E48B, U+E48C, U+E48D, U+E48E, U+E48F; the browser used an arbitrary fallback font. |
| `Demo___Greensleeves.Greensleeves.Gonville` | 12.002 | Environment: Gonville has no glyph for U+E052; the browser used an arbitrary fallback font. |
| `Stave.Tempo_Test.Gonville` | 11.929 | Environment: Gonville has no glyph for U+ECA2, U+ECA3, U+ECA5, U+ECA7, U+ECA9, U+ECAB, U+ECB7; the browser used an arbitrary fallback font. |
| `ChordSymbol.Bottom_Chord_Symbols.Gonville` | 11.677 | Environment: Gonville has no glyph for U+E874, U+E87C; the browser used an arbitrary fallback font. |
| `ChordSymbol.Double_Bottom_Chord_Symbols.Gonville` | 11.677 | Environment: Gonville has no glyph for U+E874, U+E87C; the browser used an arbitrary fallback font. |
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
| `Rhythm.Rhythm_Draw___32nd_note_rhythm_with_scratches.Gonville` | 10.042 | Environment: Gonville has no glyph for U+E100; the browser used an arbitrary fallback font. |
| `Strokes.Arpeggio_directionless__without_arrows_.Gonville` | 9.210 | Environment: Gonville has no glyph for U+E053; the browser used an arbitrary fallback font. |
| `ChordSymbol.Bounding_Box.Gonville` | 9.050 | Environment: Gonville has no glyph for U+E5D5, U+E5D7, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `ChordSymbol.Chord_Symbol_With_Modifiers.Gonville` | 9.050 | Environment: Gonville has no glyph for U+E5D5, U+E5D7, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `AccordionRegister.Active_reed_ranks_follow_their_entrances.Petaluma` | 8.720 | Environment: Petaluma has no glyph for U+E8A1, U+E8A9, U+E8AE; the browser used an arbitrary fallback font. |
| `Formatter.Vertical_alignment___many_mixed_elements.Gonville` | 7.660 | Environment: Gonville has no glyph for U+E883; the browser used an arbitrary fallback font. |
| `Beam.Auto_stemmed_tuplets_across_middle_line.Gonville` | 7.500 | Environment: Gonville has no glyph for U+E884, U+E887, U+E88A; the browser used an arbitrary fallback font. |
| `Formatter.Strict_proportional_spacing.Gonville` | 7.500 | Environment: Gonville has no glyph for U+E883, U+E884, U+E887, U+E88A; the browser used an arbitrary fallback font. |
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
| `GermanLuteNote.Principal_courses_on_one_staffless_row.Gonville` | 6.000 | Environment: Gonville has no glyph for U+EBA9, U+EC00, U+EC01, U+EC05, U+EC09; the browser used an arbitrary fallback font. |
| `Demo___Narrow_Steps.Narrow_Steps.Gonville` | 5.721 | Environment: Gonville has no glyph for U+ECA7; the browser used an arbitrary fallback font. |
| `KeySignature.Edition_defined_Sab__signatures.Gonville` | 5.400 | Environment: Gonville has no glyph for U+E443; the browser used an arbitrary fallback font. |
| `GlyphNote.GlyphNote_with_ChordSymbols.Gonville` | 5.363 | Environment: Gonville has no glyph for U+E504, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `ChordSymbol.Bottom_Stem_Down_Chord_Symbols.Gonville` | 4.052 | Environment: Gonville has no glyph for U+E870, U+E874; the browser used an arbitrary fallback font. |
| `ChordSymbol.Wide_Chord_Symbols.Gonville` | 3.188 | Environment: Gonville has no glyph for U+E873, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `ChordSymbol.Top_Chord_Symbols.Gonville` | 3.152 | Environment: Gonville has no glyph for U+E873, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `ChordSymbol.Top_Chord_Symbols_Justified.Gonville` | 3.152 | Environment: Gonville has no glyph for U+E873, U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `MultiMeasureRest.Stave_with_modifiers_Test.Gonville` | 2.360 | Environment: Gonville has no glyph for U+E4EF, U+E4F0, U+E4F1; the browser used an arbitrary fallback font. |
| `MultiMeasureRest.Simple_Test.Gonville` | 1.640 | Environment: Gonville has no glyph for U+E4EF, U+E4F0, U+E4F1; the browser used an arbitrary fallback font. |
| `ChordSymbol.Chord_Symbol_Font_Size_Tests.Gonville` | 1.316 | Environment: Gonville has no glyph for U+ED60, U+ED62; the browser used an arbitrary fallback font. |
| `Demo___Petzold.Minuet_in_G.Gonville` | 1.030 | Environment: Gonville has no glyph for U+ECA5 (tempo note); the browser used an arbitrary fallback font. |
| `Demo___Prelude_in_C_major.Prelude_in_C_major.Gonville` | 1.010 | Environment: Gonville has no glyph for U+ECA5; the browser used an arbitrary fallback font. |
| `Bend.Double_Bends.Bravura` | 1.000 | Rounded label: the plotted metrics width is 65.509 px here and 65.491 px in Chromium (the 11 pt fret text widths differ by 0.004 px), so `Math.round` prints 66px against 65px. All geometry is within 0.02 px. |
| `Bend.Double_Bends.Gonville` | 1.000 | Rounded label: the plotted metrics width is 65.509 px here and 65.491 px in Chromium (the 11 pt fret text widths differ by 0.004 px), so `Math.round` prints 66px against 65px. All geometry is within 0.02 px. |
| `Bend.Double_Bends_With_Release.Bravura` | 1.000 | Rounded label: the plotted metrics width is 65.509 px here and 65.491 px in Chromium (the 11 pt fret text widths differ by 0.004 px), so `Math.round` prints 66px against 65px. All geometry is within 0.02 px. |
| `Bend.Double_Bends_With_Release.Gonville` | 1.000 | Rounded label: the plotted metrics width is 65.509 px here and 65.491 px in Chromium (the 11 pt fret text widths differ by 0.004 px), so `Math.round` prints 66px against 65px. All geometry is within 0.02 px. |
| `Bend.Reverse_Bends.Bravura` | 1.000 | Rounded label: the plotted metrics width is 65.509 px here and 65.491 px in Chromium (the 11 pt fret text widths differ by 0.004 px), so `Math.round` prints 66px against 65px. All geometry is within 0.02 px. |
| `Bend.Reverse_Bends.Gonville` | 1.000 | Rounded label: the plotted metrics width is 65.509 px here and 65.491 px in Chromium (the 11 pt fret text widths differ by 0.004 px), so `Math.round` prints 66px against 65px. All geometry is within 0.02 px. |
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
| `FiguredBass.Independent_figured_bass_continuations.Petaluma` | 0.194 | Glyph bounds: Petaluma figured-bass glyph ink bounds differ from the Chromium bounds (5.8.0 case). |
| `StringNumber.TAB_fingerings_follow_selected_fret_positions.Petaluma` | 0.143 | Glyph bounds: the fret clear rectangle uses the Petaluma glyph bounds, which differ by 0.143 px (5.8.0 case). |
| `NoteHead.Various_Note_Heads_1.Petaluma` | 0.142 | Glyph bounds: Chromium reports Petaluma ink bounds rounded to whole font units (0.04 px); the outline bounds differ by up to 0.142 px. |
| `Stave.Multiple_Stave_Barline_Test__14pt_Section_.Petaluma` | 0.130 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `StaveNote.StaveNote_Draw___Slash.Petaluma` | 0.130 | Glyph bounds: Chromium reports Petaluma ink bounds rounded to whole font units (0.04 px); the outline bounds differ by up to 0.130 px. |
| `Clef.Bounding_Box.Bravura` | 0.120 | CoreText glyph bounds: Chromium Bravura clef/time-signature bounds are 0.12 px larger than the outline. |
| `Ornament.Changing_a_pitched_trill_partner.Bravura` | 0.120 | Text measurement: CoreText and node-canvas widths of the trill text differ; the cue note is placed where node-canvas places it (5.8.0 case). |
| `Ornament.Pitched_trill_partners.Bravura` | 0.120 | Text measurement: CoreText and node-canvas widths of the trill text differ; the cue note is placed where node-canvas places it (5.8.0 case). |
| `TimeSignature.Bounding_Box_Test.Bravura` | 0.120 | CoreText glyph bounds: Chromium Bravura clef/time-signature bounds are 0.12 px larger than the outline. |
| `Stave.Volta___Modifier_Measure_Test.Petaluma` | 0.120 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `Demo___The_Kesh_Jig.The_Kesh_Jig.Petaluma` | 0.119 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `Stave.Multiple_Stave_Barline_Test.Petaluma` | 0.119 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `Stave.Multiple_Staves_Volta_Test.Petaluma` | 0.119 | Fake-bold outset: bold section text in Petaluma Script (no bold face); Skia outset differs from the Swift estimate. |
| `Ornament.With_Upper_Lower_Accidentals.Gonville` | 0.112 | Glyph bounds: Gonville accidental bounds differ by 0.04 px; Ornament stacks them. |
| `Grace_Notes.Grace_Note_Slash_with_Beams.Bravura` | 0.107 | Glyph advance: 20pt grace notehead U+E0A4 is 7.865 px in Chromium and 7.8667 px in the font; the difference accumulates. |
| `Grace_Notes.Grace_Note_Slash_with_Beams.Petaluma` | 0.107 | Glyph advance: 20pt grace notehead U+E0A4 is 7.865 px in Chromium and 7.8667 px in the font; the difference accumulates. |
| `TimeSignature.Bounding_Box_Test.Petaluma` | 0.100 | Glyph bounds: Chromium reports Petaluma ink bounds rounded to whole font units (0.04 px); the outline bounds differ by up to 0.100 px. |
