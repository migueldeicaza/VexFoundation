// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/fretdiagram.ts` (VexFlow 5.9.0).
// Vertical and horizontal chord frames with tuning-specific guitar voicings.

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

/// Grid spacing in renderer pixels, measured across the strings and along the neck.
private let STRING_SPACING: Double = 9
private let FRET_SPACING: Double = 11

/// Chord frame orientation. In a horizontal frame the nut is at the left and the highest string is on top. (VexFlow 5.9.0)
public enum FretDiagramOrientation: String, Equatable, Sendable {
    case vertical
    case horizontal
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

    /// In a horizontal frame the nut is at the left and the highest string is on top. (VexFlow 5.9.0)
    public var orientation: FretDiagramOrientation?
    public var frets: [FretDiagramString]
    /// Left-hand fingers 1-4, low string first. `nil` or an omitted entry leaves the dot plain. (VexFlow 5.8.0)
    public var fingerings: [Int?]?
    public var firstFret: Int?
    public var rows: Int?
    public var barre: Barre?

    public init(
        orientation: FretDiagramOrientation? = nil,
        frets: [FretDiagramString], fingerings: [Int?]? = nil, firstFret: Int? = nil, rows: Int? = nil,
        barre: Barre? = nil
    ) {
        self.orientation = orientation
        self.frets = frets
        self.fingerings = fingerings
        self.firstFret = firstFret
        self.rows = rows
        self.barre = barre
    }
}

/// Standard-tuned major chords in preference order. Slash basses have their own entries. (VexFlow 5.9.0)
private let standardMajorVoicings: [(root: String, bass: String?, name: String, frame: FretDiagramSpec)] = [
    ("C", nil, "open", FretDiagramSpec(frets: [.muted, .fret(3), .fret(2), .fret(0), .fret(1), .fret(0)])),
    (
        "C", nil, "third-position",
        FretDiagramSpec(
            frets: [.muted, .fret(3), .fret(5), .fret(5), .fret(5), .fret(3)], firstFret: 3,
            barre: .init(fret: 3, from: 5, to: 1)
        )
    ),
    ("C", "E", "open", FretDiagramSpec(frets: [.fret(0), .fret(3), .fret(2), .fret(0), .fret(1), .fret(0)])),
    ("D", nil, "open", FretDiagramSpec(frets: [.muted, .muted, .fret(0), .fret(2), .fret(3), .fret(2)])),
    ("G", nil, "open", FretDiagramSpec(frets: [.fret(3), .fret(2), .fret(0), .fret(0), .fret(0), .fret(3)])),
]

public final class FretDiagram: VexElement {
    /// The registry and font metrics both use the diagram category.
    override public class var category: String { "FretDiagram" }

    /// Return a fresh frame for this harmony and tuning. Omitting the name selects the first registered shape.
    /// Only standard guitar tuning (the preset name or its pitches) and major qualities have voicings. (VexFlow 5.9.0)
    public static func lookupVoicing(_ harmony: ChordHarmony, tuning: String, name: String? = nil) throws -> FretDiagramSpec? {
        let pitches = tuning
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .joined(separator: ",")
        if tuning != "standard" && pitches != Tuning.names["standard"] { return nil }
        if !["", "maj", "major", "M"].contains(harmony.quality ?? "") { return nil }
        let root = try NotationSpelling.chordText(ChordHarmony(root: harmony.root))
        let bass = try harmony.bass.map { try NotationSpelling.chordText(ChordHarmony(root: $0)) }
        return standardMajorVoicings.first(where: { v in
            v.root == root && v.bass == bass && (name == nil || v.name == name)
        })?.frame
    }

    private let orientation: FretDiagramOrientation
    private let frets: [FretDiagramString]
    private var fingerings: [Int?] = []
    private let first: Int
    private let rows: Int
    private let barre: FretDiagramSpec.Barre?

    public init(_ spec: FretDiagramSpec) throws {
        orientation = spec.orientation ?? .vertical
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
        if first > 1 { setText(String(first)) }
        try setFingerings(spec.fingerings ?? [])
    }

    /// Replace the finger assignments for this chord. Passing no assignments clears all labels. (VexFlow 5.8.0)
    @discardableResult
    public func setFingerings(_ fingerings: [Int?] = []) throws -> Self {
        if fingerings.count > frets.count || fingerings.enumerated().contains(where: { i, finger in
            guard let finger else { return false }
            return finger < 1 || finger > 4 || frets[i] == .fret(0) || frets[i] == .muted
        }) {
            throw VexError("BadArguments", "Assign fingers 1–4 to stopped strings only.")
        }
        self.fingerings = fingerings
        return self
    }

    /// The finger on string `i` (low string first), or `nil`.
    private func finger(_ i: Int) -> Int? {
        i < fingerings.count ? fingerings[i] : nil
    }

    /// Grid coordinates run across strings (low to high) and along the neck (nut to bridge). (VexFlow 5.9.0)
    private func gridPoint(_ across: Double, _ along: Double) -> (Double, Double) {
        if orientation == .horizontal {
            return (getX() + 14 + along, getY() + 6 + Double(frets.count - 1) * STRING_SPACING - across)
        }
        return (getX() + 22 + across, getY() + 14 + along)
    }

    /// The top-left position includes the open-string marks and the upright starting-fret label.
    override public func getBoundingBox() -> BoundingBox? {
        let across = Double(frets.count - 1) * STRING_SPACING
        let along = Double(rows) * FRET_SPACING
        if orientation == .vertical { return BoundingBox(getX(), getY(), 28 + across, 17 + along) }
        var width = 16 + along
        var height = 12 + across
        if first > 1 {
            let metrics = textMetrics
            width = max(width, 15 + metrics.actualBoundingBoxLeft + metrics.actualBoundingBoxRight)
            height += metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent + 1
        }
        return BoundingBox(getX(), getY(), width, height)
    }

    /// Paint the digit over the dot and any barre that passes through it.
    private func drawFinger(_ ctx: RenderContext, _ finger: Int, _ x: Double, _ y: Double) {
        ctx.save()
        ctx.setFont(VexFont.validate(family: fontInfo.family, size: "7.5px", weight: "bold"))
        ctx.setFillStyle("white")
        let text = String(finger)
        // A digit's cap height is about five pixels at this fixed marker size.
        ctx.fillText(text, x - ctx.measureText(text).width / 2, y + 2.5)
        ctx.restore()
    }

    override public func draw() throws {
        let ctx = try checkContext()
        let across = Double(frets.count - 1) * STRING_SPACING
        let first = self.first
        func fretCenter(_ fret: Int) -> Double { (Double(fret - first) + 0.5) * FRET_SPACING }
        func line(_ across1: Double, _ along1: Double, _ across2: Double, _ along2: Double) {
            let (x1, y1) = gridPoint(across1, along1)
            let (x2, y2) = gridPoint(across2, along2)
            ctx.beginPath()
            ctx.moveTo(x1, y1)
            ctx.lineTo(x2, y2)
            ctx.stroke()
        }
        ctx.save()
        let group = ctx.openGroup("fret-diagram", getAttribute("id"))
        (group as? SVGNode)?.setAttribute(
            "aria-label",
            "Chord frame, low to high: "
                + frets.enumerated().map { i, fret in
                    finger(i).map { "\(fret) (finger \($0))" } ?? fret.description
                }.joined(separator: ", ")
                + (barre.map { ", barre at fret \($0.fret)" } ?? "")
        )
        if first > 1 {
            ctx.setFont(fontInfo)
            if orientation == .horizontal {
                // Leave room below the lowest string for its stopped dot or partial barre.
                let (left, bottom) = gridPoint(0, 0)
                let metrics = textMetrics
                ctx.fillText(text, left + metrics.actualBoundingBoxLeft, bottom + 6 + metrics.actualBoundingBoxAscent)
            } else {
                ctx.fillText(text, getX() + 2, getY() + 23)
            }
        }
        for row in 0...rows {
            ctx.setLineWidth(row == 0 && first == 1 ? 2.5 : 1)
            line(0, Double(row) * FRET_SPACING, across, Double(row) * FRET_SPACING)
        }
        for (i, fret) in frets.enumerated() {
            let string = Double(i) * STRING_SPACING
            line(string, 0, string, Double(rows) * FRET_SPACING)
            switch fret {
            case .muted:
                line(string - 2.5, -8, string + 2.5, -3)
                line(string + 2.5, -8, string - 2.5, -3)
            case .fret(let n):
                ctx.beginPath()
                let radius: Double = finger(i) != nil ? 4 : 3
                let (x, y) = gridPoint(string, n != 0 ? fretCenter(n) : -5.5)
                ctx.arc(x, y, n != 0 ? radius : 2.5, 0, 2 * Double.pi, false)
                if n != 0 { ctx.fill() } else { ctx.stroke() }
            }
        }
        if let barre {
            ctx.setLineWidth(5)
            line(
                across - Double(barre.from - 1) * STRING_SPACING, fretCenter(barre.fret),
                across - Double(barre.to - 1) * STRING_SPACING, fretCenter(barre.fret)
            )
        }
        for i in fingerings.indices {
            if let finger = finger(i), case .fret(let n) = frets[i] {
                let (x, y) = gridPoint(Double(i) * STRING_SPACING, fretCenter(n))
                drawFinger(ctx, finger, x, y)
            }
        }
        ctx.closeGroup()
        ctx.restore()
        setRendered()
    }
}
