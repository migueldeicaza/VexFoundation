// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/easyscore/rhythm.ts` (VexFlow 5.7.0).
// Automatic beaming reuses native rational grouping with an explicit EasyScore stem policy.

import Foundation

/// Native grouping/render options, with the same stem override used by `EasyScore.beam()`.
public struct EasyScoreAutoBeamOptions {
    public var groups: [Fraction]?
    public var stemDirection: StemDirection?
    public var beamRests: Bool
    public var beamMiddleOnly: Bool
    public var showStemlets: Bool
    public var maintainStemDirections: Bool
    public var flatBeams: Bool
    public var flatBeamOffset: Double?
    public var secondaryBreaks: String?
    /// Fan the secondary beams of each generated beam. (VexFlow 5.7.0)
    public var feathered: FeatheredBeamDirection?
    /// Stop interior stems of each generated beam at the innermost continuing beam. (VexFlow 5.8.0)
    public var frenchBeams: Bool
    /// `true` recalculates every stem, `false` preserves every stem, `nil` respects explicit stems.
    public var autoStem: Bool?

    public init(
        groups: [Fraction]? = nil, stemDirection: StemDirection? = nil, beamRests: Bool = false,
        beamMiddleOnly: Bool = false, showStemlets: Bool = false, maintainStemDirections: Bool = false,
        flatBeams: Bool = false, flatBeamOffset: Double? = nil, secondaryBreaks: String? = nil,
        autoStem: Bool? = nil, feathered: FeatheredBeamDirection? = nil, frenchBeams: Bool = false
    ) {
        self.feathered = feathered
        self.frenchBeams = frenchBeams
        self.groups = groups
        self.stemDirection = stemDirection
        self.beamRests = beamRests
        self.beamMiddleOnly = beamMiddleOnly
        self.showStemlets = showStemlets
        self.maintainStemDirections = maintainStemDirections
        self.flatBeams = flatBeams
        self.flatBeamOffset = flatBeamOffset
        self.secondaryBreaks = secondaryBreaks
        self.autoStem = autoStem
    }
}

/// Validate every setting before native grouping mutates existing notes or tuplets.
func easyScoreAutoBeam(_ score: EasyScore, _ notes: [StemmableNote], _ options: EasyScoreAutoBeamOptions) throws -> [Beam] {
    if Set(notes.map { ObjectIdentifier($0) }).count != notes.count {
        throw VexError("BadArguments", "Beam notes must be distinct.")
    }
    for note in notes {
        if Factory.getOwner(note) !== score.factory {
            throw VexError("BadArguments", "Beam notes must belong to this Factory.")
        }
        if note.hasBeam() { throw VexError("BadArguments", "Note already belongs to a beam.") }
    }
    let groups = try options.groups ?? Beam.getDefaultBeamGroups(score.defaults.time)
    if groups.isEmpty || groups.contains(where: { !$0.value().isFinite || $0.value() <= 0 }) {
        throw VexError("BadArguments", "Beam groups must be positive finite Fractions.")
    }
    if let secondaryBreaks = options.secondaryBreaks, Tables.durationToTicks(secondaryBreaks) == nil {
        throw VexError("BadArguments", "Invalid secondary beam break duration: \(secondaryBreaks)")
    }
    let stemPolicy: BeamStemPolicy = options.autoStem == false
        ? .preserve
        : (options.autoStem == true || options.stemDirection != nil ? .auto : .explicit)
    let config = BeamConfig(
        groups: groups.map { $0.clone() },
        stemDirection: options.stemDirection,
        beamRests: options.beamRests,
        beamMiddleOnly: options.beamMiddleOnly,
        showStemlets: options.showStemlets,
        maintainStemDirections: options.maintainStemDirections,
        flatBeams: options.flatBeams,
        flatBeamOffset: options.flatBeamOffset,
        secondaryBreaks: options.secondaryBreaks,
        stemPolicy: stemPolicy,
        feathered: options.feathered,
        frenchBeams: options.frenchBeams
    )
    return try score.build { score in
        try Beam.generateBeams(notes, config: config).map { try score.adopt($0, role: .drawable) }
    }
}
