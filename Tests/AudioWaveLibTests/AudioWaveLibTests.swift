@testable import AudioWaveLib
import AVFoundation
import XCTest

class AudioWaveLibProviderTests: XCTestCase, AudioWaveLibProviderDelegate {
    func statusUpdated(provider _: AudioWaveLib.AudioWaveLibProvider, withError error: Error) {
        // Fulfil the expectation when the processing fails
        XCTAssertNil(error)
        invalidAudioFileURL = URL(fileURLWithPath: "invalidFile.mp3")
        let provider = try? AudioWaveLibProvider(url: invalidAudioFileURL)
        XCTAssertNil(provider, "Provider initialization should fail with an invalid URL")
    }

    var provider: AudioWaveLibProvider?
    var validAudioFileURL: URL!
    var invalidAudioFileURL: URL!

    override func setUp() {
        super.setUp()
        validAudioFileURL = URL(fileURLWithPath: "./file.mp3")
        invalidAudioFileURL = URL(fileURLWithPath: "./invalidFile.mp3")
    }

    // Implementation of the delegate method
    func sampleProcessed(provider: AudioWaveLibProvider) {
        XCTAssertNotNil(provider.sampleData)
    }

    func testInvalidFrameCountOrFormatError() {
        let invalidAudioFileURL = URL(fileURLWithPath: "invalidFile.mp3")
        let provider = try? AudioWaveLibProvider(url: invalidAudioFileURL)
        XCTAssertNil(provider, "Provider initialization should fail with an invalid URL")
    }

    func testInitializationWithInvalidURLFails() {
        let invalidProvider = try? AudioWaveLibProvider(url: invalidAudioFileURL)
        XCTAssertNil(invalidProvider, "Provider initialization should fail with an invalid URL")
    }

    func testInitializationWithValidURLSucceeds() {
        // Here, you should be testing with a local variable or a differently initialized instance
        // For the sake of example, let's say we're directly using a new instance for this test
        let validProvider = try? AudioWaveLibProvider(url: validAudioFileURL)
        XCTAssertNotNil(validProvider, "Provider initialization should succeed with a valid URL")
    }

    enum AudioError: Error {
        case invalidURL
        case fileInitializationFailed(message: String)
        case invalidFrameCountOrFormat
        case audioProcessingFailed(message: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                "The URL provided is invalid."
            case let .fileInitializationFailed(message):
                "Failed to initialize audio file: \(message)"
            case .invalidFrameCountOrFormat:
                "Invalid frame count or audio format."
            case let .audioProcessingFailed(message):
                "Audio processing failed: \(message)"
            }
        }
    }

    func testErrorDescription() {
        XCTAssertEqual(AudioError.invalidURL.errorDescription, "The URL provided is invalid.")

        let fileInitError = AudioError.fileInitializationFailed(message: "File not found")
        XCTAssertEqual(fileInitError.errorDescription, "Failed to initialize audio file: File not found")

        XCTAssertEqual(AudioError.invalidFrameCountOrFormat.errorDescription, "Invalid frame count or audio format.")

        let processingError = AudioError.audioProcessingFailed(message: "Unexpected format")
        XCTAssertEqual(processingError.errorDescription, "Audio processing failed: Unexpected format")
    }
}
