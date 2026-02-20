# Advanced Notation

Compose richer notation by layering formatting, modifiers, and connectors.

## 1. Beams with ``Beam``

```swift
let run = score.notes("C5/8, D5, E5, F5")
_ = score.beam(run)
```

## 2. Tuplets with ``Tuplet``

```swift
let triplet = score.notes("G5/8, A5/8, B5/8")
_ = score.tuplet(triplet)
```

## 3. Note Modifiers

```swift
let note = f.StaveNote(StaveNoteStruct(
    keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 5)),
    duration: .quarter
))
_ = note.addModifier(f.Accidental(type: .sharp), index: 0)
_ = note.addModifier(f.Articulation(type: "a>"), index: 0)
```

## 4. Connectors

```swift
let tie = TieNotes(
    firstNote: first,
    lastNote: second,
    firstIndices: [0],
    lastIndices: [0]
)
_ = f.StaveTie(notes: tie)
_ = f.Curve(from: first, to: second)
```

## 5. Stave-Level Marks

```swift
_ = system.addStave(SystemStave(voices: [voice]))
    .addClef(.treble)
    .addKeySignature("D")
    .addTimeSignature(.meter(4, 4))
```

## 6. Finalize Format and Draw

```swift
system.format()
try? f.draw()
```

## Key Symbols

- ``Factory/Accidental(type:)``
- ``Factory/Articulation(type:)``
- ``Factory/StaveTie(notes:text:direction:)``
- ``Factory/Curve(from:to:options:)``
- ``System/format()``
- ``Factory/draw()``

## Related

- <doc:StavesAndModifiers>
- <doc:ConnectorsAndExpressiveMarks>
