# Typed Models

Typed value models reduce runtime parsing failures.

## 1. Keys via ``StaffKeySpec``

```swift
let single = StaffKeySpec(letter: .c, octave: 4)
let accidental = StaffKeySpec(letter: .g, accidental: .sharp, octave: 5)
```

Parsing variant:

```swift
let parsed = try StaffKeySpec(parsing: "g#/5")
```

## 2. Durations via ``NoteDurationSpec``

```swift
let q = NoteDurationSpec.quarter
let dotted = try NoteDurationSpec(value: .eighth, dots: 1)
let parsed = try NoteDurationSpec(parsing: "16dr")
```

## 3. Time via ``TimeSignatureSpec``

```swift
let numeric = TimeSignatureSpec.meter(5, 8)
let symbol = TimeSignatureSpec.commonTime
let parsed = TimeSignatureSpec(parsing: "7/8")
```

## 4. Required Non-Empty Collections via ``NonEmptyArray``

```swift
let keys = NonEmptyArray(
    StaffKeySpec(letter: .c, octave: 4),
    StaffKeySpec(letter: .e, octave: 4)
)
let note = StaveNoteStruct(keys: keys, duration: .quarter)
```

## 5. Boundary Conversion Example

```swift
func parseInput(keys: [String], duration: String) throws -> StaveNoteStruct {
    try StaveNoteStruct(parsingKeys: keys, duration: duration)
}
```

## Related

- <doc:TypedAPIBasics>
- ``StaveNoteStruct``
- ``TabNoteStruct``
- ``TimeSignatureSpec/meter(_:_:)``
