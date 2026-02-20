# Staves and Modifiers

Configure stave-level notation and note-level decoration.

## 1. Build a Stave with Modifiers

```swift
let stave = system.addStave(SystemStave(voices: [voice]))
    .addClef(.treble)
    .addKeySignature("D")
    .addTimeSignature(.meter(4, 4))
```

Key symbols:

- ``Stave``
- ``StaveModifier``
- ``Clef``
- ``KeySignature``
- ``TimeSignature``

## 2. End Modifiers

```swift
_ = stave.addEndClef(.bass)
_ = stave.setEndTimeSignature(.meter(2, 4))
```

## 3. Apply Note Modifiers

```swift
let note = f.StaveNote(StaveNoteStruct(
    keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 5)),
    duration: .quarter
))
_ = note.addModifier(f.Accidental(type: "#"), index: 0)
_ = note.addModifier(f.Ornament(type: "tr")!, index: 0)
```

## 4. Other Modifier Families

- ``Articulation``
- ``GraceNoteGroup``
- ``FretHandFinger``
- ``StringNumber``
- ``ChordSymbol``

## 5. Sequencing Tip

Add modifiers before final ``System/format()`` so spacing and collisions are resolved in one layout pass.

## Related

- <doc:AdvancedNotation>
- <doc:ConnectorsAndExpressiveMarks>
- ``Stave/addClef(_:size:annotation:position:)``
- ``Stave/addKeySignature(_:cancelKeySpec:position:)``
- ``Stave/addTimeSignature(_:customPadding:position:)``
- ``Stave/addEndClef(_:size:annotation:)``
- ``Stave/setEndTimeSignature(_:customPadding:)``
