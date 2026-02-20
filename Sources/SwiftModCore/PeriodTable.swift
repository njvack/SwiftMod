// Base ProTracker period table: 16 finetune values x 12 notes (1 octave, octave 0).
// This is the middle octave of the standard 3-octave table. Extended octaves are
// computed by doubling (lower) or halving (higher) these values.
//
// Finetune 0 is at index 0, finetune 1 at index 1, ..., finetune -1 (=15) at index 15
private let basePeriodTable: [[Int]] = [
    // Finetune 0
    [856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453],
    // Finetune 1
    [850, 802, 757, 715, 674, 637, 601, 567, 535, 505, 477, 450],
    // Finetune 2
    [844, 796, 752, 709, 670, 632, 597, 563, 532, 501, 474, 447],
    // Finetune 3
    [838, 791, 746, 704, 665, 628, 592, 559, 528, 498, 470, 444],
    // Finetune 4
    [832, 785, 741, 699, 660, 623, 588, 555, 524, 494, 467, 441],
    // Finetune 5
    [826, 779, 736, 694, 655, 619, 584, 551, 520, 491, 463, 437],
    // Finetune 6
    [820, 774, 730, 689, 651, 614, 580, 547, 516, 487, 460, 434],
    // Finetune 7
    [814, 768, 725, 684, 646, 610, 575, 543, 513, 484, 457, 431],
    // Finetune -8
    [907, 856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480],
    // Finetune -7
    [900, 850, 802, 757, 715, 675, 636, 601, 567, 535, 505, 477],
    // Finetune -6
    [894, 844, 796, 752, 709, 670, 632, 597, 563, 532, 501, 474],
    // Finetune -5
    [887, 838, 791, 746, 704, 665, 628, 592, 559, 528, 498, 470],
    // Finetune -4
    [881, 832, 785, 741, 699, 660, 623, 588, 555, 524, 495, 467],
    // Finetune -3
    [875, 826, 779, 736, 694, 655, 619, 584, 551, 520, 491, 463],
    // Finetune -2
    [868, 820, 774, 730, 689, 651, 614, 580, 547, 516, 487, 460],
    // Finetune -1
    [862, 814, 768, 725, 684, 646, 610, 575, 543, 513, 484, 457],
]

/// Number of octaves in the extended period table.
/// Octave 0 is the base (lowest pitch / highest periods), with each subsequent
/// octave halving the periods. 7 octaves = 84 notes (C-0 through B-6 in tracker
/// notation), matching common extended-octave MOD players.
public let periodTableOctaves = 7

/// Extended period table: 16 finetune values x (12 * periodTableOctaves) notes.
/// Computed from the base 1-octave table by doubling/halving for other octaves.
/// The base table values land in octave 0 (the lowest). Higher octaves are
/// successive halvings.
public let periodTable: [[Int]] = {
    basePeriodTable.map { baseOctave in
        (0..<periodTableOctaves).flatMap { octave in
            let shift = octave  // 0 = base, 1 = halved once, etc.
            return baseOctave.map { $0 >> shift }
        }
    }
}()

/// Minimum period value (highest pitch). Derived from the extended table at finetune 0.
public let minPeriod: Int = periodTable[0].last ?? 7

/// Maximum period value (lowest pitch). Derived from the extended table at finetune 0.
public let maxPeriod: Int = periodTable[0].first ?? 856

/// Convert a finetune nibble (0-15) from a MOD file to our period table index.
/// MOD stores finetune as unsigned 0-15 where 0=0, 1=+1, ..., 7=+7, 8=-8, ..., 15=-1.
/// Our table is ordered: [0, 1, 2, ..., 7, -8, -7, ..., -1] which matches MOD order directly.
public func finetuneToTableIndex(_ finetune: Int) -> Int {
    return finetune & 0x0F
}

/// Convert a finetune nibble (0-15 unsigned) to signed (-8..+7) for storage in Sample.
public func finetuneToSigned(_ finetune: Int) -> Int {
    let ft = finetune & 0x0F
    return ft < 8 ? ft : ft - 16
}

/// Look up the closest note for a given period value at a given finetune.
/// Returns a MIDI-style note number (0 = C-0) or nil if no match.
public func periodToNote(period: Int, finetune: Int = 0) -> NoteValue? {
    guard period > 0 else { return nil }

    let tableIndex = finetuneToTableIndex(finetune)
    let table = periodTable[tableIndex]

    // Find closest match
    var bestDist = Int.max
    var bestNote = 0

    for (i, p) in table.enumerated() {
        let dist = abs(period - p)
        if dist < bestDist {
            bestDist = dist
            bestNote = i
        }
    }

    // MOD period table starts at C-1 in tracker notation, which we map to MIDI-like note numbers.
    // Octave 1 in MOD = notes 0-11 in our system (C-1=0, C#1=1, ..., B-1=11)
    // So table index maps directly to note number.
    return .note(bestNote)
}
