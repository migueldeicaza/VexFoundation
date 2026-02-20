// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

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

    /// Maps [attribute_name][attribute_value][element_id] => Element
    private var index: [String: [String: [String: VexElement]]] = [
        "id": [:],
        "type": [:],
        "class": [:],
    ]
    private let indexLock = NSRecursiveLock()

    // MARK: - Init

    public init() {}

    // MARK: - Clear

    @discardableResult
    public func clear() -> Self {
        indexLock.lock()
        defer { indexLock.unlock() }
        index = ["id": [:], "type": [:], "class": [:]]
        return self
    }

    // MARK: - Index Management

    public func setIndexValue(name: String, value: String, id: String, elem: VexElement) {
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
        indexLock.lock()
        defer { indexLock.unlock() }

        let elemId = id ?? elem.getAttribute("id") ?? ""
        guard !elemId.isEmpty else {
            fatalError("[VexError] MissingId: Can't add element without `id` attribute to registry")
        }

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

        let allowedNames = ["id", "type", "class"]
        if allowedNames.contains(info.name) {
            updateIndex(info)
        }
        return self
    }
}
