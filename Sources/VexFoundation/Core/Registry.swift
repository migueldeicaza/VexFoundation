// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Mohit Cheppudira
//
// Port of `src/registry.ts` (VexFlow 5.2.0).

import Foundation

public enum RegistryError: Error, LocalizedError, Equatable, Sendable {
    case missingElementID

    public var errorDescription: String? {
        switch self {
        case .missingElementID:
            return "Cannot add an element without an `id` attribute to the registry."
        }
    }
}

// MARK: - Registry Update

/// Information about an attribute change for index updating.
public struct RegistryUpdate {
    public var id: String
    public var name: String
    public var value: String?
    public var oldValue: String?
}

// MARK: - Registry

/// Tracks, queries, and manages VexFlow elements by id, type, and class.
///
/// Elements can be registered explicitly via `register(elem:id:)`,
/// or automatically by enabling the default registry.
public final class Registry {

    // MARK: - Default Registry

    public static func getDefaultRegistry() -> Registry? {
        VexRuntime.getCurrentContext().getDefaultRegistry()
    }

    /// Enable auto-registration of new elements with this registry.
    public static func enableDefaultRegistry(_ registry: Registry) {
        VexRuntime.getCurrentContext().setDefaultRegistry(registry)
    }

    public static func disableDefaultRegistry() {
        VexRuntime.getCurrentContext().setDefaultRegistry(nil)
    }

    // MARK: - Index

    /// [attributeName][attributeValue][elementId] => Element
    private var index: [String: [String: [String: VexElement]]] = [
        "id": [:],
        "type": [:],
        "class": [:],
    ]
    private let indexLock = NSRecursiveLock()
    /// Registrations made during nested synchronous construction scopes. (VexFlow 5.2.0)
    private var transactions: [[VexElement]] = []

    // MARK: - Init

    public init() {}

    // MARK: - Transactions (VexFlow 5.2.0)

    /// Restore indexes and detach new elements if construction fails. External mutations are not undone.
    public func transaction<T>(_ build: () throws -> T) rethrows -> T {
        indexLock.lock()
        let before = index
        let existing = Set((before["id"] ?? [:]).values.flatMap { $0.values }.map { ObjectIdentifier($0) })
        transactions.append([])
        indexLock.unlock()
        do {
            let result = try build()
            indexLock.lock()
            transactions.removeLast()
            indexLock.unlock()
            return result
        } catch {
            indexLock.lock()
            let created = transactions.removeLast()
            index = before
            indexLock.unlock()
            for element in created where !existing.contains(ObjectIdentifier(element)) {
                element.onRegister(nil)
            }
            throw error
        }
    }

    /// All elements in the ID index.
    public func getRegisteredElements() -> [VexElement] {
        indexLock.lock()
        defer { indexLock.unlock() }
        return (index["id"] ?? [:]).values.flatMap { $0.values }
    }

    // MARK: - Clear

    @discardableResult
    public func clear() -> Self {
        indexLock.lock()
        defer { indexLock.unlock() }
        index = ["id": [:], "type": [:], "class": [:]]
        return self
    }

    // MARK: - Index Management

    /// Only these attributes may select an index, even when called directly. (VexFlow 5.1.0)
    public static func isValidIndexName(_ name: String) -> Bool {
        name == "id" || name == "type" || name == "class"
    }

    /// Upstream 5.1.0 throws for an unknown index name; this ignores it.
    public func setIndexValue(name: String, value: String, id: String, elem: VexElement) {
        guard Self.isValidIndexName(name) else { return }
        indexLock.lock()
        defer { indexLock.unlock() }

        var byValue = index[name] ?? [:]
        var byID = byValue[value] ?? [:]
        byID[id] = elem
        byValue[value] = byID
        index[name] = byValue
    }

    /// Update the index when an element's attribute changes.
    public func updateIndex(_ info: RegistryUpdate) {
        guard Self.isValidIndexName(info.name) else { return }
        indexLock.lock()
        defer { indexLock.unlock() }

        let elem = getElementById(info.id)
        if let oldValue = info.oldValue, index[info.name]?[oldValue] != nil {
            index[info.name]?[oldValue]?.removeValue(forKey: info.id)
        }
        if let value = info.value, let elem {
            setIndexValue(name: info.name, value: value,
                         id: elem.getAttribute("id") ?? info.id, elem: elem)
        }
    }

    // MARK: - Register

    /// Register an element with this registry.
    @discardableResult
    public func register(_ elem: VexElement, id: String? = nil) -> Self {
        _ = try? registerThrowing(elem, id: id)
        return self
    }

    /// Register an element with this registry.
    @discardableResult
    public func registerThrowing(_ elem: VexElement, id: String? = nil) throws -> Self {
        indexLock.lock()
        defer { indexLock.unlock() }

        let elemId = id ?? elem.getAttribute("id") ?? ""
        guard !elemId.isEmpty else {
            throw RegistryError.missingElementID
        }

        for i in transactions.indices { transactions[i].append(elem) }

        _ = elem.setAttribute("id", elemId)
        setIndexValue(name: "id", value: elemId, id: elemId, elem: elem)
        updateIndex(RegistryUpdate(
            id: elemId, name: "type",
            value: elem.getAttribute("type"), oldValue: nil
        ))
        elem.onRegister(self)
        return self
    }

    // MARK: - Query

    public func getElementById(_ id: String) -> VexElement? {
        indexLock.lock()
        defer { indexLock.unlock() }
        return index["id"]?[id]?[id]
    }

    public func getElementsByAttribute(_ attribute: String, value: String) -> [VexElement] {
        guard Self.isValidIndexName(attribute) else { return [] }
        indexLock.lock()
        defer { indexLock.unlock() }

        guard let attrIndex = index[attribute],
              let valueIndex = attrIndex[value] else {
            return []
        }
        return Array(valueIndex.values)
    }

    public func getElementsByType(_ type: String) -> [VexElement] {
        getElementsByAttribute("type", value: type)
    }

    public func getElementsByClass(_ className: String) -> [VexElement] {
        getElementsByAttribute("class", value: className)
    }

    // MARK: - Update Notification

    /// Called by elements when an indexed attribute changes.
    @discardableResult
    public func onUpdate(_ info: RegistryUpdate) -> Self {
        indexLock.lock()
        defer { indexLock.unlock() }

        if Self.isValidIndexName(info.name) {
            updateIndex(info)
        }
        return self
    }
}
