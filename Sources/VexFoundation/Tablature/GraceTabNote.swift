// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Balazs Forian-Szabo. MIT License.

import Foundation

// MARK: - GraceTabNote

/// A grace note rendered on a tab stave with reduced scale.
public final class GraceTabNote: TabNote {

    override public class var CATEGORY: String { "GraceTabNote" }

    // MARK: - Init

    public override init(_ noteStruct: TabNoteStruct, drawStem: Bool = false) {
        super.init(noteStruct, drawStem: false)

        renderOptions.yShift = 0.3
        renderOptions.scale = 0.6
        renderOptions.font = "7.5pt \(VexFont.SANS_SERIF)"

        updateWidth()
    }
}
