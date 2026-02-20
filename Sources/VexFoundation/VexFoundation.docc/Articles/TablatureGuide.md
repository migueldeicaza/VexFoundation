# Tablature Guide

Use tablature APIs for fretted instrument notation.

## 1. Create a ``TabStave``

```swift
let tabStave = f.TabStave(x: 10, y: 80, width: 480)
_ = tabStave.setContext(ctx)
```

## 2. Build ``TabNoteStruct`` Inputs

```swift
let noteData = TabNoteStruct(
    positions: [TabNotePosition(str: 3, fret: 7)],
    duration: .quarter
)
let tabNote = f.TabNote(noteData)
```

## 3. Multi-String Tab Chords

```swift
let chordData = TabNoteStruct(
    positions: [
        TabNotePosition(str: 4, fret: 9),
        TabNotePosition(str: 3, fret: 9),
        TabNotePosition(str: 2, fret: 10)
    ],
    duration: .eighth
)
let tabChord = f.TabNote(chordData)
```

## 4. Parse Duration at Boundary

```swift
let parsed = try TabNoteStruct(
    positions: [TabNotePosition(str: 2, fret: "X")],
    duration: "8r"
)
```

## 5. Tuning Helper

```swift
let tuning = Tuning("standard")
let pitch = tuning.getValueForFret(3, stringNum: 1)
```

## Related

- ``TabSlide``
- ``GraceTabNote``
- ``Factory/TabStave(x:y:width:options:)``
- ``Factory/TabNote(_:)``
- ``Tuning/getValueForFret(_:stringNum:)``
- <doc:ErrorHandlingAndPreconditions>
