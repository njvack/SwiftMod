import Testing
import Foundation
@testable import SwiftModFormats
@testable import SwiftModCore

// Path to sample_mods relative to the package root
private let sampleModsPath: String = {
    // Navigate from src/SwiftMod/ up to repo root, then into sample_mods/
    let thisFile = #filePath
    // thisFile = .../src/SwiftMod/Tests/SwiftModFormatsTests/MODLoaderTests.swift
    let packageDir = URL(fileURLWithPath: thisFile)
        .deletingLastPathComponent()  // SwiftModFormatsTests/
        .deletingLastPathComponent()  // Tests/
        .deletingLastPathComponent()  // SwiftMod/
        .deletingLastPathComponent()  // src/
        .deletingLastPathComponent()  // repo root
    return packageDir.appendingPathComponent("sample_mods").path
}()

@Test func loadAXELF() throws {
    let url = URL(fileURLWithPath: sampleModsPath).appendingPathComponent("AXELF.MOD")
    let data = try Data(contentsOf: url)

    let module = try MODLoader.load(data)

    #expect(module.channelCount == 4)
    #expect(module.title == "gliniarz")
    #expect(module.formatDescription.contains("M.K."))
    #expect(!module.patterns.isEmpty)
    #expect(module.instruments.count == 31)
    #expect(module.patternOrder.count > 0)
    #expect(module.initialSpeed == 6)
    #expect(module.initialTempo == 125)
}

@Test func identifyMOD() throws {
    let url = URL(fileURLWithPath: sampleModsPath).appendingPathComponent("AXELF.MOD")
    let data = try Data(contentsOf: url)

    let score = MODLoader.identify(data)
    #expect(score == 100)

    // Non-MOD data should score 0
    let garbage = Data(repeating: 0, count: 100)
    #expect(MODLoader.identify(garbage) == 0)
}

@Test func allMODFilesParseWithoutCrashing() throws {
    let fm = FileManager.default
    let contents = try fm.contentsOfDirectory(atPath: sampleModsPath)
    let modFiles = contents.filter { $0.uppercased().hasSuffix(".MOD") }.sorted()

    #expect(modFiles.count >= 100, "Expected at least 100 .MOD files in sample_mods/")

    var successCount = 0
    var failedFiles: [String] = []

    for file in modFiles {
        let url = URL(fileURLWithPath: sampleModsPath).appendingPathComponent(file)
        let data = try Data(contentsOf: url)

        // Only attempt to parse files we identify as MOD
        guard MODLoader.identify(data) > 0 else { continue }

        do {
            let module = try MODLoader.load(data)
            #expect(module.channelCount > 0)
            #expect(!module.patterns.isEmpty)
            successCount += 1
        } catch {
            failedFiles.append("\(file): \(error)")
        }
    }

    #expect(failedFiles.isEmpty, "Failed to parse: \(failedFiles.joined(separator: ", "))")
    #expect(successCount > 0, "Should have parsed at least some MOD files")
}

@Test func periodToNoteLookup() {
    // C-1 at finetune 0 = period 856
    let c1 = periodToNote(period: 856, finetune: 0)
    #expect(c1 == .note(0))

    // A-1 at finetune 0 = period 508
    let a1 = periodToNote(period: 508, finetune: 0)
    #expect(a1 == .note(9))

    // C-2 at finetune 0 = period 428
    let c2 = periodToNote(period: 428, finetune: 0)
    #expect(c2 == .note(12))

    // C-3 at finetune 0 = period 214
    let c3 = periodToNote(period: 214, finetune: 0)
    #expect(c3 == .note(24))

    // Period 0 = no note
    let none = periodToNote(period: 0, finetune: 0)
    #expect(none == nil)
}

@Test func finetuneConversion() {
    #expect(finetuneToSigned(0) == 0)
    #expect(finetuneToSigned(1) == 1)
    #expect(finetuneToSigned(7) == 7)
    #expect(finetuneToSigned(8) == -8)
    #expect(finetuneToSigned(15) == -1)
}
