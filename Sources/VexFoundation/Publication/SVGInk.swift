// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Native replacement for the browser geometry that `src/publication.ts` (VexFlow 5.4.0) reads:
// `SVGGraphicsElement.getBBox()`, `CanvasRenderingContext2D.measureText()` and `transform.baseVal`.
// It reads the trees that `SVGRenderContext` and the publication code write, not arbitrary SVG.

import CoreGraphics
import Foundation

extension SVGNode {
    /// Remove this node from its parent.
    func removeFromParent() {
        guard let parent else { return }
        parent.children.removeAll { $0 === self }
        self.parent = nil
    }

    /// Move `child` from its parent to the end of this node (DOM `append`).
    func appendMoving(_ child: SVGNode) {
        child.removeFromParent()
        append(child)
    }

    /// The nodes below this node in document order (DOM `querySelectorAll('*')`).
    func descendants() -> [SVGNode] {
        children.flatMap { [$0] + $0.descendants() }
    }

    /// Create a node with attributes.
    static func make(_ name: String, _ attributes: [(String, String)] = []) -> SVGNode {
        let node = SVGNode(name)
        for (k, v) in attributes { node.setAttribute(k, v) }
        return node
    }
}

/// The font of a text node, with the inherited SVG attributes.
private func textFont(_ node: SVGNode) -> FontInfo {
    FontInfo(
        family: node.inheritedAttribute("font-family") ?? Metrics.getString("fontFamily", "Bravura,Academico"),
        size: node.inheritedAttribute("font-size") ?? "10pt",
        weight: node.inheritedAttribute("font-weight") ?? "normal",
        style: node.inheritedAttribute("font-style") ?? "normal"
    )
}

/// The SVG `getBBox()` of a text node: the advance width and the font ascent and descent.
func svgTextBox(_ node: SVGNode) -> BoundingBox {
    let m = TextMeasurer.measure(node.textContent ?? "", fontInfo: textFont(node))
    let x = Double(node.getAttribute("x") ?? "0") ?? 0
    let y = Double(node.getAttribute("y") ?? "0") ?? 0
    return BoundingBox(x: x, y: y - m.fontBoundingBoxAscent, w: m.width, h: m.fontBoundingBoxAscent + m.fontBoundingBoxDescent)
}

/// The glyph ink of a text node (canvas `measureText` actual bounding box).
private func svgTextInk(_ node: SVGNode) -> BoundingBox {
    let m = TextMeasurer.measure(node.textContent ?? "", fontInfo: textFont(node))
    let x = Double(node.getAttribute("x") ?? "0") ?? 0
    let y = Double(node.getAttribute("y") ?? "0") ?? 0
    return BoundingBox(
        x: x - m.actualBoundingBoxLeft,
        y: y - m.actualBoundingBoxAscent,
        w: m.actualBoundingBoxLeft + m.actualBoundingBoxRight,
        h: m.actualBoundingBoxAscent + m.actualBoundingBoxDescent
    )
}

/// Numbers and command letters of SVG path data.
private func pathTokens(_ d: String) -> [String] {
    var tokens: [String] = []
    var current = ""
    func flush() {
        if !current.isEmpty { tokens.append(current) }
        current = ""
    }
    for ch in d {
        if ch.isLetter && ch != "e" && ch != "E" {
            flush()
            tokens.append(String(ch))
        } else if ch == " " || ch == "," || ch == "\n" || ch == "\t" {
            flush()
        } else if ch == "-" && !current.isEmpty && !current.hasSuffix("e") && !current.hasSuffix("E") {
            flush()
            current = "-"
        } else {
            current.append(ch)
        }
    }
    flush()
    return tokens
}

/// Add an SVG elliptical arc with equal radii (the arcs that `SVGRenderContext.arc` writes).
private func addSVGArc(
    _ path: CGMutablePath, from p0: CGPoint, rx: Double, ry: Double, large: Bool, sweep: Bool, to p1: CGPoint
) {
    var r = (abs(rx) + abs(ry)) / 2
    let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
    let d2 = dx * dx + dy * dy
    if r == 0 || d2 == 0 {
        path.addLine(to: p1)
        return
    }
    if d2 > r * r { r = sqrt(d2) }
    let factor = sqrt(max(0, (r * r - d2) / d2)) * (large == sweep ? -1 : 1)
    let cx = (p0.x + p1.x) / 2 + factor * dy
    let cy = (p0.y + p1.y) / 2 - factor * dx
    let start = atan2(p0.y - cy, p0.x - cx)
    let end = atan2(p1.y - cy, p1.x - cx)
    // In SVG, a positive sweep increases the angle. CoreGraphics `clockwise: false` also increases it.
    path.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: start, endAngle: end, clockwise: !sweep)
}

/// The geometric bounds of absolute SVG path data (SVG `getBBox()` of a path).
func svgPathBounds(_ d: String) -> BoundingBox {
    let tokens = pathTokens(d)
    let path = CGMutablePath()
    var i = 0
    var command = ""
    var current = CGPoint.zero
    var start = CGPoint.zero
    func number() -> Double {
        defer { i += 1 }
        return i < tokens.count ? Double(tokens[i]) ?? 0 : 0
    }
    func point() -> CGPoint {
        let x = number()
        return CGPoint(x: x, y: number())
    }
    while i < tokens.count {
        if let first = tokens[i].first, first.isLetter {
            command = tokens[i]
            i += 1
            if command == "Z" || command == "z" {
                path.closeSubpath()
                current = start
                continue
            }
        }
        switch command {
        case "M":
            current = point()
            start = current
            path.move(to: current)
            command = "L"
        case "L":
            current = point()
            path.addLine(to: current)
        case "C":
            let c1 = point(), c2 = point()
            current = point()
            path.addCurve(to: current, control1: c1, control2: c2)
        case "Q":
            let c = point()
            current = point()
            path.addQuadCurve(to: current, control: c)
        case "A":
            let rx = number(), ry = number()
            _ = number()
            let large = number() != 0, sweep = number() != 0
            let to = point()
            if path.isEmpty { path.move(to: current) }
            addSVGArc(path, from: current, rx: rx, ry: ry, large: large, sweep: sweep, to: to)
            current = to
        default:
            i += 1
        }
    }
    // A browser reports an empty box at the origin for an empty path.
    if path.isEmpty { return BoundingBox(x: 0, y: 0, w: 0, h: 0) }
    let box = path.boundingBoxOfPath
    return BoundingBox(x: box.minX, y: box.minY, w: box.width, h: box.height)
}

/// The transform of a node (`transform.baseVal.consolidate()`), or nil without one.
func svgTransform(_ node: SVGNode) -> CGAffineTransform? {
    guard let text = node.getAttribute("transform"), !text.isEmpty else { return nil }
    var result = CGAffineTransform.identity
    let scanner = Scanner(string: text)
    scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ,\n\t")
    while !scanner.isAtEnd {
        guard let name = scanner.scanCharacters(from: .letters), scanner.scanString("(") != nil else { break }
        var values: [Double] = []
        while let value = scanner.scanDouble() { values.append(value) }
        _ = scanner.scanString(")")
        let v = { (k: Int, fallback: Double) in k < values.count ? values[k] : fallback }
        let step: CGAffineTransform
        switch name {
        case "translate":
            step = CGAffineTransform(translationX: v(0, 0), y: v(1, 0))
        case "scale":
            step = CGAffineTransform(scaleX: v(0, 1), y: v(1, v(0, 1)))
        case "rotate":
            let angle = v(0, 0) * .pi / 180, cx = v(1, 0), cy = v(2, 0)
            step = CGAffineTransform(translationX: cx, y: cy).rotated(by: angle).translatedBy(x: -cx, y: -cy)
        case "matrix":
            step = CGAffineTransform(a: v(0, 1), b: v(1, 0), c: v(2, 0), d: v(3, 1), tx: v(4, 0), ty: v(5, 0))
        default:
            step = .identity
        }
        // A list applies right to left to points, so each step multiplies on the inside.
        result = step.concatenating(result)
    }
    return result
}

/// SVG text boxes include an entire music font's ascent. Use glyph ink to keep cues close to their notes.
/// Port of `inkBox()`: glyph ink for text, geometric bounds for paths and rectangles, and the union for groups.
func svgInkBox(_ node: SVGNode) throws -> BoundingBox? {
    // VexFlow 5.5.0: invisible pointer targets can extend well beyond a modifier's ink. They must not move notes
    // to another system.
    if node.getAttribute("opacity") == "0" { return nil }
    var box: BoundingBox
    switch node.name {
    case "g", "svg":
        let children = try node.children.compactMap { try svgInkBox($0) }
        guard !children.isEmpty else { return nil }
        let x = children.map { $0.x }.min()!, y = children.map { $0.y }.min()!
        box = BoundingBox(
            x: x, y: y,
            w: children.map { $0.x + $0.w }.max()! - x,
            h: children.map { $0.y + $0.h }.max()! - y
        )
    case "text":
        box = svgTextInk(node)
    case "path":
        box = svgPathBounds(node.getAttribute("d") ?? "")
    case "rect":
        let n = { (k: String) in Double(node.getAttribute(k) ?? "0") ?? 0 }
        box = BoundingBox(x: n("x"), y: n("y"), w: n("width"), h: n("height"))
    default:
        return nil
    }
    if ![box.x, box.y, box.w, box.h].allSatisfy({ $0.isFinite }) { throw invalidPage("Nonfinite SVG ink bounds.") }
    guard let matrix = svgTransform(node) else { return box }
    let corners = [
        CGPoint(x: box.x, y: box.y), CGPoint(x: box.x + box.w, y: box.y),
        CGPoint(x: box.x, y: box.y + box.h), CGPoint(x: box.x + box.w, y: box.y + box.h),
    ].map { $0.applying(matrix) }
    let x = corners.map { Double($0.x) }.min()!, y = corners.map { Double($0.y) }.min()!
    return BoundingBox(x: x, y: y, w: corners.map { Double($0.x) }.max()! - x, h: corners.map { Double($0.y) }.max()! - y)
}
