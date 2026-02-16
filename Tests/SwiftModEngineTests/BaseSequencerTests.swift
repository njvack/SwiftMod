import Testing
import SwiftModCore
@testable import SwiftModEngine

// Helper to build minimal modules for testing
func makeMinimalModule(
    patterns: [Pattern] = [],
    patternOrder: [Int] = [0],
    channelCount: Int = 4,
    instruments: [Instrument] = [],
    speed: Int = 6,
    tempo: Int = 125
) -> Module {
    Module(
        title: "Test",
        formatDescription: "Test MOD",
        channelCount: channelCount,
        patternOrder: patternOrder,
        restartPosition: 0,
        patterns: patterns,
        instruments: instruments,
        initialSpeed: speed,
        initialTempo: tempo,
        formatHints: FormatHints(sourceFormat: .mod)
    )
}

func emptyRow(_ channelCount: Int) -> [Note] {
    [Note](repeating: Note(), count: channelCount)
}

func emptyPattern(rows: Int = 64, channels: Int = 4) -> Pattern {
    let row = emptyRow(channels)
    return Pattern(rowCount: rows, rows: [[Note]](repeating: row, count: rows))
}

@Test func samplesPerTickCalculation() {
    // At 125 BPM, 44100 Hz: floor(44100 * 2.5 / 125) = 882
    let spt = BaseSequencer.computeSamplesPerTick(tempo: 125, sampleRate: 44100)
    #expect(spt == 882)
}

@Test func defaultTimingValues() {
    let mod = makeMinimalModule(patterns: [emptyPattern()])
    let seq = BaseSequencer(module: mod)
    #expect(seq.speed == 6)
    #expect(seq.tempo == 125)
    #expect(seq.samplesPerTick == 882)
    #expect(seq.orderIndex == 0)
    #expect(seq.rowIndex == 0)
    #expect(seq.tick == 0)
}

@Test func noteTriggersChannel() {
    // Create a sample
    let sample = Sample(name: "test", data: .int8([Int8](repeating: 64, count: 100)), volume: 48)
    let inst = Instrument(name: "test", samples: [sample])

    // Create a pattern with a note on channel 0 at row 0
    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(period: 428, instrument: 1)  // C-3
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst])
    let seq = BaseSequencer(module: mod)

    // After init, row 0 should have been processed
    #expect(seq.channels[0].playing == true)
    #expect(seq.channels[0].period == 428)
    #expect(seq.channels[0].volume == 48)
    #expect(seq.channels[0].instrumentIndex == 0)
    #expect(seq.channels[0].samplePosition == 0.0)
}

@Test func setVolumeEffect() {
    let sample = Sample(name: "test", data: .int8([64]), volume: 48)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(period: 428, instrument: 1, effect: .setVolume(volume: 32))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst])
    let seq = BaseSequencer(module: mod)

    #expect(seq.channels[0].volume == 32)
}

@Test func setSpeedEffect() {
    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(effect: .setSpeed(speed: 3))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern])
    let seq = BaseSequencer(module: mod)

    #expect(seq.speed == 3)
}

@Test func setTempoEffect() {
    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(effect: .setTempo(bpm: 150))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern])
    let seq = BaseSequencer(module: mod)

    #expect(seq.tempo == 150)
    #expect(seq.samplesPerTick == BaseSequencer.computeSamplesPerTick(tempo: 150, sampleRate: 44100))
}

@Test func advanceTickProgressesThroughRows() {
    let pattern = emptyPattern()
    let mod = makeMinimalModule(patterns: [pattern], speed: 6)
    let seq = BaseSequencer(module: mod)

    // We start at row 0, tick 0. After 6 ticks we should be at row 1.
    for _ in 0..<6 {
        seq.advanceTick()
    }
    #expect(seq.rowIndex == 1)
    #expect(seq.tick == 0)
}

@Test func isFinishedAtEndOfOrder() {
    // One pattern with 4 rows
    let pattern = emptyPattern(rows: 4)
    let mod = makeMinimalModule(patterns: [pattern], speed: 1)
    let seq = BaseSequencer(module: mod)

    // With speed=1, each tick advances one row.
    // Row 0 is already processed. Ticks 1,2,3 advance to rows 1,2,3.
    // Tick 4 should trigger advanceOrder and finish.
    #expect(seq.isFinished == false)
    for _ in 0..<4 {
        seq.advanceTick()
    }
    #expect(seq.isFinished == true)
}

@Test func patternBreakAdvancesToNextOrder() {
    var rows1 = [[Note]](repeating: emptyRow(4), count: 64)
    rows1[0][0] = Note(effect: .patternBreak(row: 4))
    let pattern1 = Pattern(rowCount: 64, rows: rows1)
    let pattern2 = emptyPattern()

    let mod = makeMinimalModule(
        patterns: [pattern1, pattern2],
        patternOrder: [0, 1]
    )
    let seq = BaseSequencer(module: mod)

    // After init, patternBreak fires: should be at order 1, row 4
    #expect(seq.orderIndex == 1)
    #expect(seq.rowIndex == 4)
}

@Test func positionJumpMovesToOrder() {
    var rows1 = [[Note]](repeating: emptyRow(4), count: 64)
    rows1[0][0] = Note(effect: .positionJump(order: 1))
    let pattern1 = Pattern(rowCount: 64, rows: rows1)
    let pattern2 = emptyPattern()

    let mod = makeMinimalModule(
        patterns: [pattern1, pattern2],
        patternOrder: [0, 1]
    )
    let seq = BaseSequencer(module: mod)

    // positionJump fires on row 0: should be at order 1, row 0
    #expect(seq.orderIndex == 1)
    #expect(seq.rowIndex == 0)
}

// MARK: - Tick 1+ Effect Tests

@Test func slideUpReducesPeriod() {
    let sample = Sample(name: "test", data: .int8([64]), volume: 64)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(period: 428, instrument: 1, effect: .slideUp(speed: 4))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst], speed: 6)
    let seq = BaseSequencer(module: mod)

    #expect(seq.channels[0].period == 428)

    // Tick 1: period should decrease by 4
    seq.advanceTick()
    #expect(seq.channels[0].period == 424)

    // Tick 2: decrease again
    seq.advanceTick()
    #expect(seq.channels[0].period == 420)
}

@Test func volumeSlideIncreasesVolume() {
    let sample = Sample(name: "test", data: .int8([64]), volume: 32)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    // volumeSlide upDown=0x30 means slide up by 3
    rows[0][0] = Note(period: 428, instrument: 1, effect: .volumeSlide(upDown: 0x30))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst], speed: 6)
    let seq = BaseSequencer(module: mod)

    #expect(seq.channels[0].volume == 32)

    seq.advanceTick()
    #expect(seq.channels[0].volume == 35)
}

@Test func tonePortamentoSlidesTowardTarget() {
    let sample = Sample(name: "test", data: .int8([64]), volume: 64)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    // First row: set initial period
    rows[0][0] = Note(period: 428, instrument: 1)
    // Second row: tone portamento toward period 340
    rows[1][0] = Note(period: 340, effect: .tonePortamento(speed: 10))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst], speed: 6)
    let seq = BaseSequencer(module: mod)

    // Advance to row 1
    for _ in 0..<6 { seq.advanceTick() }
    // Period should still be 428 (tone porta doesn't change on tick 0)
    #expect(seq.channels[0].period == 428)
    #expect(seq.channels[0].targetPeriod == 340)

    // Tick 1 of row 1: slide down toward 340 by 10
    seq.advanceTick()
    #expect(seq.channels[0].period == 418)
}

@Test func vibratoSetsOffset() {
    let sample = Sample(name: "test", data: .int8([64]), volume: 64)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(period: 428, instrument: 1, effect: .vibrato(speed: 4, depth: 8))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst], speed: 6)
    let seq = BaseSequencer(module: mod)

    // Tick 0: vibratoOffset should be 0 (reset at row start)
    #expect(seq.channels[0].vibratoOffset == 0)
    #expect(seq.channels[0].period == 428)

    // Tick 1: vibrato applies (but sin(0)=0, so offset is 0 on first tick)
    seq.advanceTick()
    #expect(seq.channels[0].period == 428)

    // Tick 2: vibrato position has advanced, offset should now be non-zero
    seq.advanceTick()
    #expect(seq.channels[0].period == 428) // period itself unchanged
    #expect(seq.channels[0].vibratoOffset != 0) // but offset is active
}

@Test func arpeggioAlternatesPeriods() {
    let sample = Sample(name: "test", data: .int8([64]), volume: 64)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(period: 428, instrument: 1, effect: .arpeggio(x: 4, y: 7))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst], speed: 6)
    let seq = BaseSequencer(module: mod)

    let basePeriod = seq.channels[0].period
    #expect(basePeriod == 428)

    // Tick 1 (step 1%3=1): should use X semitones offset
    seq.advanceTick()
    let periodX = seq.channels[0].period
    #expect(periodX < basePeriod) // Higher pitch = lower period

    // Tick 2 (step 2%3=2): should use Y semitones offset
    seq.advanceTick()
    let periodY = seq.channels[0].period
    #expect(periodY < periodX) // 7 semitones = even lower period than 4

    // Tick 3 (step 3%3=0): back to base
    seq.advanceTick()
    #expect(seq.channels[0].period == basePeriod)
}

@Test func noteDelaySuppressesTick0Trigger() {
    let sample = Sample(name: "test", data: .int8([64]), volume: 64)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(period: 428, instrument: 1, effect: .noteDelay(tick: 3))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst], speed: 6)
    let seq = BaseSequencer(module: mod)

    // Tick 0: note should NOT have triggered yet
    #expect(seq.channels[0].playing == false)
    #expect(seq.channels[0].period == 0)

    // Ticks 1, 2: still not triggered
    seq.advanceTick()
    seq.advanceTick()
    #expect(seq.channels[0].playing == false)

    // Tick 3: note triggers
    seq.advanceTick()
    #expect(seq.channels[0].playing == true)
    #expect(seq.channels[0].period == 428)
}

@Test func arpeggioBaseDoesNotDriftAcrossRows() {
    let sample = Sample(name: "test", data: .int8([Int8](repeating: 64, count: 1000)), volume: 64)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    // Row 0: note + arpeggio
    rows[0][0] = Note(period: 428, instrument: 1, effect: .arpeggio(x: 4, y: 7))
    // Row 1: arpeggio continues (no new note)
    rows[1][0] = Note(effect: .arpeggio(x: 4, y: 7))
    // Row 2: no effect — period should return to 428
    rows[2][0] = Note()
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst], speed: 6)
    let seq = BaseSequencer(module: mod)

    // Row 0, tick 0: base period
    #expect(seq.channels[0].period == 428)
    #expect(seq.channels[0].arpeggioBasePeriod == 428)

    // Advance through row 0 (6 ticks) to row 1
    for _ in 0..<6 { seq.advanceTick() }

    // Row 1, tick 0: base period should still be 428 (not drifted)
    #expect(seq.channels[0].arpeggioBasePeriod == 428)

    // Advance through all ticks of row 1
    for _ in 1..<6 { seq.advanceTick() }
    seq.advanceTick() // move to row 2

    // Row 2: no arpeggio, period should be back to 428
    #expect(seq.channels[0].period == 428)
}

@Test func noteCutSilencesAtTick() {
    let sample = Sample(name: "test", data: .int8([64]), volume: 64)
    let inst = Instrument(name: "test", samples: [sample])

    var rows = [[Note]](repeating: emptyRow(4), count: 64)
    rows[0][0] = Note(period: 428, instrument: 1, effect: .noteCut(tick: 2))
    let pattern = Pattern(rowCount: 64, rows: rows)

    let mod = makeMinimalModule(patterns: [pattern], instruments: [inst], speed: 6)
    let seq = BaseSequencer(module: mod)

    #expect(seq.channels[0].volume == 64)

    seq.advanceTick()  // tick 1
    #expect(seq.channels[0].volume == 64)

    seq.advanceTick()  // tick 2: cut
    #expect(seq.channels[0].volume == 0)
}
