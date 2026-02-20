# Troubleshooting

Quick diagnostics for common issues.

## 1. Nothing Renders

Check:

1. ``Factory/setContext(_:)`` was called.
2. ``FontLoader/loadDefaultFonts()`` was called.
3. ``System/format()`` ran before draw.
4. ``VexCanvas`` frame is non-zero.

Minimal verification snippet:

```swift
VexCanvas(width: 240, height: 80) { ctx in
    ctx.clear()
    FontLoader.loadDefaultFonts()
    let f = Factory()
    _ = f.setContext(ctx)
}
```

## 2. Crash on Draw

Frequent causes:

- No context on factory.
- Invalid tick totals in ``Voice``.
- Invalid connector indices.
- Missing format pass.

## 3. Parse Failures

Use parse-first checks:

```swift
if let parsed = StaveNoteStruct(parsingKeysOrNil: ["c#/4"], duration: "8") {
    // proceed
} else {
    // show user error
}
```

## 4. Voice Duration Mismatch

If strict mode fails, either fix durations or relax mode for partial phrases:

```swift
_ = voice.setMode(.soft)
```

## 5. Connector Not Visible

Check that both notes exist, indices are valid, and the line is formatted before draw.

## Related

- <doc:ErrorHandlingAndPreconditions>
- <doc:ConnectorsAndExpressiveMarks>
- ``Factory/draw()``
- ``Voice/setMode(_:)``
