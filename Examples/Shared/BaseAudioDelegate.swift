import Foundation
import AudioWaveLib

/// Base delegate class providing common functionality for audio processing examples.
/// Subclass this to inherit standard error handling and basic metrics.
open class BaseAudioDelegate: NSObject, AudioWaveLibProviderDelegate {

    /// Override this method to handle successful audio processing.
    /// The base implementation prints basic metrics.
    /// - Parameter provider: The AudioWaveLibProvider instance
    open func sampleProcessed(provider: AudioWaveLibProvider) {
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

    /// Standard error handling for AudioWaveLibProvider errors.
    /// Override to customize error handling behavior.
    /// - Parameters:
    ///   - provider: The AudioWaveLibProvider instance
    ///   - error: The error that occurred
    open func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
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