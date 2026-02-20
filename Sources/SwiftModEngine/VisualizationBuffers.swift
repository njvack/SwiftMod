/// Triple-buffered visualization data populated by the audio render thread.
///
/// Create one instance and set it on `ModuleRenderer.vizBuffers`; the renderer
/// feeds it automatically during playback. Read from the GUI thread via the
/// `readLatest*` methods.
public final class VisualizationBuffers: @unchecked Sendable {
    public let channelCount: Int
    public let sampleCount: Int

    private let channelBuffers: [TripleBuffer]
    private let leftBuffer: TripleBuffer
    private let rightBuffer: TripleBuffer
    private let monoBuffer: TripleBuffer

    // Scratch for computing mono from L+R (audio thread only, resizes if needed).
    private var monoScratch: UnsafeMutableBufferPointer<Float>

    public init(channelCount: Int, sampleCount: Int = 2048) {
        self.channelCount = channelCount
        self.sampleCount = sampleCount
        channelBuffers = (0..<channelCount).map { _ in TripleBuffer(sampleCount: sampleCount) }
        leftBuffer  = TripleBuffer(sampleCount: sampleCount)
        rightBuffer = TripleBuffer(sampleCount: sampleCount)
        monoBuffer  = TripleBuffer(sampleCount: sampleCount)
        monoScratch = UnsafeMutableBufferPointer<Float>.allocate(capacity: 512)
        monoScratch.initialize(repeating: 0.0)
    }

    deinit {
        monoScratch.deallocate()
    }

    // MARK: - Audio thread

    func appendChannel(_ src: UnsafeBufferPointer<Float>, index: Int) {
        guard index < channelCount else { return }
        channelBuffers[index].append(src)
    }

    func appendStereo(left: UnsafeBufferPointer<Float>, right: UnsafeBufferPointer<Float>) {
        leftBuffer.append(left)
        rightBuffer.append(right)

        let n = left.count
        if monoScratch.count < n {
            monoScratch.deallocate()
            monoScratch = UnsafeMutableBufferPointer<Float>.allocate(capacity: n)
            monoScratch.initialize(repeating: 0.0)
        }
        for i in 0..<n {
            monoScratch[i] = (left[i] + right[i]) * 0.5
        }
        monoBuffer.append(UnsafeBufferPointer(start: monoScratch.baseAddress, count: n))
    }

    // MARK: - GUI thread

    public func readLatestLeft()  -> UnsafeBufferPointer<Float> { leftBuffer.readLatest() }
    public func readLatestRight() -> UnsafeBufferPointer<Float> { rightBuffer.readLatest() }
    public func readLatestMono()  -> UnsafeBufferPointer<Float> { monoBuffer.readLatest() }

    public func readLatestChannel(_ index: Int) -> UnsafeBufferPointer<Float> {
        channelBuffers[index].readLatest()
    }
}
