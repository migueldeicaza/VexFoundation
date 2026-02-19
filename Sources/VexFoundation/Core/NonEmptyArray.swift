// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// A collection that always contains at least one element.
public struct NonEmptyArray<Element>: RandomAccessCollection, MutableCollection {
    private var storage: [Element]

    public typealias Index = Array<Element>.Index

    public var startIndex: Index { storage.startIndex }
    public var endIndex: Index { storage.endIndex }

    public subscript(position: Index) -> Element {
        get { storage[position] }
        set { storage[position] = newValue }
    }

    public init(_ first: Element, _ rest: Element...) {
        storage = [first] + rest
    }

    public init?(validating elements: [Element]) {
        guard let first = elements.first else { return nil }
        storage = [first] + elements.dropFirst()
    }

    public var first: Element { storage[0] }

    public var array: [Element] { storage }
}
