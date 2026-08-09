import Foundation

/// Utility functions for audio processing shared across examples.
public struct AudioUtils {
    /// Calculate Root Mean Square (RMS) level of audio samples.
    /// - Parameter samples: Array of audio sample values
    /// - Returns: RMS level as Float
    public static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        let sumSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumSquares / Float(samples.count))
    }

    /// Count zero crossings in audio samples.
    /// - Parameter samples: Array of audio sample values
    /// - Returns: Number of zero crossings
    public static func countZeroCrossings(_ samples: [Float]) -> Int {
        guard samples.count > 1 else { return 0 }
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i-1] >= 0 && samples[i] < 0) || (samples[i-1] < 0 && samples[i] >= 0) {
                crossings += 1
            }
        }
        return crossings
    }

    /// Extract basic audio metrics from sample data.
    /// - Parameter samples: Array of audio sample values
    /// - Returns: Dictionary containing audio metrics
    public static func extractAudioMetrics(_ samples: [Float]) -> [String: Float] {
        guard !samples.isEmpty else { return [:] }

        let maxAmplitude = samples.max() ?? 0.0
        let minAmplitude = samples.min() ?? 0.0
        let rmsLevel = calculateRMS(samples)
        let dynamicRange = maxAmplitude - minAmplitude
        let zeroCrossings = Float(countZeroCrossings(samples))

        return [
            "maxAmplitude": maxAmplitude,
            "minAmplitude": minAmplitude,
            "rmsLevel": rmsLevel,
            "dynamicRange": dynamicRange,
            "zeroCrossings": zeroCrossings,
            "sampleCount": Float(samples.count)
        ]
    }
}