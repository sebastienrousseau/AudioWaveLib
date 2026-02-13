#!/usr/bin/env swift

import Foundation
import AudioWaveLib

// MARK: - AudioUtils (Shared utility functions)
struct AudioUtils {
    static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        let sumSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumSquares / Float(samples.count))
    }

    static func countZeroCrossings(_ samples: [Float]) -> Int {
        guard samples.count > 1 else { return 0 }
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i-1] >= 0 && samples[i] < 0) || (samples[i-1] < 0 && samples[i] >= 0) {
                crossings += 1
            }
        }
        return crossings
    }
}

// MARK: - BaseAudioDelegate (Shared base functionality)
class BaseAudioDelegate: NSObject, AudioWaveLibProviderDelegate {
    func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let sampleData = provider.sampleData else {
            print("No sample data available.")
            return
        }
        print("Sample processed - \(sampleData.count) samples")
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        if let audioError = error as? AudioWaveLibProviderError {
            switch audioError {
            case .invalidURL:
                print("❌ Invalid audio file URL")
            case .fileInitializationFailed(let message):
                print("❌ File initialization failed: \(message)")
            case .invalidFrameCountOrFormat:
                print("❌ Invalid audio format or frame count")
            case .audioProcessingFailed(let message):
                print("❌ Audio processing failed: \(message)")
            }
        } else {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
}

// Example: Console Waveform Output
class ConsoleWaveformProcessor: BaseAudioDelegate {
    private var isProcessing = false

    override func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let sampleData = provider.sampleData else { return }

        print("\n🎵 Audio Processing Complete!")
        print("Sample count: \(sampleData.count)")

        renderConsoleWaveform(sampleData)

        isProcessing = false
    }

    override func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        print("❌ Console processor error: \(error.localizedDescription)")
        isProcessing = false
    }

    private func renderConsoleWaveform(_ samples: [Float]) {
        let consoleWidth = 80
        let consoleHeight = 20

        guard let maxValue = samples.max(),
              let minValue = samples.min() else { return }

        var waveform = Array(repeating: Array(repeating: " ", count: consoleWidth), count: consoleHeight)

        // Sample down to console width
        for columnIndex in 0..<consoleWidth {
            let startIndex = columnIndex * samples.count / consoleWidth
            let endIndex = min((columnIndex + 1) * samples.count / consoleWidth, samples.count)

            if startIndex < endIndex {
                let columnSamples = Array(samples[startIndex..<endIndex])

                guard let columnMax = columnSamples.max(),
                      let columnMin = columnSamples.min() else { continue }

                let maxRow = scaleToRow(columnMax, minValue, maxValue, consoleHeight)
                let minRow = scaleToRow(columnMin, minValue, maxValue, consoleHeight)

                for rowIndex in minRow..<maxRow {
                    if rowIndex >= 0 && rowIndex < consoleHeight {
                        waveform[rowIndex][columnIndex] = "█"
                    }
                }
            }
        }

        // Render the waveform
        print("\n🌊 Audio Waveform Visualization:")
        print("┌" + String(repeating: "─", count: consoleWidth) + "┐")

        for row in waveform.reversed() {
            print("│" + row.joined() + "│")
        }

        print("└" + String(repeating: "─", count: consoleWidth) + "┘")
        print("Duration: \(samples.count) samples")
        print("Range: \(String(format: "%.3f", minValue))...\(String(format: "%.3f", maxValue))")

        // Calculate and display additional metrics using shared utilities
        let rmsLevel = AudioUtils.calculateRMS(samples)
        let zeroCrossings = AudioUtils.countZeroCrossings(samples)

        print("\n📊 Audio Metrics:")
        print("  • RMS Level: \(String(format: "%.4f", rmsLevel))")
        print("  • Zero Crossings: \(zeroCrossings)")
        print("  • Dynamic Range: \(String(format: "%.3f", maxValue - minValue))")
    }

    private func scaleToRow(_ value: Float, _ minValue: Float, _ maxValue: Float, _ height: Int) -> Int {
        guard maxValue != minValue else { return height / 2 }
        let normalized = (value - minValue) / (maxValue - minValue)
        return max(0, min(height - 1, Int(normalized * Float(height))))
    }

    // Note: calculateRMS and countZeroCrossings moved to shared AudioUtils

    func startProcessing() {
        isProcessing = true
    }

    func isStillProcessing() -> Bool {
        return isProcessing
    }
}

// Usage example
print("🎼 Console Waveform Visualization Example")
print("========================================")

let consoleProcessor = ConsoleWaveformProcessor()

do {
    // Replace with actual audio file path
    let audioURL = URL(fileURLWithPath: "/Users/\(NSUserName())/Music/test-audio.mp3")
    print("📂 Loading audio file: \(audioURL.path)")

    let provider = try AudioWaveLibProvider(url: audioURL)
    provider.delegate = consoleProcessor

    consoleProcessor.startProcessing()
    provider.createSampleData()

    // Wait for processing to complete
    print("⏳ Processing audio data...")
    while consoleProcessor.isStillProcessing() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }

} catch AudioWaveLibProviderError.invalidURL {
    print("❌ Audio file URL is invalid")
} catch AudioWaveLibProviderError.fileInitializationFailed(let message) {
    print("❌ Could not read audio file: \(message)")
} catch {
    print("❌ Console processing failed: \(error)")
}