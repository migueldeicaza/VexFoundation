// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/metrics.ts`. The defaults tree lives in the active
// `VexRuntimeContext`, so independent contexts can change fonts and sizes
// without affecting each other. Updated to VexFlow 5.1.0 (separate text-font
// defaults: `textFontFamily` and `isText`).

import Foundation

/// Mutable metrics tree plus lookup caches. One instance per runtime context.
public final class MetricsStore {
    private let lock = NSRecursiveLock()
    private var tree: [String: Any]
    private var cacheFont: [String: FontInfo] = [:]
    private var cacheStyle: [String: ElementStyle] = [:]

    public init(defaults: [String: Any] = Metrics.defaults) {
        self.tree = defaults
    }

    /// Return the full tree (a copy).
    public var values: [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return tree
    }

    /// Clear cached lookups for `key`, or all cached lookups.
    public func clear(_ key: String? = nil) {
        lock.lock(); defer { lock.unlock() }
        if let key {
            cacheFont.removeValue(forKey: key)
            cacheStyle.removeValue(forKey: key)
        } else {
            cacheFont.removeAll()
            cacheStyle.removeAll()
        }
    }

    /// Set a value at a dotted key path (e.g. `"ChordSymbol.fontSize"`) and clear caches.
    public func set(_ key: String, _ value: Any?) {
        lock.lock(); defer { lock.unlock() }
        let parts = key.split(separator: ".").map(String.init)
        tree = Self.setting(tree, parts[...], value)
        cacheFont.removeAll()
        cacheStyle.removeAll()
    }

    private static func setting(_ node: [String: Any], _ path: ArraySlice<String>, _ value: Any?) -> [String: Any] {
        var node = node
        guard let first = path.first else { return node }
        if path.count == 1 {
            node[first] = value
        } else {
            let child = node[first] as? [String: Any] ?? [:]
            node[first] = setting(child, path.dropFirst(), value)
        }
        return node
    }

    /// Look up a value. For `Stroke.text.fontFamily`, check in order:
    /// `fontFamily`, `Stroke.fontFamily`, `Stroke.text.fontFamily`, and return
    /// the most specific value found.
    public func get(_ key: String, _ defaultValue: Any? = nil) -> Any? {
        lock.lock(); defer { lock.unlock() }
        var keyParts = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let lastKeyPart = keyParts.removeLast()
        var curr: [String: Any]? = tree
        var retVal = defaultValue
        while let node = curr {
            if let v = node[lastKeyPart], !(v is [String: Any]) {
                retVal = v
            }
            if keyParts.isEmpty { break }
            let part = keyParts.removeFirst()
            curr = node[part] as? [String: Any]
        }
        return retVal
    }

    public func getFontInfo(_ key: String) -> FontInfo {
        lock.lock(); defer { lock.unlock() }
        if let cached = cacheFont[key] { return cached }
        let size = Metrics.number(get("\(key).fontSize")) ?? 30
        let scale = Metrics.number(get("\(key).fontScale")) ?? 1
        let info = FontInfo(
            family: fontFamily(key),
            size: "\(formatJSNumber(size * scale))pt",
            weight: Metrics.string(get("\(key).fontWeight")) ?? "normal",
            style: get("\(key).fontStyle") as? String ?? "normal"
        )
        cacheFont[key] = info
        return info
    }

    /// Keep text spaces in the text font while honoring class-specific font overrides.
    /// Port of `Metrics.getFontFamily()` (VexFlow 5.1.0).
    private func fontFamily(_ key: String) -> String {
        guard get("\(key).isText", false) as? Bool == true else {
            return get("\(key).fontFamily") as? String ?? "Bravura,Academico"
        }
        var family = tree["textFontFamily"] as? String ?? "Academico,Bravura"
        var node: [String: Any]? = tree
        for part in key.split(separator: ".", omittingEmptySubsequences: false).map(String.init) {
            node = node?[part] as? [String: Any]
            guard let current = node else { break }
            family = current["fontFamily"] as? String ?? family
        }
        return family
    }

    public func getStyle(_ key: String) -> ElementStyle {
        lock.lock(); defer { lock.unlock() }
        if let cached = cacheStyle[key] { return cached }
        let style = ElementStyle(
            shadowColor: get("\(key).shadowColor") as? String,
            shadowBlur: Metrics.number(get("\(key).shadowBlur")),
            fillStyle: get("\(key).fillStyle") as? String,
            strokeStyle: get("\(key).strokeStyle") as? String,
            lineWidth: Metrics.number(get("\(key).lineWidth")),
            lineDash: get("\(key).lineDash") as? String
        )
        cacheStyle[key] = style
        return style
    }
}

/// Static facade over the metrics of the active runtime context.
public enum Metrics {
    static var store: MetricsStore { VexRuntime.getCurrentContext().metrics }

    /// Clear cached lookups for `key`, or all of them.
    public static func clear(_ key: String? = nil) { store.clear(key) }

    /// Look up a value by dotted key (see `MetricsStore.get`).
    public static func get(_ key: String, _ defaultValue: Any? = nil) -> Any? { store.get(key, defaultValue) }

    /// Look up a numeric value.
    public static func getDouble(_ key: String, _ defaultValue: Double = 0) -> Double {
        number(store.get(key)) ?? defaultValue
    }

    /// Look up a numeric value, or `nil` if missing.
    public static func getOptionalDouble(_ key: String) -> Double? {
        number(store.get(key))
    }

    /// Look up a string value.
    public static func getString(_ key: String, _ defaultValue: String = "") -> String {
        string(store.get(key)) ?? defaultValue
    }

    /// Look up a Boolean value.
    public static func getBool(_ key: String, _ defaultValue: Bool = false) -> Bool {
        store.get(key) as? Bool ?? defaultValue
    }

    public static func getFontInfo(_ key: String) -> FontInfo { store.getFontInfo(key) }
    public static func getStyle(_ key: String) -> ElementStyle { store.getStyle(key) }

    /// Set a value at a dotted key path in the active context.
    public static func set(_ key: String, _ value: Any?) { store.set(key, value) }

    static func number(_ v: Any?) -> Double? {
        switch v {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let f as Float: return Double(f)
        case let s as String: return Double(s)
        default: return nil
        }
    }

    static func string(_ v: Any?) -> String? {
        switch v {
        case let s as String: return s
        case let d as Double: return formatJSNumber(d)
        case let i as Int: return String(i)
        default: return nil
        }
    }

    /// Default metrics (VexFlow `MetricsDefaults`).
    public static var defaults: [String: Any] { [
        "pointerRect": false,
        "fontFamily": "Bravura,Academico",
        "textFontFamily": "Academico,Bravura",
        "fontSize": 30.0,
        "fontScale": 1.0,
        "fontWeight": "normal",
        "fontStyle": "normal",

        "Accidental": [
            "cautionary": ["fontSize": 20.0],
            "grace": ["fontSize": 20.0],
            "noteheadAccidentalPadding": 1.0,
            "leftPadding": 2.0,
            "accidentalSpacing": 3.0,
        ] as [String: Any],

        "Annotation": ["isText": true, "fontSize": 10.0] as [String: Any],

        "Bend": [
            "isText": true,
            "fontSize": 10.0,
            "line": ["strokeStyle": "#777777", "lineWidth": 1.0] as [String: Any],
        ] as [String: Any],

        "ChordSymbol": [
            "isText": true,
            "fontSize": 12.0,
            "spacing": 0.05,
            "subscriptOffset": 0.2,
            "superscriptOffset": -0.4,
            "superSubRatio": 0.6,
        ],

        "FretHandFinger": ["isText": true, "fontSize": 9.0, "fontWeight": "bold"] as [String: Any],

        "GraceNote": ["fontScale": 2.0 / 3.0],

        "GraceTabNote": ["fontScale": 2.0 / 3.0],

        "NoteHead": ["minPadding": 2.0],

        "PedalMarking": [
            "text": ["isText": true, "fontSize": 12.0, "fontStyle": "italic"] as [String: Any],
        ],

        "Repetition": [
            "text": [
                "isText": true,
                "fontSize": 12.0,
                "fontWeight": "bold",
                "offsetX": 12.0,
                "offsetY": 25.0,
                "spacing": 5.0,
            ] as [String: Any],
            "coda": ["offsetY": 25.0],
            "segno": ["offsetY": 10.0],
        ],

        "Stave": [
            "isText": true,
            "strokeStyle": "#999999",
            "fontSize": 8.0,
            "padding": 12.0,
            "endPaddingMax": 10.0,
            "endPaddingMin": 5.0,
            "unalignedNotePadding": 10.0,
        ] as [String: Any],

        "StaveConnector": ["text": ["isText": true, "fontSize": 16.0] as [String: Any]],

        "StaveLine": ["isText": true, "fontSize": 10.0] as [String: Any],

        "StaveNote": ["pointerRect": true],

        "StaveSection": [
            "isText": true,
            "fontSize": 10.0,
            "fontWeight": "bold",
            "lineWidth": 2.0,
            "padding": 2.0,
            "strokeStyle": "black",
        ] as [String: Any],

        "StaveTempo": [
            "isText": true,
            "fontSize": 14.0,
            "glyph": ["isText": false, "fontSize": 25.0] as [String: Any],
            "name": ["fontWeight": "bold"],
        ] as [String: Any],

        "StaveText": ["isText": true, "fontSize": 16.0] as [String: Any],

        "StaveTie": ["isText": true, "fontSize": 10.0] as [String: Any],

        "Stem": ["strokeStyle": "black"],

        "StringNumber": [
            "isText": true,
            "fontSize": 10.0,
            "fontWeight": "bold",
            "verticalPadding": 8.0,
            "stemPadding": 2.0,
            "leftPadding": 5.0,
            "rightPadding": 6.0,
        ] as [String: Any],

        "Stroke": [
            "text": ["isText": true, "fontSize": 10.0, "fontStyle": "italic", "fontWeight": "bold"] as [String: Any],
        ],

        "TabNote": ["text": ["isText": true, "fontSize": 9.0] as [String: Any]],

        "TabSlide": ["isText": true, "fontSize": 10.0, "fontStyle": "italic", "fontWeight": "bold"] as [String: Any],

        "TabStave": ["isText": true, "strokeStyle": "#999999", "fontSize": 8.0] as [String: Any],

        "TabTie": ["isText": true, "fontSize": 10.0] as [String: Any],

        "TextBracket": ["isText": true, "fontSize": 15.0, "fontStyle": "italic"] as [String: Any],

        "TextNote": ["text": ["isText": true, "fontSize": 12.0] as [String: Any]],

        "Tremolo": ["spacing": 7.0],

        "Tuplet": [
            "pointerRect": true,
            "yOffset": 0.0,
            "textYOffset": 2.0,
            "bracket": ["padding": 5.0, "lineWidth": 1.0, "legLength": 10.0],
            "suffix": ["fontScale": 1.0 / 2.0, "extraSpacing": 1.0, "suffixOffsetY": -3.0],
        ] as [String: Any],

        "Volta": ["isText": true, "fontSize": 9.0, "fontWeight": "bold"] as [String: Any],
    ] }
}
