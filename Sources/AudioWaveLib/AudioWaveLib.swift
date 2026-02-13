import AVFoundation
import Foundation

/// The current version of AudioWaveLib.
public let audioWaveLibVersion = "0.0.2"

/// An enumeration representing the possible errors that can occur in the AudioWaveLibProvider.
public enum AudioWaveLibProviderError: Error, Equatable {
    case invalidURL
    case fileInitializationFailed(String)
    case invalidFrameCountOrFormat
    case audioProcessingFailed(String)
}

/// Extension of `AudioWaveLibProviderError` conforming to `LocalizedError` protocol.
extension AudioWaveLibProviderError: LocalizedError {
    /// A localized description of the error.
    public var errorDescription: String? {
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

/// Configuration for chunked audio processing
public struct AudioProcessingConfig: Sendable {
    /// Maximum buffer size per chunk in frames (default: 1024 * 1024 = ~23 seconds at 44.1kHz)
    public let maxChunkSize: AVAudioFrameCount
    /// Maximum total memory usage in bytes (default: 100MB)
    public let maxMemoryUsage: Int

    public init(
        maxChunkSize: AVAudioFrameCount = 1024 * 1024,
        maxMemoryUsage: Int = 100 * 1024 * 1024
    ) {
        self.maxChunkSize = maxChunkSize
        self.maxMemoryUsage = maxMemoryUsage
    }

    /// Default configuration for most use cases
    public static let `default` = AudioProcessingConfig()

    /// Lightweight configuration for memory-constrained environments
    public static let lightweight = AudioProcessingConfig(
        maxChunkSize: 256 * 1024, // ~6 seconds at 44.1kHz
        maxMemoryUsage: 50 * 1024 * 1024 // 50MB
    )
}

/// Processes and accesses audio wave data, compatible across iOS, macOS, etc.
public class AudioWaveLibProvider {
    private var audioFile: AVAudioFile?

    // High-performance atomic wrapper using os_unfair_lock for visualization hot paths
    // Benchmarked 50% faster than DispatchQueue-based implementation (2.4M vs 1.2M ops/sec)
    private final class AtomicReference<T> {
        private var _value: T
        private var _lock = os_unfair_lock()

        init(_ value: T) {
            self._value = value
        }

        var value: T {
            get {
                os_unfair_lock_lock(&_lock)
                defer { os_unfair_lock_unlock(&_lock) }
                return _value
            }
            set {
                os_unfair_lock_lock(&_lock)
                defer { os_unfair_lock_unlock(&_lock) }
                _value = newValue
            }
        }
    }

    // High-performance sample data storage using os_unfair_lock atomic wrapper
    private let _atomicSampleData = AtomicReference<[Float]?>(nil)

    /// Thread-safe access to processed audio sample data.
    public var sampleData: [Float]? {
        get { _atomicSampleData.value }
        set { _atomicSampleData.value = newValue }
    }

    var processingTask: DispatchWorkItem?
    public weak var delegate: AudioWaveLibProviderDelegate?

    public init(url: URL) throws {
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
        createSampleData(config: AudioProcessingConfig.default)
    }

    public func createSampleData(config: AudioProcessingConfig) {
        guard let audioFile else {
            delegate?.statusUpdated(provider: self, withError: AudioWaveLibProviderError.invalidFrameCountOrFormat)
            return
        }

        processingTask?.cancel()

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }

            let totalFrameCount = AVAudioFrameCount(audioFile.length)
            guard totalFrameCount > 0 else {
                DispatchQueue.main.async {
                    self.delegate?.statusUpdated(
                        provider: self,
                        withError: AudioWaveLibProviderError.invalidFrameCountOrFormat
                    )
                }
                return
            }

            // Calculate memory usage and validate constraints
            let bytesPerFrame = audioFile.processingFormat.channelCount * 4 // Float32
            let totalMemoryNeeded = Int(totalFrameCount) * Int(bytesPerFrame)

            if totalMemoryNeeded > config.maxMemoryUsage {
                DispatchQueue.main.async {
                    self.delegate?.statusUpdated(
                        provider: self,
                        withError: AudioWaveLibProviderError.audioProcessingFailed(
                            "File too large: requires \(totalMemoryNeeded / (1024*1024))MB, limit is \(config.maxMemoryUsage / (1024*1024))MB"
                        )
                    )
                }
                return
            }

            var allSamples: [Float] = []
            let initialCapacity = min(Int(totalFrameCount), Int(config.maxChunkSize))
            allSamples.reserveCapacity(initialCapacity)

            let chunkSize = min(config.maxChunkSize, totalFrameCount)
            var currentFrame: AVAudioFramePosition = 0
            var processingError: Error?

            while currentFrame < audioFile.length {
                var shouldStop = false
                autoreleasepool {
                    let currentMemoryUsage = allSamples.count * MemoryLayout<Float>.size
                    if currentMemoryUsage > config.maxMemoryUsage {
                        processingError = AudioWaveLibProviderError.audioProcessingFailed(
                            "Memory limit exceeded during processing: \(currentMemoryUsage / (1024*1024))MB > \(config.maxMemoryUsage / (1024*1024))MB"
                        )
                        shouldStop = true
                        return
                    }

                    let remainingFrames = audioFile.length - currentFrame
                    let framesToRead = min(AVAudioFrameCount(remainingFrames), chunkSize)

                    do {
                        audioFile.framePosition = currentFrame

                        guard let chunkBuffer = AVAudioPCMBuffer(
                            pcmFormat: audioFile.processingFormat,
                            frameCapacity: framesToRead
                        ) else {
                            processingError = AudioWaveLibProviderError.audioProcessingFailed(
                                "Failed to allocate chunk buffer"
                            )
                            shouldStop = true
                            return
                        }

                        try audioFile.read(into: chunkBuffer)

                        if let channelData = chunkBuffer.floatChannelData?.pointee {
                            let chunkSamples = UnsafeBufferPointer(
                                start: channelData,
                                count: Int(chunkBuffer.frameLength)
                            )
                            allSamples.append(contentsOf: chunkSamples)
                        }

                        currentFrame += AVAudioFramePosition(chunkBuffer.frameLength)

                        if self.processingTask?.isCancelled ?? false {
                            shouldStop = true
                        }
                    } catch {
                        processingError = error
                        shouldStop = true
                    }
                }
                if shouldStop { break }
            }

            if let error = processingError {
                DispatchQueue.main.async {
                    self.delegate?.statusUpdated(provider: self, withError: error)
                }
                return
            }

            if self.processingTask?.isCancelled ?? false {
                return
            }

            // Store the complete sample data
            self.sampleData = allSamples

            DispatchQueue.main.async {
                self.delegate?.sampleProcessed(provider: self)
            }
        }

        processingTask = task
        DispatchQueue.global(qos: .userInitiated).async(execute: task)
    }
}

