// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Ron B. Yeh
//
// Port of `src/typeguard.ts` (VexFlow 5.0.0).

import Foundation

/// Category labels used by VexFlow-style runtime type guard helpers.
public enum VexCategory: String, CaseIterable, Sendable {
    case accidental = "Accidental"
    case annotation = "Annotation"
    case articulation = "Articulation"
    case barline = "Barline"
    case barNote = "BarNote"
    case beam = "Beam"
    case bend = "Bend"
    case chordSymbol = "ChordSymbol"
    case clef = "Clef"
    case clefNote = "ClefNote"
    case crescendo = "Crescendo"
    case curve = "Curve"
    case dot = "Dot"
    case element = "Element"
    case flag = "Flag"
    case fraction = "Fraction"
    case fretHandFinger = "FretHandFinger"
    case ghostNote = "GhostNote"
    case glyph = "Glyph"
    case glyphNote = "GlyphNote"
    case graceNote = "GraceNote"
    case graceNoteGroup = "GraceNoteGroup"
    case graceTabNote = "GraceTabNote"
    case keySignature = "KeySignature"
    case keySigNote = "KeySigNote"
    case modifier = "Modifier"
    case multiMeasureRest = "MultiMeasureRest"
    case note = "Note"
    case noteHead = "NoteHead"
    case noteSubGroup = "NoteSubGroup"
    case ornament = "Ornament"
    case parenthesis = "Parenthesis"
    case pedalMarking = "PedalMarking"
    case renderContext = "RenderContext"
    case repeatNote = "RepeatNote"
    case repetition = "Repetition"
    case stave = "Stave"
    case staveConnector = "StaveConnector"
    case staveHairpin = "StaveHairpin"
    case staveLine = "StaveLine"
    case staveModifier = "StaveModifier"
    case staveNote = "StaveNote"
    case staveSection = "StaveSection"
    case staveTempo = "StaveTempo"
    case staveText = "StaveText"
    case staveTie = "StaveTie"
    case stem = "Stem"
    case stemmableNote = "StemmableNote"
    case stringNumber = "StringNumber"
    case stroke = "Stroke"
    case system = "System"
    case tabNote = "TabNote"
    case tabSlide = "TabSlide"
    case tabStave = "TabStave"
    case tabTie = "TabTie"
    case textBracket = "TextBracket"
    case textDynamics = "TextDynamics"
    case textNote = "TextNote"
    case tickable = "Tickable"
    case timeSignature = "TimeSignature"
    case timeSigNote = "TimeSigNote"
    case tremolo = "Tremolo"
    case tuplet = "Tuplet"
    case vibrato = "Vibrato"
    case vibratoBracket = "VibratoBracket"
    case voice = "Voice"
    case volta = "Volta"
}

/// Use instead of `is` as a more flexible type guard.
///
/// - Parameters:
///   - obj: check if the class `category` of this object matches `category`.
///   - category: a category of VexFlow objects.
///   - checkAncestors: defaults to `true`, so the superclass chain is searched
///     for a matching `category`. If `false`, only the class of `obj` is checked.
/// - Returns: true if the (static) `category` of the class of `obj` matches.
public func isCategory(_ obj: Any?, _ category: VexCategory, checkAncestors: Bool = true) -> Bool {
    guard let obj else { return false }

    // Types that are not elements.
    switch category {
    case .renderContext:
        return obj is RenderContext
    case .fraction:
        return obj is Fraction
    default:
        break
    }

    guard let element = obj as? VexElement else { return false }

    if !checkAncestors {
        return type(of: element).category == category.rawValue
    }

    // Walk up the class chain to look for a matching class `category`.
    var cls: AnyClass? = type(of: element)
    while let current = cls {
        if let elementClass = current as? VexElement.Type, elementClass.category == category.rawValue {
            return true
        }
        cls = class_getSuperclass(current)
    }
    return false
}

public func isAccidental(_ obj: Any?) -> Bool { isCategory(obj, .accidental) }
public func isAnnotation(_ obj: Any?) -> Bool { isCategory(obj, .annotation) }
public func isBarline(_ obj: Any?) -> Bool { isCategory(obj, .barline) }
public func isDot(_ obj: Any?) -> Bool { isCategory(obj, .dot) }
public func isGraceNote(_ obj: Any?) -> Bool { isCategory(obj, .graceNote) }
public func isGraceNoteGroup(_ obj: Any?) -> Bool { isCategory(obj, .graceNoteGroup) }
public func isNote(_ obj: Any?) -> Bool { isCategory(obj, .note) }
public func isRenderContext(_ obj: Any?) -> Bool { isCategory(obj, .renderContext) }
public func isStaveNote(_ obj: Any?) -> Bool { isCategory(obj, .staveNote) }
public func isStemmableNote(_ obj: Any?) -> Bool { isCategory(obj, .stemmableNote) }
public func isTabNote(_ obj: Any?) -> Bool { isCategory(obj, .tabNote) }
