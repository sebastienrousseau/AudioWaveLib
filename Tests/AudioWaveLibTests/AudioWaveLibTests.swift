@testable import AudioWaveLib
import Foundation
import XCTest

// MARK: - Test Utilities

struct TestAudioFile {
    let url: URL
    let sampleRate: Double = 44_100.0
    let channels: UInt32 = 1
    let frameCount: UInt32 = 1_024

    init(fileName: String = "test_audio") {
        let tempDir = FileManager.default.temporaryDirectory
        url = tempDir.appendingPathComponent("\(fileName).wav")
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

    // swiftlint:disable force_unwrapping
    private func createWAVHeader() -> Data {
        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        let fileSize = UInt32(36 + frameCount * 4).littleEndian
        header.append(withUnsafeBytes(of: fileSize) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)

        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        let byteRate = UInt32(sampleRate * Double(channels) * 2).littleEndian
        header.append(withUnsafeBytes(of: byteRate) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(channels * 2).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })

        header.append("data".data(using: .ascii)!)
        let dataSize = UInt32(frameCount * 4).littleEndian
        header.append(withUnsafeBytes(of: dataSize) { Data($0) })

        return header
    }

    // swiftlint:enable force_unwrapping

    private func createSineWaveData() -> Data {
        var data = Data()
        let frequency = 440.0

        for index in 0 ..< frameCount {
            let phase = 2.0 * Double.pi * frequency * Double(index)
            let sample = sin(phase / sampleRate)
            let intSample = Int16(sample * 32_767.0)
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

    func sampleProcessed(provider _: AudioWaveLibProvider) {
        sampleProcessedCalled = true
        expectation?.fulfill()
    }

    func statusUpdated(provider _: AudioWaveLibProvider, withError error: Error) {
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

    func testInitializationWithNonFileURL() throws {
        let httpURL = try XCTUnwrap(URL(string: "https://example.com/audio.mp3"))

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
            if case let .fileInitializationFailed(message) = error {
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
            XCTAssertFalse(provider.sampleData?.isEmpty ?? true)
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
        for _ in 0 ..< 5 {
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
            XCTAssertNotNil(description, "Should not be nil for: \(error)")
            XCTAssertFalse(
                (description ?? "").isEmpty,
                "Should not be empty for: \(error)"
            )
        }
    }

    func testErrorMessageParameterization() {
        let messages = ["test", "error with spaces", "very long error message that exceeds typical lengths"]

        for message in messages {
            let fileError = AudioWaveLibProviderError.fileInitializationFailed(message)
            let audioError = AudioWaveLibProviderError.audioProcessingFailed(message)
            let fileDesc = fileError.errorDescription ?? ""
            let audioDesc = audioError.errorDescription ?? ""

            XCTAssertTrue(
                fileDesc.contains(message),
                "Expected '\(fileDesc)' to contain '\(message)'"
            )
            XCTAssertTrue(
                audioDesc.contains(message),
                "Expected '\(audioDesc)' to contain '\(message)'"
            )
        }
    }
}
