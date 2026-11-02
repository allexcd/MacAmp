import AppKit
import AVFoundation
import SFBAudioEngine
#if canImport(MacAmpCore)
import MacAmpCore
#endif

final class Spectrum: @unchecked Sendable {
    private let lock = NSLock()
    private var values = Array(repeating: Float(0), count: 20)
    func read() -> [Float] { lock.lock(); defer { lock.unlock() }; return values }
    // Log-spaced Goertzel filters run on the audio analysis queue, never on the main thread.
    func analyze(_ samples: [Float], rate: Double) {
        let result = (0..<20).map { band -> Float in
            let frequency = 55 * pow(1.34, Double(band))
            let coefficient = Float(2 * cos(2 * .pi * frequency / rate))
            var a: Float = 0; var b: Float = 0
            for (i, sample) in samples.enumerated() {
                let window = Float(0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(samples.count)))
                let c = sample * window + coefficient * a - b; b = a; a = c
            }
            let power = max(0, a*a + b*b - coefficient*a*b)
            return min(1, max(0, (20 * log10(sqrt(power) / Float(samples.count) + 0.00001) + 75) / 65))
        }
        lock.lock(); values = result; lock.unlock()
    }
}
final class Playback: NSObject, AudioPlayer.Delegate {
    let player = AudioPlayer()
    let eq = AVAudioUnitEQ(numberOfBands: 10)
    let spectrum = Spectrum()
    let analysisSlot = DispatchSemaphore(value: 1)
    let analysis = DispatchQueue(label: "MacAmp.spectrum", qos: .utility)
    var onEnd: (() -> Void)?
    var onError: ((String) -> Void)?
    static let frequencies: [Float] = [31,62,125,250,500,1000,2000,4000,8000,16000]
    override init() {
        super.init(); player.delegate = self
        for (i, band) in eq.bands.enumerated() { band.filterType = .parametric; band.frequency = Self.frequencies[i]; band.bandwidth = 1; band.bypass = false }
        player.modifyProcessingGraph { engine in
            engine.attach(self.eq)
            let format = self.player.sourceNode.outputFormat(forBus: 0)
            engine.disconnectNodeOutput(self.player.sourceNode)
            engine.connect(self.player.sourceNode, to: self.eq, format: format)
            engine.connect(self.eq, to: engine.mainMixerNode, format: format)
        }
        player.mainMixerNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            guard let self, let data = buffer.floatChannelData?[0], self.analysisSlot.wait(timeout: .now()) == .success else { return }
            let samples = Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
            let rate = buffer.format.sampleRate
            self.analysis.async { self.spectrum.analyze(samples, rate: rate); self.analysisSlot.signal() }
        }
    }
    func apply(_ s: Session) {
        player.mainMixerNode.outputVolume = s.volume
        player.mainMixerNode.pan = s.balance
        eq.bypass = !s.eqEnabled
        eq.globalGain = s.safePreamp
        for (i, gain) in s.bands.prefix(10).enumerated() { eq.bands[i].gain = gain }
    }
    func audioPlayer(_ audioPlayer: AudioPlayer, reconfigureProcessingGraph engine: AVAudioEngine, with format: AVAudioFormat) -> AVAudioNode {
        engine.disconnectNodeOutput(eq); engine.connect(eq, to: engine.mainMixerNode, format: format); return eq
    }
    func audioPlayer(_ audioPlayer: AudioPlayer, decodingAborted decoder: PCMDecoding, error: Error, framesRendered: AVAudioFramePosition) {
        DispatchQueue.main.async { self.onError?(error.localizedDescription) }
    }
    func audioPlayerEndOfAudio(_ audioPlayer: AudioPlayer) { DispatchQueue.main.async { self.onEnd?() } }
    func audioPlayer(_ audioPlayer: AudioPlayer, encounteredError error: Error) { DispatchQueue.main.async { self.onError?(error.localizedDescription) } }
}
