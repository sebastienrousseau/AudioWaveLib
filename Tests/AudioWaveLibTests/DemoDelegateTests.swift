@testable import AudioWaveLib
import Foundation
import XCTest

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

                var waveform = [[Character]](
                    repeating: [Character](repeating: " ", count: consoleWidth),
                    count: consoleHeight
                )

                for columnIndex in 0..<consoleWidth {
                    let startIdx = columnIndex * sampleData.count / consoleWidth
                    let endIdx = min(
                        (columnIndex + 1) * sampleData.count / consoleWidth,
                        sampleData.count
                    )
                    let columnSamples = sampleData[startIdx..<endIdx]

                    let columnMax = columnSamples.max() ?? 0
                    let columnMin = columnSamples.min() ?? 0

                    let scaledMax = scaleHeight(
                        columnMax, minValue, maxValue, consoleHeight
                    )
                    let scaledMin = scaleHeight(
                        columnMin, minValue, maxValue, consoleHeight
                    )

                    for rowIndex in scaledMin..<scaledMax {
                        waveform[rowIndex][columnIndex] = "|"
                    }
                }

                for row in waveform.reversed() {
                    capturedOutput += String(row) + "\n"
                }
            } else {
                capturedOutput = "No sample data available."
            }
        }

        func statusUpdated(
            provider: AudioWaveLibProvider,
            withError error: Error
        ) {
            capturedError = "An error occurred: \(error.localizedDescription)"
        }

        private func scaleHeight(
            _ value: Float,
            _ minValue: Float,
            _ maxValue: Float,
            _ consoleHeight: Int
        ) -> Int {
            guard maxValue != minValue else { return consoleHeight / 2 }
            let normalized = (value - minValue) / (maxValue - minValue)
            return min(consoleHeight - 1, max(0, Int(normalized * Float(consoleHeight))))
        }
    }

    func testDemoDelegateWithSampleData() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let demoDelegate = TestDemoDelegate()
        provider.delegate = demoDelegate

        provider.sampleData = [0.0, 0.5, 1.0, -0.5, -1.0, 0.0]
        demoDelegate.sampleProcessed(provider: provider)

        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)
        XCTAssertTrue(
            demoDelegate.capturedOutput.contains("|")
                || demoDelegate.capturedOutput.contains(" ")
        )
    }

    func testDemoDelegateWithNoSampleData() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let demoDelegate = TestDemoDelegate()

        demoDelegate.sampleProcessed(provider: provider)

        XCTAssertEqual(
            demoDelegate.capturedOutput,
            "No sample data available."
        )
    }

    func testDemoDelegateErrorHandling() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let demoDelegate = TestDemoDelegate()

        let testError = AudioWaveLibProviderError.invalidURL
        demoDelegate.statusUpdated(provider: provider, withError: testError)

        XCTAssertEqual(
            demoDelegate.capturedError,
            "An error occurred: The URL provided is invalid."
        )
    }

    // MARK: - Scale Height Edge Cases

    func testScaleHeightBoundaryConditions() throws {
        let testFile = TestAudioFile()
        try testFile.createFile()
        defer { testFile.cleanup() }

        let provider = try AudioWaveLibProvider(url: testFile.url)
        let demoDelegate = TestDemoDelegate()

        provider.sampleData = [1.0, 1.0, 1.0]
        demoDelegate.sampleProcessed(provider: provider)
        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)

        provider.sampleData = [1_000.0, -1_000.0]
        demoDelegate.capturedOutput = ""
        demoDelegate.sampleProcessed(provider: provider)
        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)

        provider.sampleData = [0.0, 0.0, 0.0]
        demoDelegate.capturedOutput = ""
        demoDelegate.sampleProcessed(provider: provider)
        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)

        provider.sampleData = [-1.0, -0.5, 0.0, 0.5, 1.0]
        demoDelegate.capturedOutput = ""
        demoDelegate.sampleProcessed(provider: provider)
        XCTAssertFalse(demoDelegate.capturedOutput.isEmpty)
    }
}
