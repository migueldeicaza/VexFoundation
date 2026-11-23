// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/gracenote.ts` (VexFlow 5.3.0).
// Grace-note glyphs and the optional acciaccatura slash.

import Foundation

public enum GraceNoteError: Error, LocalizedError, Equatable, Sendable {
    case noBeam

    public var errorDescription: String? {
        switch self {
        case .noBeam:
            return "Can't calculate slash bounding box without a beam."
        }
    }
}

// MARK: - GraceNote Struct

/// Input structure for creating a GraceNote (extends StaveNoteStruct).
public struct GraceNoteStruct {
    public var keys: NonEmptyArray<StaffKeySpec>
    public var duration: NoteDurationSpec
    public var slash: Bool
    public var stemDirection: StemDirection?
    public var autoStem: Bool?
    public var clef: ClefName?
    public var dots: Int?
    public var type: NoteType?
    public var octaveShift: Int?
    /// Override the music glyph family (upstream `StaveNoteStruct.musicFont`). (VexFlow 5.3.0)
    public var musicFont: String?
    /// Score-local engraving profile (upstream `StaveNoteStruct.engraving`). (VexFlow 5.3.0)
    public var engraving: EngravingProfile?
    /// Source identities of instruments and playing instructions. (VexFlow 5.4.0)
    public var notation: [NotationIdentity] = []

    public init(
        keys: NonEmptyArray<StaffKeySpec>,
        duration: NoteDurationSpec = .eighth,
        slash: Bool = false,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        clef: ClefName? = nil,
        dots: Int? = nil,
        type: NoteType? = nil,
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

    /// String-based parser for compatibility with external text inputs.
    public init(
        parsingKeys keys: [String] = [],
        duration: String,
        slash: Bool = false,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        clef: ClefName? = nil,
        dots: Int? = nil,
        type: String? = nil,
        octaveShift: Int? = nil
    ) throws {
        let parsedDuration = try NoteDurationSpec(parsing: duration)
        let parsedKeys = try StaffKeySpec.parseManyNonEmpty(keys)
        let parsedType: NoteType?
        if let type {
            guard let explicitType = NoteType(parsing: type) else {
                throw NoteDurationParseError.invalidType(type)
            }
            parsedType = explicitType
        } else {
            parsedType = nil
        }

        self.init(
            keys: parsedKeys,
            duration: parsedDuration,
            slash: slash,
            stemDirection: stemDirection,
            autoStem: autoStem,
            clef: clef,
            dots: dots,
            type: parsedType,
            octaveShift: octaveShift
        )
    }

    /// Failable parser convenience.
    public init?(
        parsingDuration duration: String,
        keys: [String],
        slash: Bool = false,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        clef: ClefName? = nil,
        dots: Int? = nil,
        type: String? = nil,
        octaveShift: Int? = nil
    ) {
        guard let parsed = try? GraceNoteStruct(
            parsingKeys: keys,
            duration: duration,
            slash: slash,
            stemDirection: stemDirection,
            autoStem: autoStem,
            clef: clef,
            dots: dots,
            type: type,
            octaveShift: octaveShift
        ) else { return nil }
        self = parsed
    }

    /// Failable string parser convenience matching the throwing parser shape.
    public init?(
        parsingKeysOrNil keys: [String],
        duration: String,
        slash: Bool = false,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        clef: ClefName? = nil,
        dots: Int? = nil,
        type: String? = nil,
        octaveShift: Int? = nil
    ) {
        guard let parsed = try? GraceNoteStruct(
            parsingKeys: keys,
            duration: duration,
            slash: slash,
            stemDirection: stemDirection,
            autoStem: autoStem,
            clef: clef,
            dots: dots,
            type: type,
            octaveShift: octaveShift
        ) else { return nil }
        self = parsed
    }

    /// String-key parser for typed duration inputs.
    public init(
        parsingKeys keys: [String],
        duration: NoteDurationSpec = .eighth,
        slash: Bool = false,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        clef: ClefName? = nil,
        dots: Int? = nil,
        type: NoteType? = nil,
        octaveShift: Int? = nil
    ) throws {
        self.init(
            keys: try StaffKeySpec.parseManyNonEmpty(keys),
            duration: duration,
            slash: slash,
            stemDirection: stemDirection,
            autoStem: autoStem,
            clef: clef,
            dots: dots,
            type: type,
            octaveShift: octaveShift
        )
    }

    /// Failable string-key parser for typed duration inputs.
    public init?(
        parsingKeysOrNil keys: [String],
        duration: NoteDurationSpec = .eighth,
        slash: Bool = false,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        clef: ClefName? = nil,
        dots: Int? = nil,
        type: NoteType? = nil,
        octaveShift: Int? = nil
    ) {
        guard let parsed = try? GraceNoteStruct(
            parsingKeys: keys,
            duration: duration,
            slash: slash,
            stemDirection: stemDirection,
            autoStem: autoStem,
            clef: clef,
            dots: dots,
            type: type,
            octaveShift: octaveShift
        ) else { return nil }
        self = parsed
    }

    /// Convert to StaveNoteStruct. Upstream: `{ strokePx: GraceNote.LEDGER_LINE_OFFSET, ...noteStruct }`.
    /// The grace note scale comes from the `GraceNote.fontScale` metric.
    func toStaveNoteStruct() -> StaveNoteStruct {
        var result = StaveNoteStruct(
            keys: keys,
            duration: duration,
            dots: dots,
            type: type,
            stemDirection: stemDirection,
            autoStem: autoStem,
            strokePx: GraceNote.GRACE_LEDGER_LINE_OFFSET,
            octaveShift: octaveShift,
            clef: clef,
            musicFont: musicFont,
            engraving: engraving
        )
        result.notation = notation
        return result
    }
}

// MARK: - GraceNote

/// A grace note: a small ornamental note rendered before or after a main note.
public class GraceNote: StaveNote {

    override public class var category: String { "GraceNote" }

    /// Upstream `GraceNote.LEDGER_LINE_OFFSET` (Swift cannot redeclare the
    /// `StaveNote.LEDGER_LINE_OFFSET` static in a subclass).
    public static let GRACE_LEDGER_LINE_OFFSET: Double = 2

    @available(*, deprecated, renamed: "GRACE_LEDGER_LINE_OFFSET")
    public static var LEDGER_LINE_OFFSET_OVERRIDE: Double { GRACE_LEDGER_LINE_OFFSET }

    /// VexFlow 4 grace note scale. VexFlow 5 uses the `GraceNote.fontScale` metric (2/3).
    @available(*, deprecated, message: "Use getFontScale().")
    public static let SCALE: Double = 0.66

    // MARK: - Properties

    public var slash: Bool
    public var slur: Bool

    // MARK: - Init

    public init(_ noteStruct: GraceNoteStruct) {
        slash = noteStruct.slash
        slur = true

        super.init(noteStruct.toStaveNoteStruct())

        _ = buildNoteHeads()

        width = 3
    }

    // MARK: - Scale

    @available(*, deprecated, message: "Use getFontScale().")
    public func getStaveNoteScale() -> Double {
        getFontScale()
    }

    // MARK: - Stem Extension

    override public func getStemExtension() -> Double {
        if let override = stemExtensionOverride, override != 0 {
            return override
        }

        var ret = super.getStemExtension()
        ret = Stem.HEIGHT * getFontScale() - Stem.HEIGHT + ret
        return ret
    }

    // MARK: - Draw

    /// Absolute endpoints of the grace slash used by both measurement and drawing. (VexFlow 5.3.0)
    public func getSlash() throws -> (x1: Double, y1: Double, x2: Double, y2: Double)? {
        guard slash, stem != nil else { return nil }
        let scale = getFontScale()

        let slashBBox: (x1: Double, y1: Double, x2: Double, y2: Double)
        if let beam {
            // FIXME: should render slash after beam?
            if !beam.postFormatted {
                beam.postFormat()
            }

            slashBBox = try calcBeamedNotesSlashBBoxThrowing(
                slashStemOffset: 8 * scale,
                slashBeamOffset: 8 * scale,
                stemProtrusion: 6 * scale,
                beamProtrusion: 5 * scale
            )
        } else {
            let stemDirection = getStemDirection()
            let noteHeadBounds = getNoteHeadBounds()
            let noteHeadWidth = noteHeads.first?.getWidth() ?? 0
            let x = stemDirection == Stem.DOWN ? getAbsoluteX() : getAbsoluteX() + noteHeadWidth
            let defaultOffsetY = (Tables.STEM_HEIGHT * scale) / 2
            let y = stemDirection == Stem.DOWN
                ? noteHeadBounds.yBottom + defaultOffsetY
                : noteHeadBounds.yTop - defaultOffsetY

            if stemDirection == Stem.DOWN {
                slashBBox = (
                    x1: x - noteHeadWidth,
                    y1: y - noteHeadWidth,
                    x2: x + noteHeadWidth,
                    y2: y + noteHeadWidth
                )
            } else {
                slashBBox = (
                    x1: x - noteHeadWidth,
                    y1: y + noteHeadWidth,
                    x2: x + noteHeadWidth,
                    y2: y - noteHeadWidth
                )
            }
        }

        return slashBBox
    }

    override public func draw() throws {
        try super.draw()
        guard let slashBBox = try getSlash() else { return }
        let scale = getFontScale()

        // FIXME: avoid staff lines, ledger lines or others.

        let ctx = try checkContext()
        ctx.setLineWidth(1 * scale) // FIXME: use more appropriate value.
        ctx.beginPath()
        ctx.moveTo(slashBBox.x1, slashBBox.y1)
        ctx.lineTo(slashBBox.x2, slashBBox.y2)
        ctx.closePath()
        ctx.stroke()
    }

    // MARK: - Beamed Slash BBox

    /// Calculates the bounding box for a slash line when the grace note is beamed.
    public func calcBeamedNotesSlashBBox(
        slashStemOffset: Double,
        slashBeamOffset: Double,
        stemProtrusion: Double,
        beamProtrusion: Double
    ) -> (x1: Double, y1: Double, x2: Double, y2: Double) {
        (try? calcBeamedNotesSlashBBoxThrowing(
            slashStemOffset: slashStemOffset,
            slashBeamOffset: slashBeamOffset,
            stemProtrusion: stemProtrusion,
            beamProtrusion: beamProtrusion
        )) ?? (0, 0, 0, 0)
    }

    public func calcBeamedNotesSlashBBoxThrowing(
        slashStemOffset: Double,
        slashBeamOffset: Double,
        stemProtrusion: Double,
        beamProtrusion: Double
    ) throws -> (x1: Double, y1: Double, x2: Double, y2: Double) {
        guard let beam else {
            throw GraceNoteError.noBeam
        }

        let beamSlope = beam.slope
        let isBeamEndNote = beam.notes.last === self
        let scaleX: Double = isBeamEndNote ? -1 : 1
        let beamAngle = atan(beamSlope * scaleX)

        // slash line intersecting point on beam.
        let iPointDx = cos(beamAngle) * slashBeamOffset
        let iPointDy = sin(beamAngle) * slashBeamOffset

        let adjustedStemOffset = slashStemOffset * getStemDirection().signDouble
        let slashAngle = atan((iPointDy - adjustedStemOffset) / iPointDx)
        let protrusionStemDeltaX = cos(slashAngle) * stemProtrusion * scaleX
        let protrusionStemDeltaY = sin(slashAngle) * stemProtrusion
        let protrusionBeamDeltaX = cos(slashAngle) * beamProtrusion * scaleX
        let protrusionBeamDeltaY = sin(slashAngle) * beamProtrusion

        let stemX = getStemX()
        let stem0X = beam.notes[0].getStemX()
        let stemY = beam.getBeamYToDraw() + (stemX - stem0X) * beamSlope

        return (
            x1: stemX - protrusionStemDeltaX,
            y1: stemY + adjustedStemOffset - protrusionStemDeltaY,
            x2: stemX + iPointDx * scaleX + protrusionBeamDeltaX,
            y2: stemY + iPointDy + protrusionBeamDeltaY
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

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("D5/q, E5, F5, G5")
        let gn = f.GraceNote(GraceNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 5)),
            duration: .eighth,
            slash: true
        ))
        let group = f.GraceNoteGroup(notes: [gn], slur: true)
        _ = notes[0].addModifier(group, index: 0)

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
