// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/fretdiagram.ts` (VexFlow 5.6.0).
// A standalone chord frame. Strings run from the lowest (left) to the highest (right).

import Foundation

/// One string of a chord frame: muted, open or stopped at an absolute fret.
public enum FretDiagramString: Equatable, Sendable, CustomStringConvertible {
    case muted
    case fret(Int)

    /// Upstream writes `'x'` for a muted string and the fret number otherwise.
    public var description: String {
        switch self {
        case .muted: return "x"
        case .fret(let n): return String(n)
        }
    }
}

/// Frets are absolute; 0 = open, `.muted` = 'x'. A barre names one-based string numbers.
public struct FretDiagramSpec: Equatable, Sendable {
    public struct Barre: Equatable, Sendable {
        public var fret: Int
        public var from: Int
        public var to: Int

        public init(fret: Int, from: Int, to: Int) {
            self.fret = fret
            self.from = from
            self.to = to
        }
    }

    public var frets: [FretDiagramString]
    public var firstFret: Int?
    public var rows: Int?
    public var barre: Barre?

    public init(frets: [FretDiagramString], firstFret: Int? = nil, rows: Int? = nil, barre: Barre? = nil) {
        self.frets = frets
        self.firstFret = firstFret
        self.rows = rows
        self.barre = barre
    }
}

public final class FretDiagram: VexElement {
    /// The registry and font metrics both use the diagram category.
    override public class var category: String { "FretDiagram" }

    private let frets: [FretDiagramString]
    private let first: Int
    private let rows: Int
    private let barre: FretDiagramSpec.Barre?

    public init(_ spec: FretDiagramSpec) throws {
        frets = spec.frets
        first = spec.firstFret ?? 1
        rows = spec.rows ?? 4
        barre = spec.barre
        let (first, rows) = (self.first, self.rows)
        func visible(_ n: Int) -> Bool { n >= first && n < first + rows }
        if frets.count < 2 || first < 1 || rows < 1 || frets.contains(where: {
            if case .fret(let n) = $0 { return n != 0 && !visible(n) }
            return false
        }) {
            throw VexError("BadArguments", "Invalid chord frame or fret outside the displayed range.")
        }
        if let barre {
            let count = frets.count
            if ![barre.from, barre.to].allSatisfy({ $0 >= 1 && $0 <= count }) || barre.from == barre.to
                || !visible(barre.fret) {
                throw VexError("BadArguments", "Barre outside chord frame.")
            }
        }
        super.init()
    }

    /// The top-left position includes the open-string marks and starting fret label.
    override public func getBoundingBox() -> BoundingBox? {
        BoundingBox(getX(), getY(), 28 + Double(frets.count - 1) * 9, 17 + Double(rows) * 11)
    }

    override public func draw() throws {
        let ctx = try checkContext()
        let left = getX() + 22
        let top = getY() + 14
        let right = left + Double(frets.count - 1) * 9
        let first = self.first
        func fretY(_ fret: Int) -> Double { top + (Double(fret - first) + 0.5) * 11 }
        func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
            ctx.beginPath()
            ctx.moveTo(x1, y1)
            ctx.lineTo(x2, y2)
            ctx.stroke()
        }
        ctx.save()
        let group = ctx.openGroup("fret-diagram", getAttribute("id"))
        (group as? SVGNode)?.setAttribute(
            "aria-label",
            "Chord frame, low to high: " + frets.map(\.description).joined(separator: ", ")
                + (barre.map { ", barre at fret \($0.fret)" } ?? "")
        )
        if first > 1 {
            ctx.setFont(fontInfo)
            ctx.fillText(String(first), getX() + 2, top + 9)
        }
        for row in 0...rows {
            ctx.setLineWidth(row == 0 && first == 1 ? 2.5 : 1)
            line(left, top + Double(row) * 11, right, top + Double(row) * 11)
        }
        for (i, fret) in frets.enumerated() {
            let x = left + Double(i) * 9
            line(x, top, x, top + Double(rows) * 11)
            switch fret {
            case .muted:
                line(x - 2.5, top - 8, x + 2.5, top - 3)
                line(x + 2.5, top - 8, x - 2.5, top - 3)
            case .fret(let n):
                ctx.beginPath()
                ctx.arc(x, n != 0 ? fretY(n) : top - 5.5, n != 0 ? 3 : 2.5, 0, 2 * Double.pi, false)
                if n != 0 { ctx.fill() } else { ctx.stroke() }
            }
        }
        if let barre {
            ctx.setLineWidth(5)
            line(right - Double(barre.from - 1) * 9, fretY(barre.fret), right - Double(barre.to - 1) * 9, fretY(barre.fret))
        }
        ctx.closeGroup()
        ctx.restore()
        setRendered()
    }
}
