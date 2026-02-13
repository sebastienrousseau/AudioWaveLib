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

        let metrics = AudioUtils.extractAudioMetrics(sampleData)
        print("Sample processed - \(Int(metrics["sampleCount"] ?? 0)) samples")
        print("Audio metrics: Max: \(String(format: "%.3f", metrics["maxAmplitude"] ?? 0)), " +
              "Min: \(String(format: "%.3f", metrics["minAmplitude"] ?? 0)), " +
              "RMS: \(String(format: "%.3f", metrics["rmsLevel"] ?? 0))")
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

// Example 1: Processing MP3 Files
class AudioProcessor: BaseAudioDelegate {
    override func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let sampleData = provider.sampleData else { return }
        print("Processed \(sampleData.count) audio samples")

        // Extract detailed audio metrics using shared utilities
        let metrics = AudioUtils.extractAudioMetrics(sampleData)

        print("Audio Analysis:")
        print("  - Samples: \(Int(metrics["sampleCount"] ?? 0))")
        print("  - Max Amplitude: \(String(format: "%.6f", metrics["maxAmplitude"] ?? 0))")
        print("  - Min Amplitude: \(String(format: "%.6f", metrics["minAmplitude"] ?? 0))")
        print("  - RMS Level: \(String(format: "%.6f", metrics["rmsLevel"] ?? 0))")
    }
}

// Usage example
let audioProcessor = AudioProcessor()

do {
    // Process an MP3 file - replace with actual file path
    let mp3URL = URL(fileURLWithPath: "/Users/\(NSUserName())/Music/sample.mp3")
    print("Processing MP3 file: \(mp3URL.path)")

    let provider = try AudioWaveLibProvider(url: mp3URL)
    provider.delegate = audioProcessor
    provider.createSampleData()

    // Keep the script running to receive delegate callbacks
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 5))

} catch AudioWaveLibProviderError.invalidURL {
    print("MP3 file URL is invalid")
} catch AudioWaveLibProviderError.fileInitializationFailed(let message) {
    print("Could not read MP3 file: \(message)")
} catch {
    print("Unexpected error: \(error)")
}