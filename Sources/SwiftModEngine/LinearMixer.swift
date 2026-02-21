import Foundation
import SwiftModCore

public struct LinearMixer: Mixer {
    public let sampleRate: Int

    // PAL Amiga clock (period * 2 = full clock cycles)
    private static let paulaClock: Float = 7_093_789.2

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
        right: UnsafeMutableBufferPointer<Float>,
        channelCapture: [UnsafeMutableBufferPointer<Float>]? = nil
    ) {
        // Zero the output buffers
        memset(left.baseAddress!, 0, frameCount * MemoryLayout<Float>.size)
        memset(right.baseAddress!, 0, frameCount * MemoryLayout<Float>.size)

        // Zero capture buffers so non-playing channels produce silence
        if let capture = channelCapture {
            for buf in capture {
                memset(buf.baseAddress!, 0, frameCount * MemoryLayout<Float>.size)
            }
        }

        for ch in 0..<channels.count {
            guard channels[ch].playing else { continue }
            guard channels[ch].period > 0 else { continue }

            let instIndex = channels[ch].instrumentIndex
            guard instIndex < samples.count else { continue }
            let instSamples = samples[instIndex]
            let sampleIdx = channels[ch].sampleIndex
            guard sampleIdx < instSamples.count else { continue }
            let prepared = instSamples[sampleIdx]

            guard !prepared.data.isEmpty else { continue }

            // Compute sample speed: apply vibrato offset to period
            let effectivePeriod = max(channels[ch].period + channels[ch].vibratoOffset, minPeriod)
            let sampleSpeed = LinearMixer.paulaClock / (Float(effectivePeriod) * 2.0 * Float(sampleRate))

            // Apply tremolo offset to volume; compute per-channel gains
            let effectiveVolume = max(0, min(64, channels[ch].volume + channels[ch].tremoloOffset))
            let volume  = Float(effectiveVolume) / 64.0
            let panning = Float(channels[ch].panning) / 255.0
            let leftGain  = volume * (1.0 - panning) * 2.0
            let rightGain = volume * panning * 2.0

            renderChannel(
                sampleData: prepared.data,
                loop: prepared.loop,
                sampleSpeed: sampleSpeed,
                leftGain: leftGain,
                rightGain: rightGain,
                channel: &channels[ch],
                frameCount: frameCount,
                left: left,
                right: right,
                monoCapture: channelCapture.map { $0[ch] }
            )
        }
    }

    private func renderChannel(
        sampleData: [Float],
        loop: Loop?,
        sampleSpeed: Float,
        leftGain: Float,
        rightGain: Float,
        channel: inout ChannelState,
        frameCount: Int,
        left: UnsafeMutableBufferPointer<Float>,
        right: UnsafeMutableBufferPointer<Float>,
        monoCapture: UnsafeMutableBufferPointer<Float>? = nil
    ) {
        let sampleLength = sampleData.count
        let loopStart  = loop?.start ?? 0
        let loopEnd    = loop.map { $0.start + $0.length } ?? sampleLength
        let loopLength = loop?.length ?? 0
        let hasLoop    = loop != nil

        // Pre-convert loop bounds to Float so the inner loop is cast-free.
        let fLoopStart  = Float(loopStart)
        let fLoopEnd    = Float(loopEnd)
        let fLoopLength = Float(loopLength)

        var pos = channel.samplePosition

        for frame in 0..<frameCount {
            // Handle loop wrapping / end of sample
            if hasLoop {
                if pos >= fLoopEnd {
                    pos -= fLoopLength * floor((pos - fLoopStart) / fLoopLength)
                    if pos >= fLoopEnd { pos = fLoopStart }
                }
            } else if pos >= Float(sampleLength) {
                channel.playing = false
                break
            }

            // Linear interpolation
            let index = Int(pos)
            let frac  = pos - Float(index)

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

            left[frame]  += sampleValue * leftGain
            right[frame] += sampleValue * rightGain
            if let cap = monoCapture { cap[frame] = sampleValue }

            pos += sampleSpeed
        }

        channel.samplePosition = pos

        // Final position wrap for looping samples
        if hasLoop && pos >= fLoopEnd {
            channel.samplePosition -= fLoopLength * floor((pos - fLoopStart) / fLoopLength)
        }
    }
}
