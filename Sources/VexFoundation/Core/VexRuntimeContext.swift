// VexFoundation - Runtime context for mutable global state.

import Foundation

/// Mutable runtime state for VexFoundation.
///
/// This context owns state that was historically shared via module-level static
/// variables (default registry, font stack, glyph cache, auto IDs, etc.).
/// Create separate contexts to isolate tests or independent rendering sessions.
public final class VexRuntimeContext {
    private let lock = NSRecursiveLock()

    private var nextElementID: Int
    private weak var defaultRegistry: Registry?

    private var fontsByName: [String: VexFont]

    private var musicFontStack: [VexFont]
    private var glyphCache: GlyphCache
    private var glyphCacheKey: String

    private var chordSymbolGlobalMetricsByCacheKey: [String: [String: Any]]

    private var unisonEnabled: Bool

    public init(
        nextElementID: Int = 1000,
        unisonEnabled: Bool = true
    ) {
        self.nextElementID = nextElementID
        self.fontsByName = [:]
        self.musicFontStack = []
        self.glyphCache = GlyphCache()
        self.glyphCacheKey = ""
        self.chordSymbolGlobalMetricsByCacheKey = [:]
        self.unisonEnabled = unisonEnabled
    }

    public func generateElementID() -> String {
        lock.lock()
        defer { lock.unlock() }
        let id = "auto\(nextElementID)"
        nextElementID += 1
        return id
    }

    public func getDefaultRegistry() -> Registry? {
        lock.lock()
        defer { lock.unlock() }
        return defaultRegistry
    }

    public func setDefaultRegistry(_ registry: Registry?) {
        lock.lock()
        defer { lock.unlock() }
        defaultRegistry = registry
    }

    public func loadFont(name: String, data: FontData? = nil, metrics: FontMetrics? = nil) -> VexFont {
        lock.lock()
        defer { lock.unlock() }

        let font = fontsByName[name] ?? VexFont(name: name)
        fontsByName[name] = font

        if let data {
            font.data = data
        }
        if let metrics {
            font.metrics = metrics
        }

        return font
    }

    public func getMusicFontStack() -> [VexFont] {
        lock.lock()
        defer { lock.unlock() }
        return musicFontStack
    }

    public func setMusicFontStack(_ fonts: [VexFont]) {
        lock.lock()
        defer { lock.unlock() }

        musicFontStack = fonts
        glyphCacheKey = fonts.map(\.name).joined(separator: ",")
        glyphCache = GlyphCache()
        chordSymbolGlobalMetricsByCacheKey.removeAll()
    }

    func getGlyphCache() -> GlyphCache {
        lock.lock()
        defer { lock.unlock() }
        return glyphCache
    }

    public func getGlyphCacheKey() -> String {
        lock.lock()
        defer { lock.unlock() }
        return glyphCacheKey
    }

    public func getChordSymbolGlobalMetrics(cacheKey: String) -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }
        return chordSymbolGlobalMetricsByCacheKey[cacheKey]
    }

    public func setChordSymbolGlobalMetrics(cacheKey: String, value: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        chordSymbolGlobalMetricsByCacheKey[cacheKey] = value
    }

    public func getUnisonEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return unisonEnabled
    }

    public func setUnisonEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        unisonEnabled = enabled
    }
}

/// Global runtime context manager.
///
/// Use `withContext` to isolate mutable state for a scoped operation.
public enum VexRuntime {
    private final class Storage: @unchecked Sendable {
        private let lock = NSRecursiveLock()
        private var defaultContext = VexRuntimeContext()

        func getDefaultContext() -> VexRuntimeContext {
            lock.lock()
            defer { lock.unlock() }
            return defaultContext
        }

        func setDefaultContext(_ context: VexRuntimeContext) {
            lock.lock()
            defer { lock.unlock() }
            defaultContext = context
        }
    }

    private static let storage = Storage()
    private static let threadContextKey = "VexFoundation.VexRuntime.threadContext"

    public static func getCurrentContext() -> VexRuntimeContext {
        if let context = Thread.current.threadDictionary[threadContextKey] as? VexRuntimeContext {
            return context
        }
        return storage.getDefaultContext()
    }

    /// Set the process-wide default runtime context.
    /// Prefer `withContext` for scoped isolation.
    public static func setCurrentContext(_ context: VexRuntimeContext) {
        storage.setDefaultContext(context)
    }

    public static func resetCurrentContext() {
        setCurrentContext(VexRuntimeContext())
    }

    @discardableResult
    public static func withContext<T>(_ context: VexRuntimeContext, _ body: () throws -> T) rethrows -> T {
        let dict = Thread.current.threadDictionary
        let previous = dict[threadContextKey] as? VexRuntimeContext
        dict[threadContextKey] = context
        defer {
            if let previous {
                dict[threadContextKey] = previous
            } else {
                dict.removeObject(forKey: threadContextKey)
            }
        }
        return try body()
    }
}
