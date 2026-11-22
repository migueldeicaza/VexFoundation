// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/svgcontext.ts` (VexFlow 5). Instead of a DOM, the context keeps
// a small element tree and serializes it with `getSVG()`. The serialization
// follows the browser `XMLSerializer` output of upstream, so SVG files can be
// compared with the upstream reference images.

import Foundation

/// Options controlling SVG serialization.
public struct SVGRenderOptions: Sendable, Equatable {
    /// Number of decimal places for coordinates (`Tables.RENDER_PRECISION_PLACES`).
    public var precision: Int
    /// Prefix the output with an XML declaration.
    public var includeXMLHeader: Bool
    /// Write the `viewBox` attribute on the root element.
    public var includeViewBox: Bool

    public init(precision: Int = 3, includeXMLHeader: Bool = false, includeViewBox: Bool = true) {
        self.precision = max(0, precision)
        self.includeXMLHeader = includeXMLHeader
        self.includeViewBox = includeViewBox
    }
}

/// An SVG attribute value: JavaScript numbers and strings behave differently
/// for truthiness (`0` is not written, `"0"` is).
public enum SVGAttributeValue: Equatable, Sendable {
    case number(Double)
    case string(String)

    var isTruthy: Bool {
        switch self {
        case .number(let n): return n != 0 && !n.isNaN
        case .string(let s): return !s.isEmpty
        }
    }

    var stringValue: String {
        switch self {
        case .number(let n): return formatJSNumber(n)
        case .string(let s): return s
        }
    }

    /// JavaScript loose equality (`==`) between attribute values.
    func looselyEquals(_ other: SVGAttributeValue?) -> Bool {
        guard let other else { return false }
        switch (self, other) {
        case let (.number(a), .number(b)): return a == b
        case let (.string(a), .string(b)): return a == b
        case let (.number(a), .string(b)), let (.string(b), .number(a)):
            let trimmed = b.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return a == 0 }
            return Double(trimmed) == a
        }
    }
}

/// Ordered attribute dictionary (JavaScript object key order).
public struct SVGAttributes: Sendable, Equatable {
    public private(set) var keys: [String] = []
    private var values: [String: SVGAttributeValue] = [:]

    public init() {}

    public init(_ pairs: [(String, SVGAttributeValue)]) {
        for (k, v) in pairs { self[k] = v }
    }

    public subscript(key: String) -> SVGAttributeValue? {
        get { values[key] }
        set {
            if let newValue {
                if values[key] == nil { keys.append(key) }
                values[key] = newValue
            } else if values[key] != nil {
                values.removeValue(forKey: key)
                keys.removeAll { $0 == key }
            }
        }
    }

    /// `{...self, ...other}`.
    public func merging(_ other: SVGAttributes) -> SVGAttributes {
        var copy = self
        for k in other.keys { copy[k] = other.values[k] }
        return copy
    }

    var pairs: [(String, SVGAttributeValue)] { keys.map { ($0, values[$0]!) } }
}

/// A node in the SVG element tree.
public final class SVGNode {
    public let name: String
    public private(set) var attributes: [(String, String)] = []
    public var children: [SVGNode] = []
    public var textContent: String?
    public weak var parent: SVGNode?

    init(_ name: String) { self.name = name }

    public func setAttribute(_ name: String, _ value: String) {
        if let i = attributes.firstIndex(where: { $0.0 == name }) {
            attributes[i].1 = value
        } else {
            attributes.append((name, value))
        }
    }

    public func getAttribute(_ name: String) -> String? {
        attributes.first { $0.0 == name }?.1
    }

    func append(_ child: SVGNode) {
        child.parent = self
        children.append(child)
    }

    func serialize(into out: inout String, isRoot: Bool = false) {
        out += "<\(name)"
        if isRoot { out += " xmlns=\"http://www.w3.org/2000/svg\"" }
        for (k, v) in attributes {
            out += " \(k)=\"\(SVGNode.escapeAttribute(v))\""
        }
        if children.isEmpty, textContent == nil {
            out += "/>"
            return
        }
        out += ">"
        if let textContent { out += SVGNode.escapeText(textContent) }
        for child in children { child.serialize(into: &out) }
        out += "</\(name)>"
    }

    static func escapeAttribute(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for c in s {
            switch c {
            case "&": out += "&amp;"
            case "\"": out += "&quot;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(c)
            }
        }
        return out
    }

    static func escapeText(_ s: String) -> String {
        var out = ""
        for c in s {
            switch c {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(c)
            }
        }
        return out
    }
}

private let attributesToIgnore: [String: Set<String>] = [
    "path": ["x", "y", "width", "height", "font-family", "font-weight", "font-style", "font-size"],
    "rect": ["font-family", "font-weight", "font-style", "font-size"],
    "text": ["width", "height"],
]

/// `RenderContext` that builds an SVG document.
public final class SVGRenderContext: RenderContext {
    private struct SavedState {
        var state: SVGAttributes
        var attributes: SVGAttributes
    }

    public let svg: SVGNode
    public private(set) var width: Double = 0
    public private(set) var height: Double = 0
    private var path: String = ""
    private var pen: (x: Double, y: Double) = (.nan, .nan)
    public private(set) var attributes: SVGAttributes
    private var state: SVGAttributes
    private var stateStack: [SavedState] = []
    private var parentNode: SVGNode
    private var groups: [SVGNode]
    private var groupAttributes: [SVGAttributes] = []
    private let precision: Double
    private let options: SVGRenderOptions
    public var backgroundFillStyle: String = "white"
    private var fontCSSString: String = ""

    /// Prefix for `class` and `id` attributes (`VexFlow` uses `vf-`).
    public static var idPrefix = "vf-"

    public init(width: Double, height: Double, options: SVGRenderOptions = SVGRenderOptions()) {
        self.options = options
        self.precision = pow(10, Double(options.precision))

        let svg = SVGNode("svg")
        svg.setAttribute("pointer-events", "none")
        self.svg = svg
        self.parentNode = svg
        self.groups = [svg]

        let defaultFont: [(String, SVGAttributeValue)] = [
            ("font-family", .string(Metrics.getString("fontFamily", "Bravura,Academico"))),
            ("font-size", .string("10pt")),
            ("font-weight", .string(VexFontWeight.normal.rawValue)),
            ("font-style", .string(VexFontStyle.normal.rawValue)),
        ]
        self.state = SVGAttributes([("scaleX", .number(1)), ("scaleY", .number(1))] + defaultFont)
        self.attributes = SVGAttributes([
            ("stroke-width", .number(1)),
            ("stroke-dasharray", .string("none")),
            ("fill", .string("black")),
            ("stroke", .string("black")),
            ("shadowBlur", .number(0)),
            ("shadowColor", .string("black")),
        ] + defaultFont)

        applyAttributes(svg, attributes)
        groupAttributes.append(attributes)
        resize(width, height)
    }

    /// Prefix a class or id with `idPrefix`.
    static func prefix(_ text: String) -> String { idPrefix + text }

    private func round(_ n: Double) -> Double {
        (n * precision + 0.5).rounded(.down) / precision
    }

    private func num(_ n: Double) -> String { formatJSNumber(n) }

    // MARK: - Groups

    @discardableResult
    public func openGroup(_ cls: String? = nil, _ id: String? = nil) -> Any? {
        let group = SVGNode("g")
        groups.append(group)
        parentNode.append(group)
        parentNode = group
        if let cls, !cls.isEmpty { group.setAttribute("class", Self.prefix(cls)) }
        if let id, !id.isEmpty { group.setAttribute("id", Self.prefix(id)) }
        applyAttributes(group, attributes)
        groupAttributes.append(groupAttributes[groupAttributes.count - 1].merging(attributes))
        return group
    }

    public func closeGroup() {
        guard groups.count > 1 else { return }
        groups.removeLast()
        groupAttributes.removeLast()
        parentNode = groups[groups.count - 1]
    }

    public func openRotation(_ angleDegrees: Double, _ x: Double, _ y: Double) {
        let group = openGroup(nil, nil) as! SVGNode
        group.setAttribute("transform", "translate(\(num(x)),\(num(y))) rotate(\(num(angleDegrees))) translate(-\(num(x)),-\(num(y)))")
    }

    public func closeRotation() {
        closeGroup()
    }

    public func add(_ child: Any) {
        if let node = child as? SVGNode { parentNode.append(node) }
    }

    // MARK: - Style

    @discardableResult
    public func setFillStyle(_ style: String) -> Self {
        attributes["fill"] = .string(style)
        return self
    }

    @discardableResult
    public func setBackgroundFillStyle(_ style: String) -> Self {
        backgroundFillStyle = style
        return self
    }

    @discardableResult
    public func setStrokeStyle(_ style: String) -> Self {
        attributes["stroke"] = .string(style)
        return self
    }

    @discardableResult
    public func setShadowColor(_ color: String) -> Self {
        attributes["shadowColor"] = .string(color)
        return self
    }

    @discardableResult
    public func setShadowBlur(_ blur: Double) -> Self {
        attributes["shadowBlur"] = .number(blur)
        return self
    }

    @discardableResult
    public func setLineWidth(_ width: Double) -> Self {
        attributes["stroke-width"] = .number(width)
        return self
    }

    @discardableResult
    public func setLineDash(_ dashPattern: [Double]) -> Self {
        attributes["stroke-dasharray"] = .string(dashPattern.map(formatJSNumber).joined(separator: ","))
        return self
    }

    @discardableResult
    public func setLineCap(_ capType: VexLineCap) -> Self {
        attributes["stroke-linecap"] = .string(capType.rawValue)
        return self
    }

    public var fillStyle: String {
        get { attributes["fill"]?.stringValue ?? "" }
        set { setFillStyle(newValue) }
    }

    public var strokeStyle: String {
        get { attributes["stroke"]?.stringValue ?? "" }
        set { setStrokeStyle(newValue) }
    }

    // MARK: - Size

    @discardableResult
    public func resize(_ width: Double, _ height: Double) -> Self {
        self.width = width
        self.height = height
        applyAttributes(svg, SVGAttributes([("width", .number(width)), ("height", .number(height))]))
        let sx = Metrics.number(stateNumber("scaleX")) ?? 1
        let sy = Metrics.number(stateNumber("scaleY")) ?? 1
        state["scaleX"] = .number(1)
        state["scaleY"] = .number(1)
        scale(sx, sy)
        return self
    }

    private func stateNumber(_ key: String) -> Double? {
        if case .number(let n)? = state[key] { return n }
        return nil
    }

    @discardableResult
    public func scale(_ x: Double, _ y: Double) -> Self {
        let sx = (stateNumber("scaleX").flatMap { $0 == 0 ? nil : $0 } ?? 1) * x
        let sy = (stateNumber("scaleY").flatMap { $0 == 0 ? nil : $0 } ?? 1) * y
        state["scaleX"] = .number(sx)
        state["scaleY"] = .number(sy)
        setViewBox(0, 0, width / sx, height / sy)
        return self
    }

    public func setViewBox(_ minX: Double, _ minY: Double, _ width: Double, _ height: Double) {
        guard options.includeViewBox else { return }
        svg.setAttribute("viewBox", "\(num(minX)) \(num(minY)) \(num(width)) \(num(height))")
    }

    // MARK: - Attributes

    private func applyAttributes(_ element: SVGNode, _ attributes: SVGAttributes) {
        let ignore = attributesToIgnore[element.name]
        let inherited = groupAttributes.last
        for (name, value) in attributes.pairs {
            if ignore?.contains(name) == true { continue }
            if Self.isUnsafeAttributeName(name) { continue }
            guard value.isTruthy else { continue }
            if let inherited, value.looselyEquals(inherited[name]) { continue }
            element.setAttribute(name, value.stringValue)
        }
    }

    /// Reject attribute names that could run script or load resources.
    static func isUnsafeAttributeName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("on") || lower == "href" || lower.hasSuffix(":href")
    }

    public func clear() {
        svg.children.removeAll()
    }

    // MARK: - Rectangles

    @discardableResult
    public func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        rect(x, y, width, height, attributes: nil)
    }

    @discardableResult
    public func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double, attributes extra: SVGAttributes?) -> Self {
        var y = y, height = height
        if height < 0 {
            y += height
            height *= -1
        }
        let rectangle = SVGNode("rect")
        let attrs = extra ?? SVGAttributes([
            ("fill", .string("none")),
            ("stroke-width", self.attributes["stroke-width"] ?? .number(1)),
            ("stroke", .string("black")),
        ])
        let geometry = SVGAttributes([
            ("x", .number(round(x))),
            ("y", .number(round(y))),
            ("width", .number(round(width))),
            ("height", .number(round(height))),
        ])
        applyAttributes(rectangle, geometry.merging(attrs))
        add(rectangle)
        return self
    }

    @discardableResult
    public func fillRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        rect(x, y, width, height, attributes: SVGAttributes([
            ("fill", attributes["fill"] ?? .string("black")),
            ("stroke", .string("none")),
        ]))
    }

    @discardableResult
    public func pointerRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        rect(x, y, width, height, attributes: SVGAttributes([
            ("opacity", .string("0")),
            ("pointer-events", .string("auto")),
        ]))
    }

    @discardableResult
    public func clearRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        rect(x, y, width, height, attributes: SVGAttributes([
            ("fill", .string(backgroundFillStyle)),
            ("stroke", .string("none")),
        ]))
    }

    // MARK: - Paths

    @discardableResult
    public func beginPath() -> Self {
        path = ""
        pen = (.nan, .nan)
        return self
    }

    @discardableResult
    public func moveTo(_ x: Double, _ y: Double) -> Self {
        let x = round(x), y = round(y)
        path += "M\(num(x)) \(num(y))"
        pen = (x, y)
        return self
    }

    @discardableResult
    public func lineTo(_ x: Double, _ y: Double) -> Self {
        let x = round(x), y = round(y)
        path += "L\(num(x)) \(num(y))"
        pen = (x, y)
        return self
    }

    @discardableResult
    public func bezierCurveTo(_ cp1x: Double, _ cp1y: Double, _ cp2x: Double, _ cp2y: Double, _ x: Double, _ y: Double) -> Self {
        let x = round(x), y = round(y)
        path += "C\(num(round(cp1x))) \(num(round(cp1y))),\(num(round(cp2x))) \(num(round(cp2y))),\(num(x)) \(num(y))"
        pen = (x, y)
        return self
    }

    @discardableResult
    public func quadraticCurveTo(_ cpx: Double, _ cpy: Double, _ x: Double, _ y: Double) -> Self {
        let x = round(x), y = round(y)
        path += "Q\(num(round(cpx))) \(num(round(cpy))),\(num(x)) \(num(y))"
        pen = (x, y)
        return self
    }

    @discardableResult
    public func arc(_ x: Double, _ y: Double, _ radius: Double, _ startAngle: Double, _ endAngle: Double, _ counterclockwise: Bool) -> Self {
        let twoPi = 2 * Double.pi
        let x0 = round(x + radius * cos(startAngle))
        let y0 = round(y + radius * sin(startAngle))

        let tmpStartTest = normalizeAngle(startAngle)
        let tmpEndTest = normalizeAngle(endAngle)
        if (!counterclockwise && endAngle - startAngle >= twoPi)
            || (counterclockwise && startAngle - endAngle >= twoPi)
            || tmpStartTest == tmpEndTest {
            let x1 = round(x + radius * cos(startAngle + .pi))
            let y1 = round(y + radius * sin(startAngle + .pi))
            let r = round(radius)
            path += "M\(num(x0)) \(num(y0)) A\(num(r)) \(num(r)) 0 0 0 \(num(x1)) \(num(y1)) "
            path += "A\(num(r)) \(num(r)) 0 0 0 \(num(x0)) \(num(y0))"
            pen = (x0, y0)
        } else {
            let x1 = round(x + radius * cos(endAngle))
            let y1 = round(y + radius * sin(endAngle))
            let s = tmpStartTest, e = tmpEndTest
            var large: Bool = abs(e - s) < .pi ? counterclockwise : !counterclockwise
            if s > e { large = !large }
            let sweep = !counterclockwise
            let r = round(radius)
            path += "M\(num(x0)) \(num(y0)) A\(num(r)) \(num(r)) 0 \(large ? 1 : 0) \(sweep ? 1 : 0) \(num(x1)) \(num(y1))"
            pen = (x1, y1)
        }
        return self
    }

    @discardableResult
    public func closePath() -> Self {
        path += "Z"
        return self
    }

    private func shadowStyle() -> String {
        let blur: Double
        if case .number(let b)? = attributes["shadowBlur"] { blur = b } else { blur = 0 }
        return "filter: drop-shadow(0 0 \(num(blur / 1.5))px \(attributes["shadowColor"]?.stringValue ?? "black"))"
    }

    private var hasShadow: Bool {
        if case .number(let b)? = attributes["shadowBlur"] { return b > 0 }
        return false
    }

    @discardableResult
    public func fill() -> Self {
        var attrs = attributes
        attrs["stroke"] = .string("none")
        return fill(attributes: attrs)
    }

    /// Fill the current path with explicit attributes.
    @discardableResult
    public func fill(attributes attrs: SVGAttributes) -> Self {
        let node = SVGNode("path")
        var attrs = attrs
        attrs["d"] = .string(path)
        if hasShadow { attrs["style"] = .string(shadowStyle()) }
        applyAttributes(node, attrs)
        if hasShadow { node.setAttribute("style", shadowStyle()) }
        add(node)
        return self
    }

    @discardableResult
    public func stroke() -> Self {
        let node = SVGNode("path")
        var attrs = attributes
        attrs["fill"] = .string("none")
        attrs["d"] = .string(path)
        applyAttributes(node, attrs)
        if hasShadow { node.setAttribute("style", shadowStyle()) }
        add(node)
        return self
    }

    // MARK: - Text

    public func measureText(_ text: String) -> TextMeasure {
        let info = VexFont.validate(
            family: attributes["font-family"]?.stringValue,
            size: attributes["font-size"]?.stringValue,
            weight: attributes["font-weight"]?.stringValue,
            style: attributes["font-style"]?.stringValue
        )
        let m = TextMeasurer.measure(text, fontInfo: info)
        return TextMeasure(
            x: 0,
            y: -m.actualBoundingBoxAscent,
            width: m.width,
            height: m.actualBoundingBoxAscent + m.actualBoundingBoxDescent
        )
    }

    @discardableResult
    public func fillText(_ text: String, _ x: Double, _ y: Double) -> Self {
        guard !text.isEmpty else { return self }
        var attrs = attributes
        attrs["stroke"] = .string("none")
        attrs["x"] = .number(round(x))
        attrs["y"] = .number(round(y))
        let node = SVGNode("text")
        node.textContent = text
        applyAttributes(node, attrs)
        add(node)
        return self
    }

    // MARK: - State

    @discardableResult
    public func save() -> Self {
        stateStack.append(SavedState(state: state, attributes: attributes))
        return self
    }

    @discardableResult
    public func restore() -> Self {
        if let saved = stateStack.popLast() {
            state = saved.state
            attributes = saved.attributes
        }
        return self
    }

    // MARK: - Font

    @discardableResult
    public func setFont(_ family: String?, _ size: Double?, _ weight: String?, _ style: String?) -> Self {
        setFont(VexFont.validate(
            family: family,
            size: size.map { "\(formatJSNumber($0))pt" },
            weight: weight,
            style: style
        ))
    }

    @discardableResult
    public func setFont(_ fontInfo: FontInfo) -> Self {
        let info = VexFont.validate(fontInfo: fontInfo)
        fontCSSString = VexFont.toCSSString(info)
        let fontAttributes: [(String, SVGAttributeValue)] = [
            ("font-family", .string(info.family)),
            ("font-size", .string(info.size)),
            ("font-weight", .string(info.weight)),
            ("font-style", .string(info.style)),
        ]
        for (k, v) in fontAttributes {
            attributes[k] = v
            state[k] = v
        }
        return self
    }

    public func getFont() -> String {
        fontCSSString
    }

    // MARK: - Output

    /// Serialize the document.
    public func getSVG() -> String {
        var out = options.includeXMLHeader ? "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" : ""
        svg.serialize(into: &out, isRoot: true)
        return out
    }
}
