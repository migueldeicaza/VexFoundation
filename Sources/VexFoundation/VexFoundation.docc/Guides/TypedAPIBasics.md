# Typed API Basics

Use typed values for internal code and parse text at input boundaries.

## 1. Typed Keys with ``StaffKeySpec``

```swift
let c4 = StaffKeySpec(letter: .c, octave: 4)
let fSharp5 = StaffKeySpec(letter: .f, accidental: .sharp, octave: 5)
```

Boundary parse:

```swift
let parsed = try StaffKeySpec(parsing: "f#/5")
```

## 2. Typed Durations with ``NoteDurationSpec``

```swift
let quarter = NoteDurationSpec.quarter
let dottedEighth = try NoteDurationSpec(value: .eighth, dots: 1)
let parsed = try NoteDurationSpec(parsing: "16dr")
```

## 3. Typed Time with ``TimeSignatureSpec``

```swift
let common = TimeSignatureSpec.commonTime
let cut = TimeSignatureSpec.cutTime
let sevenEight = TimeSignatureSpec.meter(7, 8)
```

## 4. Non-Empty Keys with ``NonEmptyArray``

```swift
let chordKeys = NonEmptyArray(
    StaffKeySpec(letter: .c, octave: 4),
    StaffKeySpec(letter: .e, octave: 4),
    StaffKeySpec(letter: .g, octave: 4)
)

let chord = StaveNoteStruct(keys: chordKeys, duration: .quarter)
```

## 5. Boundary Parsing into Typed Models

Use throwing/failable constructors when input is text.

```swift
let maybe = StaveNoteStruct(
    parsingKeysOrNil: ["c/4", "e/4", "g/4"],
    duration: "8d"
)
```

## Recommended Rule

- Parsing layer: text -> typed.
- Rendering layer: typed only.

## Key Symbols

- ``StaffKeySpec``
- ``NoteDurationSpec``
- ``TimeSignatureSpec``
- ``TimeSignatureSpec/meter(_:_:)``
- ``NonEmptyArray``
- ``StaveNoteStruct``

## Next

- <doc:TypedModels>
- <doc:ErrorHandlingAndPreconditions>
