import AVFoundation
import Foundation

/// An enumeration representing the possible errors that can occur in the AudioWaveLibProvider.
enum AudioWaveLibProviderError: Error {
    case invalidURL
    case fileInitializationFailed(String)
    case invalidFrameCountOrFormat
    case audioProcessingFailed(String)
}

/// Extension of `AudioWaveLibProviderError` conforming to `LocalizedError` protocol.
extension AudioWaveLibProviderError: LocalizedError {
    /// A localized description of the error.
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

/// A protocol that defines the delegate methods for an AudioWaveLibProvider.
public protocol AudioWaveLibProviderDelegate: AnyObject {
    /// Notifies the delegate that a sample has been processed.
    ///
    /// - Parameter provider: The AudioWaveLibProvider instance.
    func sampleProcessed(provider: AudioWaveLibProvider)

    /// Notifies the delegate that the status of the AudioWaveLibProvider has been updated.
    ///
    /// - Parameters:
    ///   - provider: The AudioWaveLibProvider instance.
    ///   - error: An optional error object if there was an error during the update.
    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error)
}

/// Processes and accesses audio wave data, compatible across iOS, macOS, etc.
public class AudioWaveLibProvider: NSObject {
    private var audioFile: AVAudioFile?
    public var sampleData: [Float]?
    var processingTask: DispatchWorkItem?
    public weak var delegate: AudioWaveLibProviderDelegate?

    public init(url: URL) throws {
        super.init()
        guard url.isFileURL else {
            throw AudioWaveLibProviderError.invalidURL
        }
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw AudioWaveLibProviderError.fileInitializationFailed(error.localizedDescription)
        }
    }

    public func createSampleData() {
        guard let audioFile else {
            delegate?.statusUpdated(provider: self, withError: AudioWaveLibProviderError.invalidFrameCountOrFormat)
            return
        }

        processingTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard frameCount > 0 else {
                delegate?.statusUpdated(
                    provider: self,
                    withError: AudioWaveLibProviderError.invalidFrameCountOrFormat
                )
                return
            }

            do {
                let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount)
                try audioFile.read(into: buffer!)
                if let channelData = buffer?.floatChannelData?.pointee {
                    let data = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer!.frameLength)))
                    sampleData = data
                    DispatchQueue.main.async {
                        self.delegate?.sampleProcessed(provider: self)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.statusUpdated(provider: self, withError: error)
                }
            }
        }

        processingTask = task
        DispatchQueue.global(qos: .userInitiated).async(execute: task)
    }

    public func getSampleData() -> [Float]? {
        sampleData
    }
}

/// A delegate class for printing waveform in the console.
class DemoDelegate: AudioWaveLibProviderDelegate {
    func sampleProcessed(provider: AudioWaveLibProvider) {
        if let sampleData = provider.getSampleData() {
            let consoleWidth = 80
            let consoleHeight = 20
            let maxValue = sampleData.max() ?? 0
            let minValue = sampleData.min() ?? 0

            // Generate ASCII art waveform
            var waveform = [[Character]](
                repeating: [Character](repeating: " ",
                                       count: consoleWidth), count: consoleHeight
            )
            for columnIndex in 0 ..< consoleWidth {
                let startIndex = columnIndex * sampleData.count / consoleWidth
                let endIndex = min((columnIndex + 1) * sampleData.count / consoleWidth, sampleData.count)
                let columnSamples = sampleData[startIndex ..< endIndex]

                let columnMax = columnSamples.max() ?? 0
                let columnMin = columnSamples.min() ?? 0

                let scaledColumnHeight = scaleHeight(columnMax, minValue, maxValue, consoleHeight)
                let scaledColumnMinHeight = scaleHeight(columnMin, minValue, maxValue, consoleHeight)

                for rowIndex in scaledColumnMinHeight ..< scaledColumnHeight {
                    waveform[rowIndex][columnIndex] = "|"
                }
            }

            // Print ASCII art waveform
            for row in waveform.reversed() {
                print(String(row))
            }
        } else {
            print("No sample data available.")
        }
    }

    func statusUpdated(provider _: AudioWaveLibProvider, withError error: Error) {
        print("An error occurred: \(error.localizedDescription)")
    }

    private func scaleHeight(_ value: Float, _ minValue: Float, _ maxValue: Float, _ consoleHeight: Int) -> Int {
        let normalizedValue = (value - minValue) / (maxValue - minValue)
        return Int(normalizedValue * Float(consoleHeight))
    }
}
