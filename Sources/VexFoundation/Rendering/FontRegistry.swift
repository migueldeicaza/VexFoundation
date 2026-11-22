// VexFoundation - Font file registry (replaces VexFlow 5 `Font.load` / FontFace).
//
// VexFlow 5 draws music glyphs as text in SMuFL fonts. This registry maps CSS
// family names (e.g. "Bravura", "Academico", "Petaluma Script") to font data
// and creates `CTFont` instances for measurement and drawing. Bundled fonts
// are registered lazily. Fonts are not registered process-wide.

import CoreText
import Foundation

public enum FontRegistryError: Error, LocalizedError, Equatable, Sendable {
    case invalidFontData(String)
    case resourceNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFontData(let name): return "Invalid font data for '\(name)'."
        case .resourceNotFound(let name): return "Bundled font resource '\(name)' not found."
        }
    }
}

/// Registry of font faces available to VexFoundation.
public final class FontRegistry: @unchecked Sendable {
    public static let shared = FontRegistry()

    private struct FaceKey: Hashable {
        let family: String
        let bold: Bool
        let italic: Bool
    }

    private struct FontKey: Hashable {
        let family: String
        let bold: Bool
        let italic: Bool
        let size: Double
    }

    private let lock = NSRecursiveLock()
    private var faces: [FaceKey: CTFontDescriptor] = [:]
    private var fontCache: [FontKey: CTFont?] = [:]
    private var bundledLoaded = false
    private var generation = 0

    /// Bundled fonts: family name -> [(resource, bold, italic)].
    public static let bundledFonts: [(family: String, resource: String, bold: Bool, italic: Bool)] = [
        ("Bravura", "bravura", false, false),
        ("Academico", "academico", false, false),
        ("Academico", "academico-bold", true, false),
        ("Gonville", "gonville", false, false),
        ("Petaluma", "petaluma", false, false),
        ("Petaluma Script", "petalumascript", false, false),
        ("Leland", "leland", false, false),
        ("Edwin", "edwin-roman", false, false),
        ("Edwin", "edwin-bold", true, false),
        ("Edwin", "edwin-italic", false, true),
        ("Edwin", "edwin-bold-italic", true, true),
    ]

    /// CSS generic families mapped to the faces Chromium uses on macOS.
    static let genericFamilies: [String: String] = [
        "serif": "Times",
        "sans-serif": "Helvetica",
        "monospace": "Courier",
        "cursive": "Apple Chancery",
        "fantasy": "Papyrus",
        "system-ui": ".AppleSystemUIFont",
    ]

    public init() {}

    /// A counter that changes when fonts are added. Caches key on it.
    public var currentGeneration: Int {
        lock.lock(); defer { lock.unlock() }
        return generation
    }

    /// Register font data under a CSS family name.
    public func register(family: String, data: Data, weight: String = "normal", style: String = "normal") throws {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor],
              let descriptor = descriptors.first
        else {
            throw FontRegistryError.invalidFontData(family)
        }
        lock.lock(); defer { lock.unlock() }
        let key = FaceKey(family: Self.normalize(family), bold: VexFont.isBold(weight), italic: VexFont.isItalic(style))
        faces[key] = descriptor
        fontCache.removeAll()
        generation += 1
    }

    /// Register a font file at `url` under a CSS family name.
    public func register(family: String, url: URL, weight: String = "normal", style: String = "normal") throws {
        try register(family: family, data: Data(contentsOf: url), weight: weight, style: style)
    }

    /// True if `family` has a registered face (bundled fonts included).
    public func hasFamily(_ family: String) -> Bool {
        loadBundledFontsIfNeeded()
        lock.lock(); defer { lock.unlock() }
        let f = Self.normalize(family)
        return faces.keys.contains { $0.family == f }
    }

    /// Load the fonts bundled in the package resources.
    public func loadBundledFontsIfNeeded() {
        lock.lock()
        if bundledLoaded { lock.unlock(); return }
        bundledLoaded = true
        lock.unlock()
        for entry in Self.bundledFonts {
            guard let url = Bundle.module.url(forResource: entry.resource, withExtension: "otf", subdirectory: "fonts")
                ?? Bundle.module.url(forResource: entry.resource, withExtension: "otf")
            else { continue }
            try? register(
                family: entry.family,
                url: url,
                weight: entry.bold ? "bold" : "normal",
                style: entry.italic ? "italic" : "normal"
            )
        }
    }

    /// Return a `CTFont` for one CSS family at `sizePx` pixels, or `nil` if the
    /// family is not available.
    public func font(family rawFamily: String, sizePx: Double, bold: Bool, italic: Bool) -> CTFont? {
        loadBundledFontsIfNeeded()
        let family = Self.normalize(rawFamily)
        let key = FontKey(family: family, bold: bold, italic: italic, size: sizePx)
        lock.lock()
        if let cached = fontCache[key] { lock.unlock(); return cached }
        lock.unlock()

        let result = makeFont(family: family, sizePx: sizePx, bold: bold, italic: italic)

        lock.lock()
        fontCache[key] = result
        lock.unlock()
        return result
    }

    private func makeFont(family: String, sizePx: Double, bold: Bool, italic: Bool) -> CTFont? {
        let size = CGFloat(sizePx)
        lock.lock()
        let exact = faces[FaceKey(family: family, bold: bold, italic: italic)]
        let regular = faces[FaceKey(family: family, bold: false, italic: false)]
        let anyFace = faces.first { $0.key.family == family }?.value
        lock.unlock()

        if let descriptor = exact {
            return CTFontCreateWithFontDescriptor(descriptor, size, nil)
        }
        if let descriptor = regular ?? anyFace {
            // Synthesize the style (as browsers do) when no exact face exists.
            let base = CTFontCreateWithFontDescriptor(descriptor, size, nil)
            return applyTraits(base, bold: bold, italic: italic) ?? base
        }

        // System font lookup by family name.
        let systemName = Self.genericFamilies[family] ?? family
        let candidate = CTFontCreateWithName(systemName as CFString, size, nil)
        let resolvedFamily = (CTFontCopyFamilyName(candidate) as String).lowercased()
        let resolvedName = (CTFontCopyPostScriptName(candidate) as String).lowercased()
        let wanted = systemName.lowercased()
        guard resolvedFamily == wanted || resolvedName == wanted || Self.genericFamilies[family] != nil else {
            return nil
        }
        return applyTraits(candidate, bold: bold, italic: italic) ?? candidate
    }

    private func applyTraits(_ font: CTFont, bold: Bool, italic: Bool) -> CTFont? {
        guard bold || italic else { return font }
        var traits = CTFontSymbolicTraits()
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        return CTFontCreateCopyWithSymbolicTraits(font, 0, nil, traits, traits)
    }

    /// Split a CSS family list ("Bravura, 'Petaluma Script'") into names.
    public static func splitFamilies(_ css: String) -> [String] {
        css.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }.filter { !$0.isEmpty }
    }

    static func normalize(_ family: String) -> String {
        family.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .lowercased()
    }
}
