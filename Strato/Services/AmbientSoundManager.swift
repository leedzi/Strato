import Foundation
import AVFoundation

public enum CabinAudioPreset: String, CaseIterable, Identifiable, Sendable {
    case off = "静音"
    case a350Cabin = "A350 巡航机舱"
    case stratosphereWind = "平流层高空气流"
    case vhfAtcHum = "VHF 塔台无线电底噪"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .off: return "speaker.slash.fill"
        case .a350Cabin: return "waveform.circle.fill"
        case .stratosphereWind: return "wind.circle.fill"
        case .vhfAtcHum: return "antenna.radiowaves.left.and.right.circle.fill"
        }
    }
}

/// Synthesizes multi-mode aviation focus soundscapes in real time using AVAudioEngine.
@MainActor
final class AmbientSoundManager {
    static let shared = AmbientSoundManager()

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private(set) var currentPreset: CabinAudioPreset = .off

    var isPlaying: Bool {
        currentPreset != .off
    }

    func cyclePreset() -> CabinAudioPreset {
        let all = CabinAudioPreset.allCases
        let currentIndex = all.firstIndex(of: currentPreset) ?? 0
        let next = all[(currentIndex + 1) % all.count]
        setPreset(next)
        return next
    }

    func setPreset(_ preset: CabinAudioPreset) {
        stop()
        guard preset != .off else {
            currentPreset = .off
            return
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44_100

        var lp1: Float = 0.0
        var lp2: Float = 0.0
        var phase1: Double = 0.0
        var phase2: Double = 0.0
        var squelchCounter: Int = 0

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                var sample: Float = 0.0

                switch preset {
                case .off:
                    sample = 0.0

                case .a350Cabin:
                    // Deep warm cabin pressurization & twin Rolls-Royce Trent XWB hum
                    lp1 = (lp1 + 0.038 * white) / 1.038
                    lp2 = (lp2 + 0.015 * lp1) / 1.015
                    phase1 += (2.0 * Double.pi * 68.0) / sampleRate
                    phase2 += (2.0 * Double.pi * 136.0) / sampleRate
                    if phase1 > 2.0 * Double.pi { phase1 -= 2.0 * Double.pi }
                    if phase2 > 2.0 * Double.pi { phase2 -= 2.0 * Double.pi }
                    let turbine = Float(sin(phase1)) * 0.022 + Float(sin(phase2)) * 0.009
                    sample = (lp2 * 0.42) + turbine

                case .stratosphereWind:
                    // Airy FL380 wind rush across cockpit windshield
                    lp1 = (lp1 + 0.085 * white) / 1.085
                    phase1 += (2.0 * Double.pi * 0.18) / sampleRate
                    if phase1 > 2.0 * Double.pi { phase1 -= 2.0 * Double.pi }
                    let swell = 0.75 + 0.25 * Float(sin(phase1))
                    sample = lp1 * 0.28 * swell

                case .vhfAtcHum:
                    // Subtle VHF radio carrier floor with occasional gentle squelch tick
                    lp1 = (lp1 + 0.14 * white) / 1.14
                    squelchCounter += 1
                    let carrierOpen = (squelchCounter % Int(sampleRate * 9)) < Int(sampleRate * 1.4)
                    let gain: Float = carrierOpen ? 0.14 : 0.06
                    sample = lp1 * gain
                }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.38

        do {
            try engine.start()
            self.engine = engine
            self.sourceNode = node
            self.currentPreset = preset
        } catch {
            self.currentPreset = .off
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        sourceNode = nil
        currentPreset = .off
    }
}
