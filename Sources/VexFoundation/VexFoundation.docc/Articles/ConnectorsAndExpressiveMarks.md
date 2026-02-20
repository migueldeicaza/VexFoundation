# Connectors and Expressive Marks

Connectors span notes and phrases across time.

## 1. Tie with ``StaveTie``

```swift
let tieData = TieNotes(
    firstNote: first,
    lastNote: second,
    firstIndices: [0],
    lastIndices: [0]
)
_ = f.StaveTie(notes: tieData)
```

## 2. Slur/Curve with ``Curve``

```swift
_ = f.Curve(from: first, to: second)
```

## 3. Text Bracket with ``TextBracket``

```swift
_ = f.TextBracket(
    from: first,
    to: second,
    text: "8",
    superscript: "va",
    position: .top
)
```

## 4. Pedal Marking with ``PedalMarking``

```swift
_ = f.PedalMarking(notes: [first, second], type: .mixed)
```

## 5. Stave Line with ``StaveLine``

```swift
let lineNotes = StaveLineNotes(firstNote: first, lastNote: second, firstIndices: [0], lastIndices: [0])
_ = f.StaveLine(notes: lineNotes, text: "legato")
```

## 6. Preconditions

- Indices must match notehead arrays.
- Notes must be valid, attached, and formatted before drawing.

## Related

- <doc:Troubleshooting>
- ``VibratoBracket``
- ``Factory/StaveTie(notes:text:direction:)``
- ``Factory/Curve(from:to:options:)``
- ``Factory/TextBracket(from:to:text:superscript:position:line:font:)``
- ``Factory/PedalMarking(notes:type:)``
- ``Factory/StaveLine(notes:text:font:)``
