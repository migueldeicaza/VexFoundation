// VexFoundation - Runtime context for mutable global state.

import Foundation

/// Mutable runtime state for VexFoundation.
///
/// This context owns state that was historically shared via module-level static
/// variables (default registry, metrics and fonts, auto IDs, etc.).
/// Create separate contexts to isolate tests or independent rendering sessions.
public final class VexRuntimeContext {
    private let lock = NSRecursiveLock()

    private var nextElementID: Int
    private weak var defaultRegistry: Registry?

    private var unisonEnabled: Bool
    private var staveLineThickness: Double
    private var upstreamParityModeValue: Bool

    /// Metrics tree (fonts, sizes, paddings) for this context. See `Metrics`.
    public let metrics: MetricsStore

    public init(
        nextElementID: Int = 1000,
        unisonEnabled: Bool = true,
        staveLineThickness: Double = 1,
        upstreamParityMode: Bool = false,
        metrics: MetricsStore = MetricsStore()
    ) {
        self.nextElementID = nextElementID
        self.unisonEnabled = unisonEnabled
        self.staveLineThickness = staveLineThickness
        self.upstreamParityModeValue = upstreamParityMode
        self.metrics = metrics
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

    /// Set the music and text font stack, e.g. `setFonts("Bravura", "Academico")`.
    /// Port of `VexFlow.setFonts()`.
    public func setFonts(_ fontNames: [String]) {
        metrics.set("fontFamily", fontNames.joined(separator: ","))
        metrics.clear()
    }

    /// The current font family names. Port of `VexFlow.getFonts()`.
    public func getFonts() -> [String] {
        (metrics.get("fontFamily") as? String ?? "").split(separator: ",").map(String.init)
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

    /// When `true`, local VexFlowPatch deviations (OSMD-derived behavior) are
    /// disabled so rendering matches upstream VexFlow exactly. Parity tests set this.
    public var upstreamParityMode: Bool {
        get { lock.lock(); defer { lock.unlock() }; return upstreamParityModeValue }
        set { lock.lock(); defer { lock.unlock() }; upstreamParityModeValue = newValue }
    }

    public func getStaveLineThickness() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return staveLineThickness
    }

    public func setStaveLineThickness(_ thickness: Double) {
        lock.lock()
        defer { lock.unlock() }
        staveLineThickness = thickness
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
