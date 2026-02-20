# Theory Utilities

Use theory helpers to preprocess notation input.

## 1. Note and Key Parsing with ``Music``

```swift
let music = Music()
let noteParts = music.getNoteParts("F#")
let keyParts = music.getKeyParts("Dm")
```

## 2. Key-Aware Accidental Selection with ``KeyManager``

```swift
let manager = KeyManager("G")
let result = manager.selectNote("f")
// result.note, result.accidental, result.change
```

## 3. Scale/Interval Logic in App Layer

```swift
let rootValue = music.getNoteValue("c")
let majorScale = music.getScaleTones(rootValue, intervals: Music.scales["major"]!)
```

## 4. Convert to Typed Engraving Models

```swift
let typed = StaffKeySpec(letter: .f, accidental: .sharp, octave: 4)
let duration = NoteDurationSpec.quarter
let note = StaveNoteStruct(keys: NonEmptyArray(typed), duration: duration)
```

## Related

- <doc:TypedModels>
- <doc:VexFlowParityAndMigration>
- ``Music/getNoteParts(_:)``
- ``Music/getKeyParts(_:)``
- ``KeyManager/selectNote(_:)``
