// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/svgexport.ts` (VexFlow 5.1.0): convert SVG text to font outlines
// without changing the live drawing.
//
// Swift: upstream takes loaded opentype.js fonts. Here the outlines come from the
// fonts that laid out the score (`FontRegistry` via `TextMeasurer.layout`, CoreText),
// so no font list is needed.

import CoreGraphics
import Foundation

public enum SVGExportError: Error, LocalizedError, Equatable, Sendable {
    /// A character has no outline in the fonts of its text element.
    case missingFont(text: String, family: String)
    /// Portable export expects plain `SVGRenderContext` text.
    case unexpectedTextChildren

    public var errorDescription: String? {
        switch self {
        case .missingFont(let text, let family):
            return "No outline for \"\(text)\" in \(family)."
        case .unexpectedTextChildren:
            return "Portable export expects plain SVGContext text."
        }
    }
}

extension SVGNode {
    /// A deep copy of this node and its children.
    func clone() -> SVGNode {
        let copy = SVGNode(name)
        for (k, v) in attributes { copy.setAttribute(k, v) }
        copy.textContent = textContent
        for child in children { copy.append(child.clone()) }
        return copy
    }

    /// `SVGRenderContext` omits attributes already present on a containing group or the SVG root.
    func inheritedAttribute(_ name: String) -> String? {
        var current: SVGNode? = self
        while let node = current {
            if let value = node.getAttribute(name) { return value }
            current = node.parent
        }
        return nil
    }
}

/// Clone a VexFoundation SVG tree and replace all text with paths. Throws if a glyph is
/// missing. This accepts trees produced by `SVGRenderContext`, not arbitrary SVG.
/// Port of `svgWithFontPaths()`.
public func svgWithFontPaths(_ svg: SVGNode) throws -> SVGNode {
    let copy = svg.clone()
    try replaceText(in: copy)
    return copy
}

private func replaceText(in node: SVGNode) throws {
    for (index, child) in node.children.enumerated() {
        if child.name == "text" {
            if !child.children.isEmpty { throw SVGExportError.unexpectedTextChildren }
            let path = SVGNode("path")
            for (name, value) in child.attributes where name != "x" && name != "y" && !name.hasPrefix("font-") {
                path.setAttribute(name, value)
            }
            path.setAttribute("d", try textPathData(child))
            path.parent = node
            node.children[index] = path
        } else {
            try replaceText(in: child)
        }
    }
}

/// Lay out the text with its inherited font, as the drawing did, and return its outline.
private func textPathData(_ text: SVGNode) throws -> String {
    let family = text.inheritedAttribute("font-family") ?? ""
    let fontInfo = FontInfo(
        family: family,
        size: text.inheritedAttribute("font-size") ?? "10pt",
        weight: text.inheritedAttribute("font-weight") ?? "normal",
        style: text.inheritedAttribute("font-style") ?? "normal"
    )
    let string = text.textContent ?? ""
    let x = Double(text.getAttribute("x") ?? "0") ?? 0
    let y = Double(text.getAttribute("y") ?? "0") ?? 0
    let layout = TextMeasurer.layout(string, fontInfo: fontInfo)
    if !string.isEmpty && (layout.runs.isEmpty || layout.runs.contains { $0.glyphs.contains(0) }) {
        throw SVGExportError.missingFont(text: string, family: family)
    }
    return svgPathData(layout.path(x: x, y: y))
}

/// SVG path data of `path`, with numbers rounded to `decimalPlaces` (opentype.js `toPathData`).
public func svgPathData(_ path: CGPath, decimalPlaces: Int = 5) -> String {
    let scale = pow(10, Double(decimalPlaces))
    func n(_ v: CGFloat) -> String {
        var r = (Double(v) * scale).rounded() / scale
        if r == 0 { r = 0 } // no "-0"
        return formatJSNumber(r)
    }
    func p(_ pt: CGPoint) -> String { "\(n(pt.x)) \(n(pt.y))" }
    var d = ""
    path.applyWithBlock { element in
        let e = element.pointee
        switch e.type {
        case .moveToPoint: d += "M" + p(e.points[0])
        case .addLineToPoint: d += "L" + p(e.points[0])
        case .addQuadCurveToPoint: d += "Q" + p(e.points[0]) + " " + p(e.points[1])
        case .addCurveToPoint: d += "C" + p(e.points[0]) + " " + p(e.points[1]) + " " + p(e.points[2])
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

extension SVGRenderContext {
    /// Serialize a drawing. With `portable: true`, all text is converted to paths, so the
    /// SVG does not depend on installed fonts. Port of `SVGContext.toSVG()`.
    public static func toSVG(_ svg: SVGNode, portable: Bool = false, includeXMLHeader: Bool = false) throws -> String {
        let output = portable ? try svgWithFontPaths(svg) : svg
        var out = includeXMLHeader ? "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" : ""
        output.serialize(into: &out, isRoot: true)
        return out
    }

    /// Export without modifying the live drawing. With `portable: true`, text and music
    /// glyphs become `<path>` outlines.
    public func toSVG(portable: Bool = false) throws -> String {
        try SVGRenderContext.toSVG(svg, portable: portable, includeXMLHeader: options.includeXMLHeader)
    }
}
