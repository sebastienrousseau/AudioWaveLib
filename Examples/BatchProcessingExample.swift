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

    static func extractAudioMetrics(_ samples: [Float]) -> [String: Float] {
        guard !samples.isEmpty else { return [:] }
        let maxAmplitude = samples.max() ?? 0.0
        let minAmplitude = samples.min() ?? 0.0
        let rmsLevel = calculateRMS(samples)
        return [
            "maxAmplitude": maxAmplitude,
            "minAmplitude": minAmplitude,
            "rmsLevel": rmsLevel,
            "sampleCount": Float(samples.count)
        ]
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

// Example: Batch Processing Multiple Audio Formats
class BatchAudioProcessor: BaseAudioDelegate {
    private var processedFiles: [String] = []
    private var currentFile: String = ""
    private var totalFiles: Int = 0
    private var processedCount: Int = 0

    func processAudioFiles(_ urls: [URL]) {
        totalFiles = urls.count
        processedCount = 0

        print("Starting batch processing of \(totalFiles) audio files...")

        for url in urls {
            currentFile = url.lastPathComponent

            do {
                let provider = try AudioWaveLibProvider(url: url)
                provider.delegate = self
                provider.createSampleData()
            } catch {
                print("Failed to process \(currentFile): \(error)")
                processedCount += 1
                checkCompletion()
            }
        }
    }

    override func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let sampleData = provider.sampleData else { return }

        processedFiles.append(currentFile)
        processedCount += 1

        print("✓ Processed \(currentFile) - \(sampleData.count) samples")

        // Extract audio metrics using shared utilities
        let metrics = AudioUtils.extractAudioMetrics(sampleData)
        print("  Max: \(String(format: "%.3f", metrics["maxAmplitude"] ?? 0)), " +
              "Min: \(String(format: "%.3f", metrics["minAmplitude"] ?? 0)), " +
              "RMS: \(String(format: "%.3f", metrics["rmsLevel"] ?? 0))")

        checkCompletion()
    }

    override func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        print("✗ Error processing \(currentFile): \(error.localizedDescription)")
        processedCount += 1
        checkCompletion()
    }

    private func checkCompletion() {
        if processedCount >= totalFiles {
            print("\nBatch processing complete!")
            print("Successfully processed: \(processedFiles.count)/\(totalFiles) files")
            exit(0)
        }
    }
}

// Usage example
let batchProcessor = BatchAudioProcessor()

// Example file paths - replace with actual audio files
let audioFiles = [
    URL(fileURLWithPath: "/Users/\(NSUserName())/Music/track1.mp3"),
    URL(fileURLWithPath: "/Users/\(NSUserName())/Music/track2.wav"),
    URL(fileURLWithPath: "/Users/\(NSUserName())/Music/track3.m4a"),
    URL(fileURLWithPath: "/Users/\(NSUserName())/Music/track4.aiff")
]

print("Batch Audio Processing Example")
print("===============================")

batchProcessor.processAudioFiles(audioFiles)

// Keep the script running to receive all delegate callbacks
RunLoop.current.run(until: Date(timeIntervalSinceNow: 30))