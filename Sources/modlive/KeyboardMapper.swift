import SwiftModFormats

enum KeyboardMapper {
    // Maps macOS virtual key codes to semitone offsets from the base octave.
    // GarageBand-style layout: bottom row = white keys, top row = black keys.
    //   A=C  W=C#  S=D  E=D#  D=E  F=F  T=F#  G=G  Y=G#  H=A  U=A#  J=B
    //   K=C+1  O=C#+1  L=D+1  P=D#+1  ;=E+1  '=F+1
    private static let keyCodeToSemitone: [UInt16: Int] = [
        0x00: 0,   // A  -> C
        0x0D: 1,   // W  -> C#
        0x01: 2,   // S  -> D
        0x0E: 3,   // E  -> D#
        0x02: 4,   // D  -> E
        0x03: 5,   // F  -> F
        0x11: 6,   // T  -> F#
        0x05: 7,   // G  -> G
        0x10: 8,   // Y  -> G#
        0x04: 9,   // H  -> A
        0x20: 10,  // U  -> A#
        0x26: 11,  // J  -> B
        0x28: 12,  // K  -> C+1
        0x1F: 13,  // O  -> C#+1
        0x25: 14,  // L  -> D+1
        0x23: 15,  // P  -> D#+1
        0x29: 16,  // ;  -> E+1
        0x27: 17,  // '  -> F+1
    ]

    /// Z key code for octave down
    static let octaveDownKeyCode: UInt16 = 0x06
    /// X key code for octave up
    static let octaveUpKeyCode: UInt16 = 0x07

    /// Returns the Amiga period for a given key code, octave, and finetune.
    /// - Parameters:
    ///   - keyCode: macOS virtual key code
    ///   - octave: Base octave (0-2 for MOD's 3 octaves)
    ///   - finetune: Sample finetune value (0-15, matching period table index)
    /// - Returns: Amiga period value, or nil if the key doesn't map to a note
    ///           or the resulting note is out of range.
    static func periodForKeyCode(_ keyCode: UInt16, octave: Int, finetune: Int = 0) -> Int? {
        guard let semitone = keyCodeToSemitone[keyCode] else { return nil }

        let noteIndex = octave * 12 + semitone
        let tableIndex = finetune & 0x0F
        let table = periodTable[tableIndex]

        guard noteIndex >= 0, noteIndex < table.count else { return nil }
        return table[noteIndex]
    }

    /// Returns the note name for a semitone offset (for display).
    static func noteNameForKeyCode(_ keyCode: UInt16) -> String? {
        guard let semitone = keyCodeToSemitone[keyCode] else { return nil }
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
                     "C", "C#", "D", "D#", "E", "F"]
        guard semitone < names.count else { return nil }
        return names[semitone]
    }
}
