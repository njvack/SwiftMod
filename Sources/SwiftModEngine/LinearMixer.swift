import Foundation
import SwiftModCore

public struct LinearMixer: Mixer {
    public let sampleRate: Int

    // PAL Amiga clock (period * 2 = full clock cycles)
    private static let paulaClock: Double = 7_093_789.2

    private struct PreparedSample {
        let data: [Float]
        let loop: Loop?
    }

    /// Indexed by [instrumentIndex][sampleIndex].
    private var samples: [[PreparedSample]] = []

    public init(sampleRate: Int = 44100) {
        self.sampleRate = sampleRate
    }

    public mutating func prepare(module: Module) {
        samples = module.instruments.map { instrument in
            instrument.samples.map { sample in
                let floats: [Float]
                switch sample.data {
                case .int8(let data):
                    floats = data.map { Float($0) / 128.0 }
                case .int16(let data):
                    floats = data.map { Float($0) / 32768.0 }
                }
                return PreparedSample(data: floats, loop: sample.loop)
            }
        }
    }

    public mutating func render(
        channels: inout [ChannelState],
        frameCount: Int,
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>
    ) {
        // Zero the buffers
        memset(left.baseAddress!, 0, frameCount * MemoryLayout<Float>.size)
        memset(right.baseAddress!, 0, frameCount * MemoryLayout<Float>.size)

        for ch in 0..<channels.count {
            guard channels[ch].playing else { continue }
            guard channels[ch].period > 0 else { continue }

            let instIndex = channels[ch].instrumentIndex
            guard instIndex < samples.count else { continue }
            let instSamples = samples[instIndex]
            let sampleIdx = channels[ch].sampleIndex
            guard sampleIdx < instSamples.count else { continue }
            let prepared = instSamples[sampleIdx]

            let sampleLength = prepared.data.count
            guard sampleLength > 0 else { continue }

            // Compute sample speed: apply vibrato offset to period
            let effectivePeriod = max(channels[ch].period + channels[ch].vibratoOffset, minPeriod)
            let frequency = LinearMixer.paulaClock / (Double(effectivePeriod) * 2.0)
            let sampleSpeed = frequency / Double(sampleRate)

            // Apply tremolo offset to volume
            let effectiveVolume = max(0, min(64, channels[ch].volume + channels[ch].tremoloOffset))
            let volume = Double(effectiveVolume) / 64.0
            let panning = Double(channels[ch].panning) / 255.0
            let leftGain = Float(volume * (1.0 - panning) * 2.0)
            let rightGain = Float(volume * panning * 2.0)

            renderChannel(
                sampleData: prepared.data,
                loop: prepared.loop,
                sampleSpeed: sampleSpeed,
                leftGain: leftGain,
                rightGain: rightGain,
                channel: &channels[ch],
                frameCount: frameCount,
                left: left,
                right: right
            )
        }
    }

    private func renderChannel(
        sampleData: [Float],
        loop: Loop?,
        sampleSpeed: Double,
        leftGain: Float,
        rightGain: Float,
        channel: inout ChannelState,
        frameCount: Int,
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>
    ) {
        let sampleLength = sampleData.count
        let loopStart = loop?.start ?? 0
        let loopEnd = loop.map { $0.start + $0.length } ?? sampleLength
        let loopLength = loop?.length ?? 0
        let hasLoop = loop != nil
        var pos = channel.samplePosition

        for frame in 0..<frameCount {
            // Handle loop wrapping / end of sample
            if hasLoop {
                if pos >= Double(loopEnd) {
                    pos -= Double(loopLength) * floor((pos - Double(loopStart)) / Double(loopLength))
                    if pos >= Double(loopEnd) { pos = Double(loopStart) }
                }
            } else if pos >= Double(sampleLength) {
                channel.playing = false
                break
            }

            // Linear interpolation
            let index = Int(pos)
            let frac = Float(pos - Double(index))

            let s0 = sampleData[index]
            let s1: Float
            let nextIndex = index + 1
            if nextIndex < sampleLength {
                s1 = sampleData[nextIndex]
            } else if hasLoop {
                s1 = sampleData[loopStart]
            } else {
                s1 = s0
            }

            let sampleValue = s0 + (s1 - s0) * frac

            left[frame] += sampleValue * leftGain
            right[frame] += sampleValue * rightGain

            pos += sampleSpeed
        }

        channel.samplePosition = pos

        // Final position wrap for looping samples
        if hasLoop && channel.samplePosition >= Double(loopEnd) {
            channel.samplePosition -= Double(loopLength) * floor((channel.samplePosition - Double(loopStart)) / Double(loopLength))
        }
    }
}
