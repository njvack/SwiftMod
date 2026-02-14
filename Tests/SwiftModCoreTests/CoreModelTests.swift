import Testing
@testable import SwiftModCore

@Test func moduleConstruction() {
    let module = Module(
        title: "Test",
        formatDescription: "Test Format",
        channelCount: 4,
        patternOrder: [0, 1],
        restartPosition: 0,
        patterns: [Pattern(rowCount: 64, rows: [])],
        instruments: [],
        formatHints: FormatHints(sourceFormat: .mod)
    )

    #expect(module.title == "Test")
    #expect(module.channelCount == 4)
    #expect(module.initialSpeed == 6)
    #expect(module.initialTempo == 125)
    #expect(module.initialGlobalVolume == 64)
}

@Test func sampleDefaults() {
    let sample = Sample(name: "kick")
    #expect(sample.volume == 64)
    #expect(sample.sampleRate == 8363)
    #expect(sample.finetune == 0)
    #expect(sample.loop == nil)
    #expect(sample.data.frameCount == 0)
}

@Test func instrumentDefaults() {
    let inst = Instrument(name: "piano", samples: [])
    #expect(inst.newNoteAction == .cut)
    #expect(inst.duplicateCheckType == .none)
    #expect(inst.volumeEnvelope == nil)
    #expect(inst.fadeOut == 0)
}
