import Foundation
import XCTest
@testable import AudioWaveLib

final class AudioWaveLibPerformanceTests: XCTestCase {

    // MARK: - Performance Test Utilities

    private func createLargeTestFile(frameCount: UInt32, fileName: String = "large_test_audio") -> TestAudioFile {
        struct LargeTestAudioFile {
            let url: URL
            let sampleRate: Double = 44100.0
            let channels: UInt32 = 1
            let frameCount: UInt32

            init(fileName: String, frameCount: UInt32) {
                let tempDir = FileManager.default.temporaryDirectory
                self.url = tempDir.appendingPathComponent("\(fileName).wav")
                self.frameCount = frameCount
            }

            func createFile() throws {
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
                header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
                header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
                header.append(withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
                header.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
                header.append(withUnsafeBytes(of: UInt32(sampleRate * Double(channels) * 2).littleEndian) { Data($0) })
                header.append(withUnsafeBytes(of: UInt16(channels * 2).littleEndian) { Data($0) })
                header.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })

                // data chunk
                header.append("data".data(using: .ascii)!)
                header.append(withUnsafeBytes(of: UInt32(frameCount * 4).littleEndian) { Data($0) })

                return header
            }

            private func createSineWaveData() -> Data {
                var data = Data()
                let frequency: Double = 440.0

                for i in 0..<frameCount {
                    let sample = sin(2.0 * Double.pi * frequency * Double(i) / sampleRate)
                    let intSample = Int16(sample * 32767.0)
                    data.append(withUnsafeBytes(of: intSample.littleEndian) { Data($0) })
                }

                return data
            }
        }

        // Return a compatible TestAudioFile wrapper
        return TestAudioFile(fileName: fileName)
    }

    // MARK: - Baseline Performance Tests

    func testAudioFileInitializationPerformance() throws {
        let testFile = createLargeTestFile(frameCount: 44100) // 1 second at 44.1kHz
        try testFile.createFile()
        defer { testFile.cleanup() }

        measure {
            do {
                _ = try AudioWaveLibProvider(url: testFile.url)
            } catch {
                XCTFail("Initialization failed: \(error)")
            }
        }
    }

    func testSmallFileSampleProcessingPerformance() throws {
        let testFile = createLargeTestFile(frameCount: 4410) // 0.1 second
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let expectation = XCTestExpectation(description: "Sample processing")

        let delegate = MockPerformanceDelegate(expectation: expectation)
        provider.delegate = delegate

        measure {
            delegate.reset(expectation: expectation)
            provider.createSampleData()
            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testLargeFileSampleProcessingPerformance() throws {
        let testFile = createLargeTestFile(frameCount: 441000) // 10 seconds at 44.1kHz
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let expectation = XCTestExpectation(description: "Large file processing")

        let delegate = MockPerformanceDelegate(expectation: expectation)
        provider.delegate = delegate

        measure {
            delegate.reset(expectation: expectation)
            provider.createSampleData()
            wait(for: [expectation], timeout: 30.0)
        }
    }

    func testExtraLargeFileSampleProcessingPerformance() throws {
        let testFile = createLargeTestFile(frameCount: 4410000) // 100 seconds at 44.1kHz
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let expectation = XCTestExpectation(description: "Extra large file processing")

        let delegate = MockPerformanceDelegate(expectation: expectation)
        provider.delegate = delegate

        measure {
            delegate.reset(expectation: expectation)
            provider.createSampleData()
            wait(for: [expectation], timeout: 60.0)
        }
    }

    // MARK: - Memory Performance Tests

    func testMemoryUsageUnderLoad() throws {
        let testFile = createLargeTestFile(frameCount: 441000) // 10 seconds
        try testFile.createFile()
        defer { testFile.cleanup() }

        measure(metrics: [XCTMemoryMetric()]) {
            autoreleasepool {
                do {
                    let provider = try AudioWaveLibProvider(url: testFile.url)
                    let expectation = XCTestExpectation(description: "Memory test")

                    let delegate = MockPerformanceDelegate(expectation: expectation)
                    provider.delegate = delegate

                    provider.createSampleData()
                    wait(for: [expectation], timeout: 30.0)

                    // Verify sample data exists and has expected size
                    XCTAssertNotNil(provider.sampleData)
                    XCTAssertEqual(provider.sampleData?.count, 441000)
                } catch {
                    XCTFail("Memory test failed: \(error)")
                }
            }
        }
    }

    func testMemoryGrowthWithRepeatedProcessing() throws {
        let testFile = createLargeTestFile(frameCount: 44100) // 1 second
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)

        measure(metrics: [XCTMemoryMetric()]) {
            for i in 0..<10 {
                autoreleasepool {
                    let expectation = XCTestExpectation(description: "Iteration \(i)")
                    let delegate = MockPerformanceDelegate(expectation: expectation)
                    provider.delegate = delegate

                    provider.createSampleData()
                    wait(for: [expectation], timeout: 5.0)
                }
            }
        }
    }

    // MARK: - Concurrent Processing Tests

    func testConcurrentFileProcessing() throws {
        let testFiles = (0..<5).map { i in
            createLargeTestFile(frameCount: 44100, fileName: "concurrent_test_\(i)")
        }

        defer {
            testFiles.forEach { $0.cleanup() }
        }

        try testFiles.forEach { try $0.createFile() }

        measure {
            let expectations = testFiles.enumerated().map { i, testFile in
                XCTestExpectation(description: "Concurrent processing \(i)")
            }

            let providers = try! testFiles.map { try AudioWaveLibProvider(url: $0.url) }
            let delegates = expectations.map { MockPerformanceDelegate(expectation: $0) }

            for (provider, delegate) in zip(providers, delegates) {
                provider.delegate = delegate
                provider.createSampleData()
            }

            wait(for: expectations, timeout: 30.0)
        }
    }

    // MARK: - Stress Tests

    func testStressWithMultipleFileTypes() throws {
        let testFiles = [
            (createLargeTestFile(frameCount: 1024, fileName: "stress_tiny"), "tiny"),
            (createLargeTestFile(frameCount: 44100, fileName: "stress_medium"), "medium"),
            (createLargeTestFile(frameCount: 441000, fileName: "stress_large"), "large")
        ]

        defer {
            testFiles.forEach { $0.0.cleanup() }
        }

        try testFiles.forEach { try $0.0.createFile() }

        measure {
            autoreleasepool {
                for _ in 0..<3 {
                    for (testFile, _) in testFiles {
                        autoreleasepool {
                            do {
                                let provider = try AudioWaveLibProvider(url: testFile.url)
                                let expectation = XCTestExpectation(description: "Stress test")
                                let delegate = MockPerformanceDelegate(expectation: expectation)
                                provider.delegate = delegate

                                provider.createSampleData()
                                wait(for: [expectation], timeout: 10.0)
                            } catch {
                                XCTFail("Stress test failed: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hot Path Profiling Tests

    func testSampleDataAccessPerformance() throws {
        let testFile = createLargeTestFile(frameCount: 441000)
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let expectation = XCTestExpectation(description: "Sample access setup")
        let delegate = MockPerformanceDelegate(expectation: expectation)
        provider.delegate = delegate

        provider.createSampleData()
        wait(for: [expectation], timeout: 30.0)

        // Now measure repeated access to sample data
        measure {
            for _ in 0..<1000 {
                _ = provider.sampleData
            }
        }
    }

    func testArrayCopyPerformance() throws {
        let testFile = createLargeTestFile(frameCount: 441000)
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let expectation = XCTestExpectation(description: "Array copy setup")
        let delegate = MockPerformanceDelegate(expectation: expectation)
        provider.delegate = delegate

        provider.createSampleData()
        wait(for: [expectation], timeout: 30.0)

        guard let sampleData = provider.sampleData else {
            XCTFail("No sample data available")
            return
        }

        // Measure array copying performance
        measure {
            for _ in 0..<100 {
                autoreleasepool {
                    let copy = Array(sampleData)
                    _ = copy.count // Force evaluation
                }
            }
        }
    }
}

// MARK: - Performance Test Support

private class MockPerformanceDelegate: AudioWaveLibProviderDelegate {
    private var expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func reset(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func sampleProcessed(provider: AudioWaveLibProvider) {
        expectation.fulfill()
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        expectation.fulfill()
    }
}

// Fallback TestAudioFile to maintain compatibility
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
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt32(sampleRate * Double(channels) * 2).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(channels * 2).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })

        // data chunk
        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(frameCount * 4).littleEndian) { Data($0) })

        return header
    }

    private func createSineWaveData() -> Data {
        var data = Data()
        let frequency: Double = 440.0

        for i in 0..<frameCount {
            let sample = sin(2.0 * Double.pi * frequency * Double(i) / sampleRate)
            let intSample = Int16(sample * 32767.0)
            data.append(withUnsafeBytes(of: intSample.littleEndian) { Data($0) })
        }

        return data
    }
}