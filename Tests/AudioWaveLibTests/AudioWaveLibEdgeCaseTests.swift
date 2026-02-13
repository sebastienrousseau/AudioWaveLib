@testable import AudioWaveLib
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
}
