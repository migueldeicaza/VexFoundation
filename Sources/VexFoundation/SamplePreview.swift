// VexFoundation - Sample preview demonstrating the Factory/EasyScore/System API.

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Two-Voice Stave", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 200) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)
        let score = f.EasyScore()
        let system = f.System(options: SystemOptions(factory: f))

        // Create a 4/4 treble stave and add two parallel voices.
        _ = system.addStave(SystemStave(
            voices: [
                // Top voice has 4 quarter notes with stems up.
                score.voice(score.notes("C#5/q, B4, A4, G#4", options: ["stem": "up"])),

                // Bottom voice has two half notes, with stems down.
                score.voice(score.notes("C#4/h, C#4", options: ["stem": "down"]))
            ]
        ))
            .addClef(.treble)
            //TODO: this is ugly to use: .addTimeSignature(.numeric(top: TimeSignatureDigits(parsing: "4")!, bottom: TimeSignatureDigits(parsing: "3"))!)
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
