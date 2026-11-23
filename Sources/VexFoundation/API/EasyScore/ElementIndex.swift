// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/easyscore/elementindex.ts` (VexFlow 5.2.0).
// Score-local IDs and notation provenance, independent of the ambient Registry.

import Foundation

/// Original notation input and its end-exclusive range. Measures are one-based.
/// Offsets count `Character`s (upstream counts UTF-16 code units; the same for ASCII input).
public struct EasyScoreSource: Equatable, Sendable {
    public var input: String
    public var start: Int
    public var end: Int
    public var measure: Int?

    public init(input: String, start: Int, end: Int, measure: Int? = nil) {
        self.input = input
        self.start = start
        self.end = end
        self.measure = measure
    }
}

/// One index per EasyScore. Element provenance also lets visual debuggers inspect an element directly.
final class EasyScoreReferences {
    /// Internal reference entry. The subscription is released by reset or failed construction.
    private final class Reference {
        var id: String
        let source: EasyScoreSource?
        var unsubscribe: () -> Void = {}

        init(id: String, source: EasyScoreSource?) {
            self.id = id
            self.source = source
        }
    }

    private var ids: [String: VexElement] = [:]
    private var entries: [ObjectIdentifier: (element: VexElement, reference: Reference)] = [:]
    private var scopes: [[() -> Void]] = []

    /// Values are copies, so tools cannot change the stored source range.
    static func sourceOf(_ element: VexElement) -> EasyScoreSource? {
        element.easyScoreSource
    }

    /// Missing IDs are ordinary lookup misses, including after reset.
    func get(_ id: String) -> VexElement? { ids[id] }

    /// Only members of this score have instance-local source metadata.
    func getSource(_ element: VexElement) -> EasyScoreSource? {
        entries[ObjectIdentifier(element)]?.reference.source
    }

    /// Reject empty or duplicate IDs before registration or native ID mutation.
    private func validate(_ element: VexElement, _ id: String?) throws -> String {
        guard let id, !id.isEmpty else { throw VexError("BadArguments", "Score elements need a nonempty ID.") }
        if let existing = ids[id], existing !== element {
            throw VexError("BadArguments", "Duplicate score element ID: \(id)")
        }
        return id
    }

    /// Repeated registration is harmless. Native ID changes keep the index synchronized.
    @discardableResult
    func add<T: VexElement>(_ element: T, source: EasyScoreSource? = nil) throws -> T {
        let key = ObjectIdentifier(element)
        if entries[key] != nil { return element }
        let id = try validate(element, element.getAttribute("id"))
        let entry = Reference(id: id, source: source)
        entry.unsubscribe = element.onIdChange(
            validate: { [weak self, unowned element] next in _ = try self?.validate(element, next) },
            changed: { [weak self, unowned element, unowned entry] in
                guard let self else { return }
                self.ids.removeValue(forKey: entry.id)
                entry.id = element.getAttribute("id") ?? ""
                self.ids[entry.id] = element
            }
        )
        entries[key] = (element, entry)
        ids[id] = element
        if let source { element.easyScoreSource = source }
        if !scopes.isEmpty {
            scopes[scopes.count - 1].append { [weak self, weak element] in
                if let element { self?.remove(element) }
            }
        }
        return element
    }

    /// Release exactly this score's subscription and provenance.
    private func remove(_ element: VexElement) {
        guard let entry = entries[ObjectIdentifier(element)]?.reference else { return }
        entry.unsubscribe()
        ids.removeValue(forKey: entry.id)
        entries.removeValue(forKey: ObjectIdentifier(element))
        if let source = entry.source, element.easyScoreSource == source { element.easyScoreSource = nil }
    }

    /// Preserve references across draw(); reset explicitly ends the editing session.
    func clear() {
        for (element, _) in Array(entries.values) { remove(element) }
    }

    /// Nested failed construction releases subscriptions as well as visible references.
    func transaction<T>(_ build: () throws -> T) throws -> T {
        scopes.append([])
        do {
            let result = try build()
            let undo = scopes.removeLast()
            if !scopes.isEmpty { scopes[scopes.count - 1].append(contentsOf: undo) }
            return result
        } catch {
            let undo = scopes.removeLast()
            for revert in undo.reversed() { revert() }
            throw error
        }
    }
}
