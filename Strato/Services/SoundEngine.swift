import AVFoundation
import Foundation

/// Synthesised cabin ambience and announcement chimes. No audio files are bundled.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    enum Chime {
        /// Single soft tone: an announcement.
        case notice
        /// Two descending tones: seat-belt sign.
        case attention
        /// Three rising tones: arrival.
        case arrival
    }

    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    private var generator: NoiseGenerator?
    private var chimePlayer: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []
    private var fadeTask: Task<Void, Never>?
    private(set) var preset: AmbientPreset = .off

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let ended = raw == AVAudioSession.InterruptionType.ended.rawValue
            Task { @MainActor in
                guard let self, ended, self.preset != .off else { return }
                self.restart()
            }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.preset != .off else { return }
                self.restart()
            }
        })
    }

    var isPlaying: Bool { preset != .off && engine?.isRunning == true }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        // Mix with whatever the user is already listening to.
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func play(_ newPreset: AmbientPreset) {
        guard newPreset != preset || engine?.isRunning != true else { return }
        stopEngine()
        preset = newPreset
        guard newPreset != .off else {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            return
        }
        startEngine()
    }

    func stop() {
        play(.off)
    }

    private func restart() {
        let current = preset
        stopEngine()
        preset = current
        startEngine()
    }

    private func startEngine() {
        activateSession()
        let engine = AVAudioEngine()
        let hardware = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = hardware > 8000 ? hardware : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            preset = .off
            return
        }
        let generator = NoiseGenerator(preset: preset, sampleRate: sampleRate)
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            let left = buffers.count > 0 ? buffers[0].mData?.assumingMemoryBound(to: Float.self) : nil
            let right = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : nil
            for frame in 0..<Int(frameCount) {
                let sample = generator.next()
                left?[frame] = sample.0
                right?[frame] = sample.1
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0
        do {
            try engine.start()
        } catch {
            preset = .off
            return
        }
        self.engine = engine
        self.source = node
        self.generator = generator
        fade(to: 0.55, over: 1.8)
    }

    private func stopEngine() {
        fadeTask?.cancel()
        fadeTask = nil
        engine?.stop()
        if let source { engine?.detach(source) }
        engine = nil
        source = nil
        generator = nil
    }

    private func fade(to target: Float, over seconds: Double) {
        fadeTask?.cancel()
        fadeTask = Task { [weak self] in
            let steps = 24
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(seconds / Double(steps) * 1_000_000_000))
                guard !Task.isCancelled, let mixer = self?.engine?.mainMixerNode else { return }
                mixer.outputVolume = target * Float(i) / Float(steps)
            }
        }
    }

    // MARK: Chimes

    func chime(_ kind: Chime) {
        let tones: [(frequency: Double, start: Double)]
        switch kind {
        case .notice: tones = [(587.33, 0)]
        case .attention: tones = [(659.25, 0), (523.25, 0.42)]
        case .arrival: tones = [(523.25, 0), (659.25, 0.22), (783.99, 0.44)]
        }
        let data = SoundEngine.wav(tones: tones, duration: 2.0)
        if preset == .off { activateSession() }
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = 0.5
        player.prepareToPlay()
        player.play()
        chimePlayer = player
    }

    /// Renders bell-like tones (a fundamental plus two partials with exponential decay) to WAV data.
    static func wav(tones: [(frequency: Double, start: Double)], duration: Double) -> Data {
        let sampleRate = 44_100.0
        let count = Int(duration * sampleRate)
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var value = 0.0
            for tone in tones where t >= tone.start {
                let dt = t - tone.start
                let attack = min(1, dt / 0.006)
                let envelope = attack * exp(-dt * 3.2)
                let w = 2 * Double.pi * tone.frequency * dt
                value += envelope * (sin(w) + 0.32 * sin(2 * w) * exp(-dt * 2) + 0.12 * sin(3.01 * w) * exp(-dt * 4))
            }
            let clipped = max(-1, min(1, value * 0.42))
            samples[i] = Int16(clipped * 32_000)
        }
        var data = Data()
        func append<T: FixedWidthInteger>(_ v: T) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        let byteCount = UInt32(count * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36) + byteCount)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate) * 2)
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(byteCount)
        samples.withUnsafeBufferPointer { data.append(Data(buffer: $0)) }
        return data
    }
}

/// Runs on the audio render thread: no allocation, no locks, its own tiny random generator.
private final class NoiseGenerator {
    private let preset: AmbientPreset
    private let sampleRate: Double
    private var seed: UInt32 = 0x9E37_79B9
    private var brownL: Float = 0
    private var brownR: Float = 0
    private var lowL: Float = 0
    private var lowR: Float = 0
    private var highL: Float = 0
    private var highR: Float = 0
    private var phaseA = 0.0
    private var phaseB = 0.0
    private var lfo = 0.0
    private var dropLevel: Float = 0
    private var dropCountdown = 0

    init(preset: AmbientPreset, sampleRate: Double) {
        self.preset = preset
        self.sampleRate = sampleRate
    }

    @inline(__always)
    private func white() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    func next() -> (Float, Float) {
        lfo += 2 * .pi * 0.07 / sampleRate
        if lfo > 2 * .pi { lfo -= 2 * .pi }
        let swell = Float(sin(lfo))

        switch preset {
        case .off:
            return (0, 0)

        case .cabin:
            // Deep rumble (brown noise), a broad air-conditioning hiss, and a faint engine drone.
            brownL = (brownL + 0.022 * white()) * 0.996
            brownR = (brownR + 0.022 * white()) * 0.996
            lowL += 0.085 * (white() - lowL)
            lowR += 0.085 * (white() - lowR)
            phaseA += 2 * .pi * 82 / sampleRate
            phaseB += 2 * .pi * 123.5 / sampleRate
            if phaseA > 2 * .pi { phaseA -= 2 * .pi }
            if phaseB > 2 * .pi { phaseB -= 2 * .pi }
            let drone = Float(sin(phaseA)) * 0.014 + Float(sin(phaseB)) * 0.007
            let gain = 1 + 0.06 * swell
            let l = (brownL * 1.9 + lowL * 0.11 + drone) * gain
            let r = (brownR * 1.9 + lowR * 0.11 + drone) * gain
            return (l * 0.75 + r * 0.25, r * 0.75 + l * 0.25)

        case .wind:
            // Airflow over the fuselage: noise through a filter whose cutoff drifts slowly.
            let cutoff = 0.05 + 0.03 * (swell + 1)
            lowL += cutoff * (white() - lowL)
            lowR += cutoff * (white() - lowR)
            brownL = (brownL + 0.012 * white()) * 0.997
            brownR = (brownR + 0.012 * white()) * 0.997
            let gain = 0.75 + 0.25 * swell
            return ((lowL * 0.5 + brownL * 0.9) * gain, (lowR * 0.5 + brownR * 0.9) * gain)

        case .rain:
            // Steady rain (high-passed noise) with occasional heavier drops on the window.
            let wl = white(), wr = white()
            highL += 0.35 * (wl - highL)
            highR += 0.35 * (wr - highR)
            lowL += 0.02 * (wl - lowL)
            lowR += 0.02 * (wr - lowR)
            dropCountdown -= 1
            if dropCountdown <= 0 {
                dropCountdown = Int(sampleRate * Double(0.02 + 0.16 * abs(white())))
                dropLevel = 0.5 + 0.5 * abs(white())
            }
            dropLevel *= 0.9965
            let drops = white() * dropLevel * 0.05
            let l = (wl - highL) * 0.085 + lowL * 0.5 + drops
            let r = (wr - highR) * 0.085 + lowR * 0.5 + drops * 0.6
            return (l, r)
        }
    }
}
