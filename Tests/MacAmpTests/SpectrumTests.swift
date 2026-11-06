import XCTest
@testable import MacAmp
final class SpectrumTests: XCTestCase {
    func testBarsRiseInstantlyFallSteadilyAndPeaksHoldThenDrop() {
        let motion = SpectrumMotion()
        var up = Array(repeating: Float(0), count: Spectrum.bands); up[0] = 0.8
        motion.step(to: up, at: 0)
        XCTAssertEqual(motion.levels[0], 0.8)
        motion.step(to: [], at: 0.1)
        XCTAssertEqual(motion.levels[0], 0.8 - SpectrumMotion.fallRate * 0.1, accuracy: 0.001)
        XCTAssertEqual(motion.peaks[0], 0.8, "peak holds")
        for t in stride(from: 0.2, through: 2.0, by: 0.05) { motion.step(to: [], at: t) }
        XCTAssertTrue(motion.isIdle, "everything falls back to zero")
    }
    func testFramesAreReleasedAtAudioPace() {
        let spectrum = Spectrum()
        let rate = 44_100.0
        let tone = (0..<4410).map { Float(sin(2 * Double.pi * 440 * Double($0) / rate)) * 0.5 }
        spectrum.analyze(tone, rate: rate, arrival: 100)
        let first = spectrum.read(at: 100)
        XCTAssertTrue(first.contains { $0 > 0 })
        XCTAssertEqual(spectrum.read(at: 99), first, "nothing newer is due yet")
        let last = spectrum.read(at: 100.2)
        XCTAssertEqual(last, spectrum.read(), "after the block's duration the newest slice is shown")
    }
}
