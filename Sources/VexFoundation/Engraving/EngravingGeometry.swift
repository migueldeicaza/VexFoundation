// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/engravinggeometry.ts` (VexFlow 5.4.0).
// Pre-draw geometry of formatted VF5 notation. All coordinates are unscaled renderer pixels.

import Foundation

/// A point in renderer pixels.
public struct EngravingPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Enclosing rectangles can be conservative for strokes and curves.
public struct EngravingShape {
    public var parts: [BoundingBox]
    public var anchors: [String: EngravingPoint]

    public init(parts: [BoundingBox] = [], anchors: [String: EngravingPoint] = [:]) {
        self.parts = parts
        self.anchors = anchors
    }
}

/// Codes are stable. Source IDs come from the native element or its author.
public struct GeometryDiagnostic: Sendable, Equatable {
    public enum Code: String, Sendable {
        case unsupportedGeometry = "UnsupportedGeometry"
        case unformattedGeometry = "UnformattedGeometry"
        case invalidGeometry = "InvalidGeometry"
        case layoutOverflow = "LayoutOverflow"
    }

    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public var code: Code
    /// Always `"measure"`.
    public var phase: String
    public var severity: Severity
    public var sourceId: String
}

/// Return `nil` from an extension adapter to delegate to the built-in participants.
public struct GeometryOptions {
    public var `extension`: ((VexElement) -> EngravingShape?)?
    public var paddingPx: Double?
    public var viewport: BoundingBox?

    public init(
        extension: ((VexElement) -> EngravingShape?)? = nil,
        paddingPx: Double? = nil,
        viewport: BoundingBox? = nil
    ) {
        self.extension = `extension`
        self.paddingPx = paddingPx
        self.viewport = viewport
    }
}

/// Union and layout bounds are absent for empty or invalid geometry. Check diagnostics for partial results.
public struct EngravingGeometry {
    public var parts: [BoundingBox]
    public var anchors: [String: EngravingPoint]
    public var ink: BoundingBox?
    public var layout: BoundingBox?
    public var diagnostics: [GeometryDiagnostic]
}

/// Invalid `paddingPx` (upstream `RangeError`).
public enum EngravingGeometryError: Error, LocalizedError, Equatable, Sendable {
    case invalidPadding

    public var errorDescription: String? {
        "Expected finite nonnegative layout padding."
    }
}

/// Symmetric padding also encloses the stroke around a sloping centerline.
private func inflate(_ box: BoundingBox, _ amount: Double) -> BoundingBox {
    BoundingBox(x: box.x - amount, y: box.y - amount, w: box.w + 2 * amount, h: box.h + 2 * amount)
}

private func rectangle(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> BoundingBox {
    BoundingBox(x: min(x1, x2), y: min(y1, y2), w: abs(x2 - x1), h: abs(y2 - y1))
}

/// Swift has no exception for an unformatted element; this marks the upstream `RuntimeError`.
private struct UnformattedElement: Error {}

/// A note owns heads, flag, stem, ledgers and modifiers. A beam owns the filled strips.
private func noteShape(_ note: StaveNote) throws -> EngravingShape {
    if note.renderOptions.draw == false { return EngravingShape() }
    // Upstream `getAbsoluteX()` and `checkStave()` throw for an unformatted note.
    _ = try note.checkStaveThrowing()
    _ = try note.checkTickContextThrowing()
    note.getBeam()?.postFormat()
    var parts = note.getHeadInk()
    var anchors: [String: EngravingPoint] = [:]
    let ys = note.getYs()
    for (i, box) in parts.enumerated() {
        anchors["head\(i)"] = EngravingPoint(x: box.x + box.w / 2, y: i < ys.count ? ys[i] : .nan)
    }
    if let segment = note.getStemSegment() {
        parts.append(BoundingBox(
            x: segment.x - Stem.WIDTH / 2,
            y: min(segment.baseY, segment.tipY),
            w: Stem.WIDTH,
            h: abs(segment.tipY - segment.baseY)
        ))
        anchors["stemBase"] = EngravingPoint(x: segment.x, y: segment.baseY)
        anchors["stemTip"] = EngravingPoint(x: segment.x, y: segment.tipY)
    }
    if let flag = note.getFlagInk() { parts.append(flag) }
    let lineWidth = note.getLedgerLineStyle().lineWidth ?? note.checkStave().getDefaultLedgerLineStyle().lineWidth ?? 1
    for line in note.getLedgerLines() {
        parts.append(BoundingBox(x: line.x, y: line.y - lineWidth / 2, w: line.width, h: lineWidth))
    }
    if let grace = note as? GraceNote, let slash = try grace.getSlash() {
        parts.append(inflate(rectangle(slash.x1, slash.y1, slash.x2, slash.y2), grace.getFontScale() / 2))
    }
    return EngravingShape(parts: parts, anchors: anchors)
}

/// Measure after formatting and assigning staves. Never calls draw or touches a renderer. (VexFlow 5.3.0)
public func measureEngraving(_ element: VexElement, options: GeometryOptions = GeometryOptions()) throws -> EngravingGeometry {
    var diagnostics: [GeometryDiagnostic] = []
    func report(_ owner: VexElement, _ code: GeometryDiagnostic.Code) {
        diagnostics.append(GeometryDiagnostic(
            code: code,
            phase: "measure",
            severity: code == .layoutOverflow ? .warning : .error,
            sourceId: owner.getAttribute("id") ?? ""
        ))
    }

    func collect(_ owner: VexElement) -> EngravingShape {
        var shape = EngravingShape()
        func children(_ elements: [VexElement]) {
            for child in elements { shape.parts.append(contentsOf: collect(child).parts) }
        }
        do {
            let kind = type(of: owner)
            if let custom = options.extension?(owner) {
                shape = custom
            } else if kind == StaveNote.self || kind == GraceNote.self, let note = owner as? StaveNote {
                shape = try noteShape(note)
                if note.renderOptions.draw != false { children(note.getModifiers()) }
            } else if kind == FiguredBass.self, let figuredBass = owner as? FiguredBass {
                shape.parts.append(contentsOf: try figuredBass.getInkParts())
            } else if kind == GraceNoteGroup.self, let group = owner as? GraceNoteGroup {
                children(try group.getLayoutElements())
            } else if kind == Articulation.self, let articulation = owner as? Articulation {
                let box = try articulation.getInkBounds()
                shape.parts.append(box)
                shape.anchors["center"] = EngravingPoint(x: box.x + box.w / 2, y: box.y + box.h / 2)
            } else if kind == Accidental.self, let accidental = owner as? Accidental {
                shape.parts.append(try accidental.getInkBounds())
            } else if kind == Dot.self, let dot = owner as? Dot {
                _ = try dot.checkAttachedNote().checkStaveThrowing()
                shape.parts.append(dot.getInkBounds())
            } else if kind == Tuplet.self || kind == Ornament.self || kind == PedalMarking.self
                || kind == StaveHairpin.self || kind == TextBracket.self {
                guard let box = owner.getBoundingBox() else { throw UnformattedElement() }
                shape.parts.append(box)
            } else if kind == Beam.self, let beam = owner as? Beam {
                guard let box = beam.getBoundingBox() else { throw UnformattedElement() }
                shape.parts.append(box)
                for (i, note) in beam.getNotes().enumerated() {
                    shape.anchors["stem\(i)"] = EngravingPoint(x: note.getStemX(), y: note.getStemExtents().topY)
                }
            } else if kind == Curve.self, let curve = owner as? Curve {
                guard let box = curve.getBoundingBox() else { throw UnformattedElement() }
                shape.parts.append(inflate(box, (curve.getStyle()?.lineWidth ?? 1) / 2))
                let anchors = try curve.getAnchors()
                shape.anchors = [
                    "start": EngravingPoint(x: anchors.start.x, y: anchors.start.y),
                    "end": EngravingPoint(x: anchors.end.x, y: anchors.end.y),
                ]
            } else if kind == Annotation.self, let mark = owner as? Annotation {
                let x = try mark.computeX().x
                let y = try mark.computeY().y
                shape.parts.append(mark.getTextInk(x, y))
                shape.anchors["baseline"] = EngravingPoint(x: x + mark.getXShift(), y: y + mark.getYShift())
            } else if kind == StaveTie.self && owner.text.isEmpty, let tie = owner as? StaveTie {
                shape.parts.append(try tie.getRibbonBounds())
            } else {
                report(owner, .unsupportedGeometry)
            }
            func finiteBox(_ b: BoundingBox) -> Bool {
                [b.x, b.y, b.w, b.h].allSatisfy { $0.isFinite } && b.w >= 0 && b.h >= 0
            }
            if !shape.parts.allSatisfy(finiteBox) || !shape.anchors.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) {
                report(owner, .invalidGeometry)
                return EngravingShape()
            }
        } catch {
            report(owner, .unformattedGeometry)
        }
        return shape
    }

    var shape = collect(element)
    let padding = options.paddingPx ?? 0
    if !padding.isFinite || padding < 0 { throw EngravingGeometryError.invalidPadding }
    var ink: BoundingBox?
    for part in shape.parts {
        let box = BoundingBox(x: part.x, y: part.y, w: part.w, h: part.h)
        if ink == nil { ink = box } else { _ = ink?.mergeWith(box) }
    }
    let layout = ink.map { inflate($0, padding) }
    if let ink, let group = element as? GraceNoteGroup {
        let note = group.checkAttachedNote()
        let index = group.checkIndex()
        let ys = note.getYs()
        let y = index >= 0 && index < ys.count ? ys[index] : .nan
        shape.anchors["left"] = EngravingPoint(x: ink.x, y: y)
        shape.anchors["right"] = EngravingPoint(x: ink.x + ink.w, y: y)
    }
    if let v = options.viewport, let layout,
       layout.x < v.x || layout.y < v.y || layout.x + layout.w > v.x + v.w || layout.y + layout.h > v.y + v.h {
        report(element, .layoutOverflow)
    }
    return EngravingGeometry(
        parts: shape.parts, anchors: shape.anchors, ink: ink, layout: layout, diagnostics: diagnostics
    )
}
