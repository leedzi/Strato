import Foundation
import AVFoundation

/// Synthesizes soft stratospheric cabin white noise in real time using AVAudioEngine.
/// Requires zero bundled audio files and mixes cleanly with other audio.
@MainActor
final class AmbientSoundManager {
    static let shared = AmbientSoundManager()

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private(set) var isPlaying: Bool = false

    func toggle() -> Bool {
        if isPlaying {
            stop()
        } else {
            start()
        }
        return isPlaying
    }

    func start() {
        guard !isPlaying else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44_100

        // Simple warm low-pass filtered brown/pink cabin hum state
        var lastOut: Float = 0.0
        var phase: Double = 0.0
        let humFreq = 72.0 // subtle cabin engine resonance

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                // Warm low-pass filter for aircraft cabin air swoosh
                lastOut = (lastOut + (0.045 * white)) / 1.045
                phase += (2.0 * Double.pi * humFreq) / sampleRate
                if phase > 2.0 * Double.pi { phase -= 2.0 * Double.pi }
                let turbineHum = Float(sin(phase)) * 0.018
                let sample = (lastOut * 0.32) + turbineHum

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.35

        do {
            try engine.start()
            self.engine = engine
            self.sourceNode = node
            self.isPlaying = true
        } catch {
            self.isPlaying = false
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        sourceNode = nil
        isPlaying = false
    }
}
