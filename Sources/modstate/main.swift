import Foundation
import SwiftModCore
import SwiftModFormats
import SwiftModEngine
import ModCLI

// MARK: - Argument parsing

let cli = CLIArgs.parse(usage: """
    Usage: modstate <input.mod> [--start-order N] [--end-order N] [--start-row N] [--end-row N]

    Dumps sequencer channel state one line per tick to stdout.
    Playback always starts from order 0; --start-order/row fast-forwards silently.
    """)

let inputPath  = cli.inputPath
let startOrder = cli.startOrder
let endOrder   = cli.endOrder
let startRow   = cli.startRow
let endRow     = cli.endRow

// MARK: - Load and run

let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
let module = try MODLoader.load(data)
let sequencer = BaseSequencer(module: module, sampleRate: 44100)

// MARK: - State formatting

func formatState() -> String {
    let header = String(format: "ORD=%03d ROW=%02d TIC=%02d BPM=%03d SPD=%02d",
        sequencer.orderIndex, sequencer.rowIndex, sequencer.tick,
        sequencer.tempo, sequencer.speed)

    // Look up the current row's notes for effect display (tick-0 effect persists all row)
    let patternIndex = module.patternOrder[sequencer.orderIndex]
    let row = module.patterns[patternIndex].rows[sequencer.rowIndex]

    let channelFields = sequencer.channels.enumerated().map { (ci, ch) -> String in
        // Sequencer register state — period and volume as currently stored.
        // Note: vol stays at its last set value even after a non-looping sample
        // finishes. libxmp reports 0 in that case (mixer output level); we report
        // the stored register value, which matches actual Amiga hardware behavior.
        let effectivePeriod = max(0, ch.period + ch.vibratoOffset)
        let effectiveVolume = max(0, min(64, ch.volume + ch.tremoloOffset))
        // smp: show 0 for channels that have never been triggered (playing=false, period=0)
        let smp = ch.playing || ch.period > 0 ? ch.instrumentIndex + 1 : 0
        // Effect: use raw bytes stored on the note for exact hex representation
        let note = ci < row.count ? row[ci] : Note()
        let fx: String
        if let eff = note.rawEffect, let prm = note.rawEffectParam, eff != 0 || prm != 0 {
            fx = String(format: "%X%02X", eff, prm)
        } else {
            fx = "---"
        }
        return String(format: "CH%02d:per=%04d vol=%02d smp=%02d pan=%03d fx=%@",
            ci, effectivePeriod, effectiveVolume, smp, ch.panning, fx)
    }.joined(separator: "  ")

    return "\(header)  \(channelFields)"
}

// MARK: - Main loop

struct VisitedPosition: Hashable, Sendable {
    let order: Int
    let row: Int
}

var visited = Set<VisitedPosition>()
var prevOrder = -1
var prevRow = -1

while !sequencer.isFinished {
    let curOrder = sequencer.orderIndex
    let curRow = sequencer.rowIndex

    // Loop detection: stop when we revisit an order+row we've already output
    if curOrder != prevOrder || curRow != prevRow {
        let pos = VisitedPosition(order: curOrder, row: curRow)
        if visited.contains(pos) { break }
        visited.insert(pos)
        prevOrder = curOrder
        prevRow = curRow
    }

    // End range: stop after this order+row
    if curOrder > endOrder || (curOrder == endOrder && curRow > endRow) { break }

    // Print if at or past the start range
    if curOrder > startOrder || (curOrder == startOrder && curRow >= startRow) {
        print(formatState())
    }

    sequencer.advanceTick()
}
