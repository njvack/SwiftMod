import Foundation
import SwiftModCore

public struct LinearMixer: Mixer {
    public let sampleRate: Int

    // PAL Amiga clock (period * 2 = full clock cycles)
    private static let paulaClock: Double = 7_093_789.2

    public init(sampleRate: Int = 44100) {
        self.sampleRate = sampleRate
    }

    public mutating func render(
        channels: inout [ChannelState],
        module: Module,
        frameCount: Int,
        into buffer: UnsafeMutableBufferPointer<Float>
    ) {
        // Zero the buffer
        memset(buffer.baseAddress!, 0, frameCount * 2 * MemoryLayout<Float>.size)

        for ch in 0..<channels.count {
            guard channels[ch].playing else { continue }
            guard channels[ch].period > 0 else { continue }

            let instIndex = channels[ch].instrumentIndex
            guard instIndex < module.instruments.count else { continue }
            let instrument = module.instruments[instIndex]
            let sampleIdx = channels[ch].sampleIndex
            guard sampleIdx < instrument.samples.count else { continue }
            let sample = instrument.samples[sampleIdx]

            let sampleLength = sample.data.frameCount
            guard sampleLength > 0 else { continue }

            // Compute sample speed: apply vibrato offset to period
            let effectivePeriod = max(channels[ch].period + channels[ch].vibratoOffset, 113)
            let frequency = LinearMixer.paulaClock / (Double(effectivePeriod) * 2.0)
            let sampleSpeed = frequency / Double(sampleRate)

            // Apply tremolo offset to volume
            let effectiveVolume = max(0, min(64, channels[ch].volume + channels[ch].tremoloOffset))
            let volume = Double(effectiveVolume) / 64.0
            let panning = Double(channels[ch].panning) / 255.0
            let leftGain = Float(volume * (1.0 - panning) * 2.0)
            let rightGain = Float(volume * panning * 2.0)

            // Access sample data without copying the array
            switch sample.data {
            case .int8(let sampleData):
                sampleData.withUnsafeBufferPointer { samplePtr in
                    renderChannel(
                        samplePtr: samplePtr,
                        sampleLength: sampleLength,
                        loop: sample.loop,
                        sampleSpeed: sampleSpeed,
                        leftGain: leftGain,
                        rightGain: rightGain,
                        channel: &channels[ch],
                        frameCount: frameCount,
                        buffer: buffer
                    )
                }
            case .int16:
                continue
            }
        }
    }

    private func renderChannel(
        samplePtr: UnsafeBufferPointer<Int8>,
        sampleLength: Int,
        loop: Loop?,
        sampleSpeed: Double,
        leftGain: Float,
        rightGain: Float,
        channel: inout ChannelState,
        frameCount: Int,
        buffer: UnsafeMutableBufferPointer<Float>
    ) {
        let loopStart = loop?.start ?? 0
        let loopEnd = loop.map { $0.start + $0.length } ?? sampleLength
        let loopLength = loop?.length ?? 0
        let hasLoop = loop != nil
        var pos = channel.samplePosition
        let base = samplePtr.baseAddress!

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

            let s0 = Float(base[index]) / 128.0
            let s1: Float
            let nextIndex = index + 1
            if nextIndex < sampleLength {
                s1 = Float(base[nextIndex]) / 128.0
            } else if hasLoop {
                s1 = Float(base[loopStart]) / 128.0
            } else {
                s1 = s0
            }

            let sampleValue = s0 + (s1 - s0) * frac

            buffer[frame &* 2] += sampleValue * leftGain
            buffer[frame &* 2 &+ 1] += sampleValue * rightGain

            pos += sampleSpeed
        }

        channel.samplePosition = pos

        // Final position wrap for looping samples
        if hasLoop && channel.samplePosition >= Double(loopEnd) {
            channel.samplePosition -= Double(loopLength) * floor((channel.samplePosition - Double(loopStart)) / Double(loopLength))
        }
    }
}
