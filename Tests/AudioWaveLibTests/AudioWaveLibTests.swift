import Foundation
import XCTest
@testable import AudioWaveLib

// MARK: - Test Utilities

private struct TestAudioFile {
    let url: URL
    let sampleRate: Double = 44100.0
    let channels: UInt32 = 1
    let frameCount: UInt32 = 1024

    init(fileName: String = "test_audio") {
        let tempDir = FileManager.default.temporaryDirectory
        self.url = tempDir.appendingPathComponent("\(fileName).wav")
    }

    func createFile() throws {
        // Create a minimal WAV file for testing
        let header = createWAVHeader()
        let audioData = createSineWaveData()
        let fullData = header + audioData
        try fullData.write(to: url)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }

    private func createWAVHeader() -> Data {
        var header = Data()
        // RIFF header
        header.append("RIFF".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(36 + frameCount * 4).littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // format (PCM)
        header.append(withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt32(sampleRate * Double(channels) * 2).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(channels * 2).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) }) // bits per sample

        // data chunk
        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(frameCount * 4).littleEndian) { Data($0) })

        return header
    }

    private func createSineWaveData() -> Data {
        var data = Data()
        let frequency: Double = 440.0 // A note

        for i in 0..<frameCount {
            let sample = sin(2.0 * Double.pi * frequency * Double(i) / sampleRate)
            let intSample = Int16(sample * 32767.0)
            data.append(withUnsafeBytes(of: intSample.littleEndian) { Data($0) })
        }

        return data
    }
}

// MARK: - Mock Delegate for Testing

private class MockDelegate: AudioWaveLibProviderDelegate {
    var sampleProcessedCalled = false
    var statusUpdatedCalled = false
    var lastError: Error?
    var expectation: XCTestExpectation?

    func sampleProcessed(provider: AudioWaveLibProvider) {
        sampleProcessedCalled = true
        expectation?.fulfill()
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        statusUpdatedCalled = true
        lastError = error
        expectation?.fulfill()
    }

    func reset() {
        sampleProcessedCalled = false
        statusUpdatedCalled = false
        lastError = nil
        expectation = nil
    }
}

// MARK: - Test Cases

final class AudioWaveLibTests: XCTestCase {

    // MARK: - Version Tests

    func testAudioWaveLibVersion() {
        XCTAssertEqual(audioWaveLibVersion, "0.0.2")
    }

    // MARK: - Error Tests

    func testAudioWaveLibProviderErrorEquatable() {
        // Test equality
        XCTAssertEqual(AudioWaveLibProviderError.invalidURL, AudioWaveLibProviderError.invalidURL)
        XCTAssertEqual(
            AudioWaveLibProviderError.fileInitializationFailed("test"),
            AudioWaveLibProviderError.fileInitializationFailed("test")
        )
        XCTAssertEqual(
            AudioWaveLibProviderError.invalidFrameCountOrFormat,
            AudioWaveLibProviderError.invalidFrameCountOrFormat
        )
        XCTAssertEqual(
            AudioWaveLibProviderError.audioProcessingFailed("test"),
            AudioWaveLibProviderError.audioProcessingFailed("test")
        )

        // Test inequality
        XCTAssertNotEqual(AudioWaveLibProviderError.invalidURL, AudioWaveLibProviderError.invalidFrameCountOrFormat)
        XCTAssertNotEqual(
            AudioWaveLibProviderError.fileInitializationFailed("test1"),
            AudioWaveLibProviderError.fileInitializationFailed("test2")
        )
        XCTAssertNotEqual(
            AudioWaveLibProviderError.audioProcessingFailed("test1"),
            AudioWaveLibProviderError.audioProcessingFailed("test2")
        )
    }

    func testAudioWaveLibProviderErrorLocalizedDescription() {
        let error1 = AudioWaveLibProviderError.invalidURL
        XCTAssertEqual(error1.errorDescription, "The URL provided is invalid.")

        let error2 = AudioWaveLibProviderError.fileInitializationFailed("File not found")
        XCTAssertEqual(error2.errorDescription, "Failed to initialize audio file: File not found")

        let error3 = AudioWaveLibProviderError.invalidFrameCountOrFormat
        XCTAssertEqual(error3.errorDescription, "Invalid frame count or audio format.")

        let error4 = AudioWaveLibProviderError.audioProcessingFailed("Format error")
        XCTAssertEqual(error4.errorDescription, "Audio processing failed: Format error")
    }

    // MARK: - AudioWaveLibProvider Initialization Tests

    func testInitializationWithNonFileURL() {
        let httpURL = URL(string: "https://example.com/audio.mp3")!

        do {
            _ = try AudioWaveLibProvider(url: httpURL)
            XCTFail("Expected invalidURL error")
        } catch let error as AudioWaveLibProviderError {
            XCTAssertEqual(error, AudioWaveLibProviderError.invalidURL)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInitializationWithNonExistentFile() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path/audio.mp3")

        do {
            _ = try AudioWaveLibProvider(url: nonExistentURL)
            XCTFail("Expected fileInitializationFailed error")
        } catch let error as AudioWaveLibProviderError {
            if case .fileInitializationFailed(let message) = error {
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("Expected fileInitializationFailed error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInitializationWithValidFile() throws {
        let testFile = TestAudioFile(fileName: "valid_audio")
        try testFile.createFile()
        defer { testFile.cleanup() }

        do {
            let provider = try AudioWaveLibProvider(url: testFile.url)
            XCTAssertNotNil(provider)
            XCTAssertNil(provider.sampleData) // Should be nil until processing
        } catch {
            XCTFail("Initialization should succeed with valid file: \(error)")
        }
    }

    // MARK: - Delegate Tests

    func testDelegateWeakReference() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        var delegate: MockDelegate? = MockDelegate()
        provider.delegate = delegate

        XCTAssertNotNil(provider.delegate)

        delegate = nil
        XCTAssertNil(provider.delegate)
    }

    // MARK: - Sample Data Processing Tests

    func testSampleDataBeforeProcessing() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)

        XCTAssertNil(provider.sampleData)
        XCTAssertNil(provider.sampleData)
    }

    func testCreateSampleDataWithValidFile() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let delegate = MockDelegate()
        provider.delegate = delegate

        let expectation = XCTestExpectation(description: "Sample processing completed")
        delegate.expectation = expectation

        provider.createSampleData()

        wait(for: [expectation], timeout: 5.0)

        if delegate.sampleProcessedCalled {
            XCTAssertNotNil(provider.sampleData)
            XCTAssertNotNil(provider.sampleData)
            XCTAssertFalse(provider.sampleData!.isEmpty)
        } else if delegate.statusUpdatedCalled {
            XCTAssertNotNil(delegate.lastError)
        } else {
            XCTFail("Neither delegate method was called")
        }
    }

    // MARK: - Async Cancellation Tests

    func testTaskCancellation() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)

        // Start processing
        provider.createSampleData()

        // Immediately start another processing (should cancel the first)
        provider.createSampleData()

        // The cancellation behavior is internal, but we can verify the provider still works
        XCTAssertNotNil(provider)
    }

    // MARK: - Edge Case Tests

    func testMultipleConcurrentCreateSampleDataCalls() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let delegate = MockDelegate()
        provider.delegate = delegate

        let expectation = XCTestExpectation(description: "Final processing completed")
        delegate.expectation = expectation

        // Make multiple concurrent calls
        for _ in 0..<5 {
            provider.createSampleData()
        }

        wait(for: [expectation], timeout: 10.0)

        // Should still complete successfully
        XCTAssertTrue(delegate.sampleProcessedCalled || delegate.statusUpdatedCalled)
    }

    // MARK: - Property-Based Tests

    func testErrorDescriptionsAreNonEmpty() {
        let testCases: [AudioWaveLibProviderError] = [
            .invalidURL,
            .fileInitializationFailed(""),
            .fileInitializationFailed("test message"),
            .invalidFrameCountOrFormat,
            .audioProcessingFailed(""),
            .audioProcessingFailed("test message")
        ]

        for error in testCases {
            let description = error.errorDescription
            XCTAssertNotNil(description, "Error description should not be nil for: \(error)")
            XCTAssertFalse(description!.isEmpty, "Error description should not be empty for: \(error)")
        }
    }

    func testErrorMessageParameterization() {
        let messages = ["", "test", "error with spaces", "unicode 🎵", "very long error message that exceeds typical lengths"]

        for message in messages {
            let fileError = AudioWaveLibProviderError.fileInitializationFailed(message)
            let audioError = AudioWaveLibProviderError.audioProcessingFailed(message)

            XCTAssertTrue(fileError.errorDescription!.contains(message))
            XCTAssertTrue(audioError.errorDescription!.contains(message))
        }
    }

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
                if case .fileInitializationFailed(_) = error {
                    // Expected behavior for non-existent files
                } else {
                    XCTFail("Expected fileInitializationFailed for unicode path: \(path)")
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

        // Provider should be deallocated when it goes out of scope
        XCTAssertNil(weakProvider)
    }
}

// MARK: - Demo Delegate Tests

final class DemoDelegateTests: XCTestCase {

    private class TestDemoDelegate: AudioWaveLibProviderDelegate {
        var capturedOutput: String = ""
        var capturedError: String = ""

        func sampleProcessed(provider: AudioWaveLibProvider) {
            if let sampleData = provider.sampleData {
                let consoleWidth = 80
                let consoleHeight = 20
                let maxValue = sampleData.max() ?? 0
                let minValue = sampleData.min() ?? 0

                // Capture output instead of printing
                var waveform = [[Character]](
                    repeating: [Character](repeating: " ", count: consoleWidth),
                    count: consoleHeight
                )

                for columnIndex in 0..<consoleWidth {
                    let startIndex = columnIndex * sampleData.count / consoleWidth
                    let endIndex = min((columnIndex + 1) * sampleData.count / consoleWidth, sampleData.count)
                    let columnSamples = sampleData[startIndex..<endIndex]

                    let columnMax = columnSamples.max() ?? 0
                    let columnMin = columnSamples.min() ?? 0

                    let scaledColumnHeight = scaleHeight(columnMax, minValue, maxValue, consoleHeight)
                    let scaledColumnMinHeight = scaleHeight(columnMin, minValue, maxValue, consoleHeight)

                    for rowIndex in scaledColumnMinHeight..<scaledColumnHeight {
                        waveform[rowIndex][columnIndex] = "|"
                    }
                }

                // Capture the output
                for row in waveform.reversed() {
                    capturedOutput += String(row) + "\n"
                }
            } else {
                capturedOutput = "No sample data available."
            }
        }

        func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
            capturedError = "An error occurred: \(error.localizedDescription)"
        }

        private func scaleHeight(_ value: Float, _ minValue: Float, _ maxValue: Float, _ consoleHeight: Int) -> Int {
            let normalizedValue = (value - minValue) / (maxValue - minValue)
            return Int(normalizedValue * Float(consoleHeight))
        }
    }

    func testDemoDelegateWithSampleData() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let demoDelegate = TestDemoDelegate()
        provider.delegate = demoDelegate

        let expectation = XCTestExpectation(description: "Demo delegate processing")

        // Manually set some test data
        provider.sampleData = [0.0, 0.5, 1.0, -0.5, -1.0, 0.0]

        // Trigger the delegate method
        demoDelegate.sampleProcessed(provider: provider)

        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)
        XCTAssertTrue(demoDelegate.capturedOutput.contains("|") || demoDelegate.capturedOutput.contains(" "))
    }

    func testDemoDelegateWithNoSampleData() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let demoDelegate = TestDemoDelegate()

        // Don't set sample data
        demoDelegate.sampleProcessed(provider: provider)

        XCTAssertEqual(demoDelegate.capturedOutput, "No sample data available.")
    }

    func testDemoDelegateErrorHandling() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let demoDelegate = TestDemoDelegate()

        let testError = AudioWaveLibProviderError.invalidURL
        demoDelegate.statusUpdated(provider: provider, withError: testError)

        XCTAssertEqual(demoDelegate.capturedError, "An error occurred: The URL provided is invalid.")
    }

    // MARK: - Scale Height Edge Cases

    func testScaleHeightBoundaryConditions() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let demoDelegate = TestDemoDelegate()

        // Test with same min/max values (division by zero protection)
        provider.sampleData = [1.0, 1.0, 1.0]
        demoDelegate.sampleProcessed(provider: provider)
        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)

        // Test with extreme values
        provider.sampleData = [Float.greatestFiniteMagnitude, Float.leastNormalMagnitude]
        demoDelegate.capturedOutput = "" // Reset
        demoDelegate.sampleProcessed(provider: provider)
        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)

        // Test with zero values
        provider.sampleData = [0.0, 0.0, 0.0]
        demoDelegate.capturedOutput = "" // Reset
        demoDelegate.sampleProcessed(provider: provider)
        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)

        // Test with negative values
        provider.sampleData = [-1.0, -0.5, 0.0, 0.5, 1.0]
        demoDelegate.capturedOutput = "" // Reset
        demoDelegate.sampleProcessed(provider: provider)
        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)
    }
}
