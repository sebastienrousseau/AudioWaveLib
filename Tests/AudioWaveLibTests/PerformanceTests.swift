import Foundation
import XCTest
@testable import AudioWaveLib

final class AudioWaveLibPerformanceTests: XCTestCase {

    // MARK: - Performance Test Utilities

    private func createTestFile(frameCount: UInt32, fileName: String = "perf_test_audio") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("\(fileName).wav")

        let sampleRate: UInt32 = 44100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let frequency: Double = 440.0

        var data = Data()

        // RIFF header
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(36 + frameCount * 2).littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        data.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt32(sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(channels * bitsPerSample / 8).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data chunk
        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(frameCount * 2).littleEndian) { Data($0) })

        for i in 0..<frameCount {
            let sample = sin(2.0 * Double.pi * frequency * Double(i) / Double(sampleRate))
            let intSample = Int16(sample * 32767.0)
            data.append(withUnsafeBytes(of: intSample.littleEndian) { Data($0) })
        }

        try! data.write(to: url)
        return url
    }

    // MARK: - Baseline Performance Tests

    func testAudioFileInitializationPerformance() throws {
        let url = createTestFile(frameCount: 44100)
        defer { try? FileManager.default.removeItem(at: url) }

        measure {
            do {
                _ = try AudioWaveLibProvider(url: url)
            } catch {
                XCTFail("Initialization failed: \(error)")
            }
        }
    }

    func testSmallFileSampleProcessingPerformance() throws {
        let url = createTestFile(frameCount: 4410)
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = try AudioWaveLibProvider(url: url)

        measure {
            let expectation = XCTestExpectation(description: "Sample processing")
            let delegate = MockPerformanceDelegate(expectation: expectation)
            provider.delegate = delegate
            provider.createSampleData()
            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testLargeFileSampleProcessingPerformance() throws {
        let url = createTestFile(frameCount: 441000)
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = try AudioWaveLibProvider(url: url)

        measure {
            let expectation = XCTestExpectation(description: "Large file processing")
            let delegate = MockPerformanceDelegate(expectation: expectation)
            provider.delegate = delegate
            provider.createSampleData()
            wait(for: [expectation], timeout: 30.0)
        }
    }

    // MARK: - Memory Performance Tests

    func testMemoryUsageUnderLoad() throws {
        let url = createTestFile(frameCount: 441000)
        defer { try? FileManager.default.removeItem(at: url) }

        measure(metrics: [XCTMemoryMetric()]) {
            autoreleasepool {
                do {
                    let provider = try AudioWaveLibProvider(url: url)
                    let expectation = XCTestExpectation(description: "Memory test")
                    let delegate = MockPerformanceDelegate(expectation: expectation)
                    provider.delegate = delegate

                    provider.createSampleData()
                    wait(for: [expectation], timeout: 30.0)

                    XCTAssertNotNil(provider.sampleData)
                } catch {
                    XCTFail("Memory test failed: \(error)")
                }
            }
        }
    }

    func testMemoryGrowthWithRepeatedProcessing() throws {
        let url = createTestFile(frameCount: 44100)
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = try AudioWaveLibProvider(url: url)

        measure(metrics: [XCTMemoryMetric()]) {
            for _ in 0..<10 {
                autoreleasepool {
                    let expectation = XCTestExpectation(description: "Iteration")
                    let delegate = MockPerformanceDelegate(expectation: expectation)
                    provider.delegate = delegate
                    provider.createSampleData()
                    wait(for: [expectation], timeout: 5.0)
                }
            }
        }
    }

    // MARK: - Hot Path Profiling Tests

    func testSampleDataAccessPerformance() throws {
        let url = createTestFile(frameCount: 441000)
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = try AudioWaveLibProvider(url: url)
        let expectation = XCTestExpectation(description: "Sample access setup")
        let delegate = MockPerformanceDelegate(expectation: expectation)
        provider.delegate = delegate

        provider.createSampleData()
        wait(for: [expectation], timeout: 30.0)

        measure {
            for _ in 0..<1000 {
                _ = provider.sampleData
            }
        }
    }
}

// MARK: - Performance Test Support

private class MockPerformanceDelegate: AudioWaveLibProviderDelegate {
    private let expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func sampleProcessed(provider: AudioWaveLibProvider) {
        expectation.fulfill()
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        expectation.fulfill()
    }
}
