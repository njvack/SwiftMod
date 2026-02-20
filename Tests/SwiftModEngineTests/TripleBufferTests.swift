import Foundation
import Testing
import Synchronization
@testable import SwiftModEngine

// MARK: - Functional

@Test func tripleBufferDeliversData() {
    // Single-threaded sanity check: data written by the producer is readable.
    let buf = TripleBuffer(sampleCount: 8)
    var src = [Float](repeating: 0.0, count: 8)

    // Nothing published yet — readLatest should return the zeroed slot.
    let empty = buf.readLatest()
    #expect(empty.allSatisfy { $0 == 0.0 })

    // Publish one full buffer worth of 1.0s.
    for i in 0..<8 { src[i] = 1.0 }
    src.withUnsafeBufferPointer { buf.append($0) }

    let latest = buf.readLatest()
    #expect(latest.allSatisfy { $0 == 1.0 })
}

@Test func tripleBufferAccumulatesAcrossMultipleAppends() {
    // append() with a count smaller than sampleCount should accumulate
    // across calls before publishing.
    let buf = TripleBuffer(sampleCount: 8)

    // Four appends of 2 samples each = one full 8-sample buffer.
    let chunk = [Float](repeating: 7.0, count: 2)
    chunk.withUnsafeBufferPointer { ptr in
        for _ in 0..<4 { buf.append(ptr) }
    }

    // Now one buffer should have been published.
    // A second 8-sample read should still see all 7.0s (the ready slot).
    let latest = buf.readLatest()
    #expect(latest.allSatisfy { $0 == 7.0 })
}

// MARK: - Concurrency stress test

@Test func tripleBufferNeverExposesPartialWrite() {
    // The core concurrency invariant: every buffer returned by readLatest()
    // must be internally uniform — the producer always writes the same float
    // to every frame, so a torn read would show mixed values.
    //
    // Using DispatchGroup + concurrent queue gives us real OS-thread parallelism.
    // The failure flag uses Atomic<Bool> to avoid a data race in the test itself.

    let sampleCount = 16   // small so publishBuffer() fires frequently
    let iterations  = 100_000
    let buf = TripleBuffer(sampleCount: sampleCount)
    let hadTornRead = Atomic<Bool>(false)

    let group = DispatchGroup()

    // Producer: repeatedly fills and publishes uniform buffers.
    DispatchQueue.global().async(group: group) {
        var src = [Float](repeating: 0.0, count: sampleCount)
        for i in 0..<iterations {
            let value = Float(i & 0xFF)
            for j in 0..<sampleCount { src[j] = value }
            src.withUnsafeBufferPointer { buf.append($0) }
        }
    }

    // Consumer: reads and checks uniformity on every call.
    DispatchQueue.global().async(group: group) {
        for _ in 0..<iterations {
            let latest = buf.readLatest()
            let first = latest[0]
            if latest.dropFirst().contains(where: { $0 != first }) {
                hadTornRead.store(true, ordering: .relaxed)
            }
        }
    }

    group.wait()
    let torn = hadTornRead.load(ordering: .relaxed)
    #expect(!torn)
}
