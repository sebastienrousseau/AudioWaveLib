@testable import AudioWaveLib
import AVFoundation
import Foundation
import XCTest

final class AudioWaveLibEdgeCaseTests: XCTestCase {
    // MARK: - Unicode and Boundary Tests

    func testUnicodeFilePaths() {
        let unicodePaths = [
            "/tmp/音频文件.wav",
            "/tmp/файл.mp3",
            "/tmp/🎵音乐🎵.wav",
            "/tmp/ファイル.mp3"
        ]

        for path in unicodePaths {
            let url = URL(fileURLWithPath: path)

            do {
                _ = try AudioWaveLibProvider(url: url)
                XCTFail("Should fail with non-existent unicode file")
            } catch let error as AudioWaveLibProviderError {
                if case .fileInitializationFailed = error {
                    // Expected behavior for non-existent files
                } else {
                    XCTFail("Expected fileInitializationFailed for: \(path)")
                }
            } catch {
                XCTFail("Unexpected error type for unicode path: \(error)")
            }
        }
    }

    // MARK: - Memory Management Tests

    func testProviderDeallocation() throws {
        weak var weakProvider: AudioWaveLibProvider?

        do {
            let testFile = TestAudioFile()
            try testFile.createFile()
            defer { testFile.cleanup() }

            let provider = try AudioWaveLibProvider(url: testFile.url)
            weakProvider = provider
            XCTAssertNotNil(weakProvider)
        }

        XCTAssertNil(weakProvider)
    }

    // MARK: - Malformed and multi-channel input

    /// Writes a WAV file and returns its URL, deleting it when `body` returns.
    private func withTemporaryWAV(
        channels: AVAudioChannelCount,
        frames: AVAudioFrameCount,
        _ body: (URL) throws -> Void
    ) rethrows {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("awl-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: channels
        ) else {
            XCTFail("could not build a \(channels)-channel format")
            return
        }

        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frames
            ) else {
                XCTFail("could not allocate a \(frames)-frame buffer")
                return
            }
            buffer.frameLength = frames
            // A ramp, so a dropped channel is detectable rather than silent.
            for channel in 0 ..< Int(channels) {
                guard let data = buffer.floatChannelData?[channel] else { continue }
                for frame in 0 ..< Int(frames) {
                    data[frame] = Float(channel + 1) * Float(frame) / Float(frames)
                }
            }
            try file.write(from: buffer)
        } catch {
            XCTFail("could not write the fixture: \(error)")
            return
        }

        try body(url)
    }

    /// Truncated input must terminate rather than spin.
    ///
    /// `readChunkedSamples` advances by `chunkBuffer.frameLength`, so a read
    /// returning zero frames would leave `currentFrame` unchanged and the
    /// enclosing `while` would never end — on a background queue, that is a
    /// pinned core and a delegate that never fires. The library now guards
    /// against it explicitly.
    ///
    /// Note on what this test does and does not prove: it exercises the
    /// truncated-file path and asserts termination, but it does **not**
    /// reproduce the zero-frame read — removing the guard leaves it passing.
    /// AVAudioFile appears to reject or clamp such reads before the loop sees
    /// them. The guard is therefore defensive rather than a fix for a
    /// demonstrated hang, and this test is a termination regression net.
    func testTruncatedFileTerminatesInsteadOfHanging() throws {
        try withTemporaryWAV(channels: 1, frames: 8_192) { url in
            let handle = try FileHandle(forUpdating: url)
            let size = try handle.seekToEnd()
            // Drop the tail of the data chunk only. The RIFF header keeps its
            // original frame count, so AVAudioFile still opens the file and
            // reports the full length — the shortfall only shows up as a
            // short/zero read once the loop walks past the real data.
            try handle.truncate(atOffset: size - 2_048)
            try handle.close()

            guard let provider = try? AudioWaveLibProvider(url: url) else {
                // AVAudioFile can reject the truncated file outright, which is
                // also an acceptable outcome — the point is that it terminates.
                return
            }

            let finished = expectation(description: "processing terminates")
            let delegate = TerminationDelegate { finished.fulfill() }
            provider.delegate = delegate
            provider.createSampleData()

            // Generous, but bounded: before the guard this never completed.
            wait(for: [finished], timeout: 20)
        }
    }

    /// `sampleData` is documented as a single channel. This pins that contract
    /// so a future change to interleaved output is a deliberate decision.
    func testStereoFileYieldsFirstChannelOnly() throws {
        let frames: AVAudioFrameCount = 4_096
        try withTemporaryWAV(channels: 2, frames: frames) { url in
            let provider = try XCTUnwrap(try? AudioWaveLibProvider(url: url))
            let done = expectation(description: "processed")
            let delegate = TerminationDelegate { done.fulfill() }
            provider.delegate = delegate
            provider.createSampleData()
            wait(for: [done], timeout: 20)

            let samples = try XCTUnwrap(provider.sampleData)
            XCTAssertEqual(
                samples.count,
                Int(frames),
                "one channel expected, not interleaved: got \(samples.count) for \(frames) frames"
            )
            // Channel 0 was written as frame/frames, channel 1 as 2*frame/frames.
            let midpoint = samples[Int(frames) / 2]
            XCTAssertEqual(midpoint, 0.5, accuracy: 0.01, "channel 0 expected")
        }
    }

    /// Fires once on either delegate callback, so a test can wait for the
    /// provider to stop regardless of success or failure.
    private final class TerminationDelegate: AudioWaveLibProviderDelegate {
        private let onFinish: () -> Void
        private var fired = false

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func sampleProcessed(provider _: AudioWaveLibProvider) { finish() }
        func statusUpdated(provider _: AudioWaveLibProvider, withError _: Error) { finish() }

        private func finish() {
            guard !fired else { return }
            fired = true
            onFinish()
        }
    }
}
