// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - GraceNote Struct

/// Input structure for creating a GraceNote (extends StaveNoteStruct).
public struct GraceNoteStruct {
    public var keys: [String]
    public var duration: String
    public var slash: Bool
    public var stemDirection: StemDirection?
    public var autoStem: Bool?
    public var clef: ClefName?
    public var dots: Int?
    public var type: String?
    public var octaveShift: Int?

    public init(
        keys: [String] = [],
        duration: String = "8",
        slash: Bool = false,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        clef: ClefName? = nil,
        dots: Int? = nil,
        type: String? = nil,
        octaveShift: Int? = nil
    ) {
        self.keys = keys
        self.duration = duration
        self.slash = slash
        self.stemDirection = stemDirection
        self.autoStem = autoStem
        self.clef = clef
        self.dots = dots
        self.type = type
        self.octaveShift = octaveShift
    }

    /// Convert to StaveNoteStruct with grace note scale applied.
    func toStaveNoteStruct() -> StaveNoteStruct {
        StaveNoteStruct(
            keys: keys,
            duration: duration,
            dots: dots,
            type: type,
            stemDirection: stemDirection,
            autoStem: autoStem,
            strokePx: GraceNote.LEDGER_LINE_OFFSET,
            glyphFontScale: Tables.NOTATION_FONT_SCALE * GraceNote.SCALE,
            octaveShift: octaveShift,
            clef: clef
        )
    }
}

// MARK: - GraceNote

/// A grace note: a small ornamental note rendered before or after a main note.
public class GraceNote: StaveNote {

    override public class var category: String { "GraceNote" }

    public static let GRACE_LEDGER_LINE_OFFSET: Double = 2
    public static var LEDGER_LINE_OFFSET_OVERRIDE: Double { GRACE_LEDGER_LINE_OFFSET }
    public static let SCALE: Double = 0.66

    // MARK: - Properties

    public var slash: Bool
    public var slur: Bool = true

    // MARK: - Init

    public init(_ noteStruct: GraceNoteStruct) {
        self.slash = noteStruct.slash

        super.init(noteStruct.toStaveNoteStruct())

        _ = buildNoteHeads()
        tickableWidth = 3
    }

    // MARK: - Scale

    override public func getStaveNoteScale() -> Double {
        renderOptions.glyphFontScale / Tables.NOTATION_FONT_SCALE
    }

    // MARK: - Stem Extension

    override public func getStemExtension() -> Double {
        if let override = stemExtensionOverride {
            return override
        }

        if glyphProps.stem {
            let staveNoteScale = getStaveNoteScale()
            let superExt = super.getStemExtension()
            return (Stem.HEIGHT + superExt) * staveNoteScale - Stem.HEIGHT
        }

        return 0
    }

    // MARK: - Draw

    override public func draw() throws {
        try super.draw()
        setRendered()

        guard slash, let stem else { return }

        let staveNoteScale = getStaveNoteScale()
        let offsetScale = staveNoteScale / 0.66

        var slashX1: Double, slashY1: Double, slashX2: Double, slashY2: Double

        if let beam {
            if !beam.postFormatted {
                beam.postFormat()
            }
            let bbox = calcBeamedNotesSlashBBox(
                slashStemOffset: 8 * offsetScale,
                slashBeamOffset: 8 * offsetScale,
                stemProtrusion: 6 * offsetScale,
                beamProtrusion: 5 * offsetScale
            )
            slashX1 = bbox.x1
            slashY1 = bbox.y1
            slashX2 = bbox.x2
            slashY2 = bbox.y2
        } else {
            let stemDirection = getStemDirection()
            let noteHeadBounds = getNoteHeadBounds()
            let noteStemHeight = stem.getHeight()
            var x = getAbsoluteX()
            var y = stemDirection == Stem.DOWN
                ? noteHeadBounds.yTop - noteStemHeight
                : noteHeadBounds.yBottom - noteStemHeight

            let defaultStemExtension = stemDirection == Stem.DOWN
                ? glyphProps.stemDownExtension
                : glyphProps.stemUpExtension

            var defaultOffsetY = Tables.STEM_HEIGHT
            defaultOffsetY -= defaultOffsetY / 2.8
            defaultOffsetY += defaultStemExtension
            y += defaultOffsetY * staveNoteScale * stemDirection.signDouble

            let offsets: (x1: Double, y1: Double, x2: Double, y2: Double)
            if stemDirection == Stem.UP {
                offsets = (x1: 1, y1: 0, x2: 13, y2: -9)
            } else {
                offsets = (x1: -4, y1: 1, x2: 13, y2: 9)
            }

            x += offsets.x1 * offsetScale
            y += offsets.y1 * offsetScale
            slashX1 = x
            slashY1 = y
            slashX2 = x + offsets.x2 * offsetScale
            slashY2 = y + offsets.y2 * offsetScale
        }

        let ctx = try checkContext()
        ctx.save()
        _ = ctx.setLineWidth(1 * offsetScale)
        ctx.beginPath()
        ctx.moveTo(slashX1, slashY1)
        ctx.lineTo(slashX2, slashY2)
        ctx.closePath()
        ctx.stroke()
        ctx.restore()
    }

    // MARK: - Beamed Slash BBox

    /// Calculates the bounding box for a slash line when the grace note is beamed.
    public func calcBeamedNotesSlashBBox(
        slashStemOffset: Double,
        slashBeamOffset: Double,
        stemProtrusion: Double,
        beamProtrusion: Double
    ) -> (x1: Double, y1: Double, x2: Double, y2: Double) {
        guard let beam else {
            fatalError("[VexError] NoBeam: Can't calculate without a beam.")
        }

        let beamSlope = beam.slope
        let isBeamEndNote = beam.notes.last === self
        let scaleX: Double = isBeamEndNote ? -1 : 1
        let beamAngle = atan(beamSlope * scaleX)

        // Slash line intersecting point on beam
        let iPointDx = cos(beamAngle) * slashBeamOffset
        let iPointDy = sin(beamAngle) * slashBeamOffset

        let adjustedStemOffset = slashStemOffset * getStemDirection().signDouble
        let slashAngle = atan((iPointDy - adjustedStemOffset) / iPointDx)
        let protrusionStemDx = cos(slashAngle) * stemProtrusion * scaleX
        let protrusionStemDy = sin(slashAngle) * stemProtrusion
        let protrusionBeamDx = cos(slashAngle) * beamProtrusion * scaleX
        let protrusionBeamDy = sin(slashAngle) * beamProtrusion

        let stemX = getStemX()
        let stem0X = beam.notes[0].getStemX()
        let stemY = beam.getBeamYToDraw() + (stemX - stem0X) * beamSlope

        return (
            x1: stemX - protrusionStemDx,
            y1: stemY + adjustedStemOffset - protrusionStemDy,
            x2: stemX + iPointDx * scaleX + protrusionBeamDx,
            y2: stemY + iPointDy + protrusionBeamDy
        )
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("GraceNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("D5/q, E5, F5, G5")
        let gn = f.GraceNote(GraceNoteStruct(keys: ["C/5"], duration: "8", slash: true))
        let group = f.GraceNoteGroup(notes: [gn], slur: true)
        _ = notes[0].addModifier(group, index: 0)

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)
            .addTimeSignature("4/4")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
