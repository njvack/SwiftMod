import Synchronization

/// Lock-free triple buffer for audio→GUI float data transfer.
///
/// The audio thread calls `append(_:)` to accumulate samples; when the internal
/// buffer fills it atomically publishes the completed buffer and reclaims the
/// previously-ready slot to write into next.
///
/// The GUI thread calls `readLatest()` to atomically swap in the most recently
/// published buffer.
///
/// - Important: `append` must only be called from a single producer (audio thread).
///   `readLatest` must only be called from a single consumer (main thread).
final class TripleBuffer: @unchecked Sendable {
    let sampleCount: Int

    // Three contiguous float arrays, allocated once — no CoW possible.
    private let storage: UnsafeMutablePointer<UnsafeMutableBufferPointer<Float>>

    // Audio thread private — no synchronization needed.
    private var writeSlot: Int = 0
    private var writeOffset: Int = 0

    // Atomic handoff between audio and GUI threads.
    // Starts at 1 so the first exchange always yields a valid (zeroed) slot.
    private let readySlot: Atomic<Int>

    // GUI thread private — no synchronization needed.
    private var readSlot: Int = 2

    init(sampleCount: Int) {
        self.sampleCount = sampleCount
        self.readySlot = Atomic<Int>(1)
        let slots = UnsafeMutablePointer<UnsafeMutableBufferPointer<Float>>.allocate(capacity: 3)
        for i in 0..<3 {
            let buf = UnsafeMutableBufferPointer<Float>.allocate(capacity: sampleCount)
            buf.initialize(repeating: 0.0)
            slots[i] = buf
        }
        storage = slots
    }

    deinit {
        for i in 0..<3 { storage[i].deallocate() }
        storage.deallocate()
    }

    // MARK: - Audio thread

    /// Append samples from the audio render callback.
    /// Automatically publishes and rotates the write slot when the buffer fills.
    func append(_ src: UnsafeBufferPointer<Float>) {
        var base = src.baseAddress!
        var remaining = src.count
        while remaining > 0 {
            let space = sampleCount - writeOffset
            let n = min(remaining, space)
            storage[writeSlot].baseAddress!
                .advanced(by: writeOffset)
                .update(from: base, count: n)
            writeOffset += n
            base = base.advanced(by: n)
            remaining -= n
            if writeOffset == sampleCount {
                writeSlot = readySlot.exchange(writeSlot, ordering: .releasing)
                writeOffset = 0
            }
        }
    }

    // MARK: - GUI thread

    /// Swap in the latest published buffer and return a pointer to it.
    /// Safe to read until the next call to `readLatest()`.
    func readLatest() -> UnsafeBufferPointer<Float> {
        readSlot = readySlot.exchange(readSlot, ordering: .acquiring)
        return UnsafeBufferPointer(storage[readSlot])
    }
}
