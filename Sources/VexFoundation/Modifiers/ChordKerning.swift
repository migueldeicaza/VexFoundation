// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/chordkerning.ts` (VexFlow 5.2.0).
// Opt-in chord typography: explicit font profiles and backend-independent run placement.

import Foundation

/// Script position relative to the parent chord's baseline.
public enum ChordSymbolPosition: String, Sendable {
    case baseline
    case superscript
    case `subscript`
}

/// A boundary adjustment in parent-font em units. Characters are literal Unicode values.
public struct ChordSymbolKerningPair: Sendable, Equatable {
    public var left: String
    public var right: String
    public var position: ChordSymbolPosition
    public var adjustmentEm: Double

    public init(left: String, right: String, position: ChordSymbolPosition, adjustmentEm: Double) {
        self.left = left
        self.right = right
        self.position = position
        self.adjustmentEm = adjustmentEm
    }
}

/// Exact faces and style for a calibrated pair table. Custom profiles are per chord.
public struct ChordSymbolKerningProfile: Sendable, Equatable {
    public var textFont: String
    public var musicFont: String
    public var weight: String?
    public var style: String?
    public var pairs: [ChordSymbolKerningPair]

    public init(
        textFont: String, musicFont: String, weight: String? = nil, style: String? = nil,
        pairs: [ChordSymbolKerningPair]
    ) {
        self.textFont = textFont
        self.musicFont = musicFont
        self.weight = weight
        self.style = style
        self.pairs = pairs
    }
}

/// Text stays together until a music glyph or script boundary changes the font run.
public struct ChordSymbolText: Sendable, Equatable {
    public var text: String
    public var position: ChordSymbolPosition

    public init(text: String, position: ChordSymbolPosition) {
        self.text = text
        self.position = position
    }
}

/// A measured run, in unscaled score coordinates, shared by all render back ends.
public struct ChordSymbolRun: Sendable, Equatable {
    public var text: String
    public var position: ChordSymbolPosition
    public var font: FontInfo
    public var x: Double
    public var y: Double
    public var metrics: TextMetrics
}

/// Layout constants passed to `layoutChordRuns`.
public struct ChordSymbolRunOptions: Sendable {
    public var spacing: Double
    public var ratio: Double
    public var superscript: Double
    public var `subscript`: Double

    public init(spacing: Double, ratio: Double, superscript: Double, subscript: Double) {
        self.spacing = spacing
        self.ratio = ratio
        self.superscript = superscript
        self.subscript = `subscript`
    }
}

/// Conservative optical corrections for the bundled regular faces; unspecified pairs use zero.
private func scriptPairs(_ a: Double, _ f: Double) -> [ChordSymbolKerningPair] {
    let symbols = [Glyphs.csymDiminished, Glyphs.csymHalfDiminished, Glyphs.csymMajorSeventh]
    return symbols.flatMap { right in
        [
            ChordSymbolKerningPair(left: "A", right: right, position: .superscript, adjustmentEm: a),
            ChordSymbolKerningPair(left: "F", right: right, position: .subscript, adjustmentEm: f),
        ]
    }
}

/// Font-specific values are deliberately small; the ordinary text remains natively shaped.
private let builtInChordKerningProfiles: [ChordSymbolKerningProfile] = [
    ChordSymbolKerningProfile(textFont: "Academico", musicFont: "Bravura", pairs: scriptPairs(-0.18, -0.12)),
    ChordSymbolKerningProfile(textFont: "Petaluma Script", musicFont: "Petaluma", pairs: scriptPairs(-0.12, -0.08)),
]

/// Normalize only the supported CSS spellings; an unknown weight or face never borrows a profile.
private func normalWeight(_ weight: String?) -> String {
    guard let weight, !weight.isEmpty, weight != "normal" else { return "400" }
    return weight
}

/// Match explicit leading faces, not a guess about which fallback face supplied a glyph.
public func chordKerningProfile(
    _ font: FontInfo,
    custom: ChordSymbolKerningProfile? = nil
) -> ChordSymbolKerningProfile? {
    let families = font.family.components(separatedBy: ",").map { family -> String in
        var name = family.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = name.first, first == "'" || first == "\"" { name.removeFirst() }
        if let last = name.last, last == "'" || last == "\"" { name.removeLast() }
        return name
    }
    let candidates = custom.map { [$0] } ?? builtInChordKerningProfiles
    let fontStyle = font.style.isEmpty ? "normal" : font.style
    return candidates.first { profile in
        families.count > 1
            && families[0] == profile.textFont
            && families[1] == profile.musicFont
            && normalWeight(font.weight) == normalWeight(profile.weight)
            && fontStyle == (profile.style.flatMap { $0.isEmpty ? nil : $0 } ?? "normal")
    }
}

/// Restrict splitting to chord symbols and accidentals. Leave other text and combining marks intact.
private func musicCharacter(_ character: Character) -> Bool {
    character.unicodeScalars.contains { scalar in
        (0xE870...0xE87F).contains(scalar.value)
            || (0xED60...0xED67).contains(scalar.value)
            || (0xE260...0xE26F).contains(scalar.value)
    }
}

/// Merge adjacent fragments at the same baseline before splitting into text/music font runs.
private func groups(_ blocks: [ChordSymbolText]) -> [ChordSymbolText] {
    var result: [ChordSymbolText] = []
    for block in blocks where !block.text.isEmpty {
        if let last = result.last, last.position == block.position {
            result[result.count - 1].text += block.text
        } else {
            result.append(block)
        }
    }
    return result
}

/// Split only at font-role boundaries, so words and digit sequences retain native shaping.
private func spans(_ text: String) -> [(text: String, music: Bool)] {
    var result: [(text: String, music: Bool)] = []
    for character in text {
        let music = musicCharacter(character)
        if let last = result.last, last.music == music {
            result[result.count - 1].text.append(character)
        } else {
            result.append((String(character), music))
        }
    }
    return result
}

/// Pair values move the following run and its advance together, never just the painted glyph.
private func adjustment(
    _ profile: ChordSymbolKerningProfile, _ left: String, _ right: String, _ position: ChordSymbolPosition
) -> Double {
    guard let last = left.last.map(String.init), let first = right.first.map(String.init) else { return 0 }
    return profile.pairs.first { $0.left == last && $0.right == first && $0.position == position }?.adjustmentEm ?? 0
}

/// Rebuild positions on every format pass. No accumulated shifts or separate SVG-only corrections.
public func layoutChordRuns(
    _ blocks: [ChordSymbolText],
    font: FontInfo,
    profile: ChordSymbolKerningProfile,
    options: ChordSymbolRunOptions,
    measure: (String, FontInfo) -> TextMetrics
) -> (runs: [ChordSymbolRun], width: Double) {
    let em = VexFont.convertSizeToPixelValue(font.size)
    var runs: [ChordSymbolRun] = []
    var cursor: Double = 0
    var previousText = ""
    var stack: (position: ChordSymbolPosition, x: Double, end: Double)?
    for group in groups(blocks) {
        let script = group.position != .baseline
        let stacked = script && stack != nil && stack?.position != group.position
        var x = stacked ? (stack?.x ?? cursor) : cursor
        if !stacked && !runs.isEmpty {
            x += options.spacing * em + adjustment(profile, previousText, group.text, group.position) * em
        }
        let anchor = x
        let y: Double
        switch group.position {
        case .superscript: y = options.superscript * em
        case .subscript: y = options.subscript * em
        case .baseline: y = 0
        }
        var previousSpan = ""
        for span in spans(group.text) {
            if !previousSpan.isEmpty { x += adjustment(profile, previousSpan, span.text, group.position) * em }
            var runFont = font
            runFont.family = span.music ? profile.musicFont : profile.textFont
            runFont.size = script ? VexFont.scaleSize(font.size, options.ratio) : font.size
            let metrics = measure(span.text, runFont)
            runs.append(ChordSymbolRun(
                text: span.text, position: group.position, font: runFont, x: x, y: y, metrics: metrics
            ))
            x += metrics.width
            previousSpan = span.text
        }
        cursor = stacked ? max(stack?.end ?? x, x) : x
        stack = script && !stacked ? (group.position, anchor, cursor) : nil
        previousText = group.text
    }
    // Include ink overhangs without discarding advances (including intentional spaces).
    let left = min(0, runs.map { $0.x - $0.metrics.actualBoundingBoxLeft }.min() ?? 0)
    let right = max(cursor, runs.map { $0.x + $0.metrics.actualBoundingBoxRight }.max() ?? cursor)
    for i in runs.indices { runs[i].x -= left }
    return (runs, right - left)
}
