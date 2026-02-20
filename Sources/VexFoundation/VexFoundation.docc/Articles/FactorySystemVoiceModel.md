# Factory, System, and Voice Model

``Factory``, ``System``, and ``Voice`` are the primary composition units.

## 1. ``Factory`` Creates and Queues Elements

```swift
let f = Factory(options: FactoryOptions(width: 600, height: 220))
_ = f.setContext(ctx)
```

Factory constructors include ``Factory/Stave(x:y:width:options:)``, ``Factory/StaveNote(_:)``, ``Factory/Voice(timeSignature:)``, ``Factory/System(options:)``, and connector/modifier helpers.

## 2. ``Voice`` Owns Tickables and Time Validation

```swift
let voice = f.Voice(timeSignature: .meter(4, 4))
_ = voice.addTickables(notes)
```

Use ``Voice/setMode(_:)`` to switch strictness.

## 3. ``System`` Lays Out Staves Together

```swift
let system = f.System(options: SystemOptions(factory: f, x: 10, width: 560, y: 10))
_ = system.addStave(SystemStave(voices: [voice]))
    .addClef(.treble)
    .addTimeSignature(.meter(4, 4))
```

## 4. Format Then Draw

```swift
system.format()
try? f.draw()
```

## 5. Option Tuning

``SystemOptions`` can tune spacing and justification, including `autoWidth`, `spaceBetweenStaves`, and `noPadding`.

## Related

- ``SystemOptions``
- ``SystemStave``
- ``Voice/setMode(_:)``
- ``Voice/addTickables(_:)``
- ``System/addStave(_:)``
- ``Factory/draw()``
- <doc:ErrorHandlingAndPreconditions>
