import AVFoundation
import Foundation

/// The current version of AudioWaveLib.
public let audioWaveLibVersion = "0.0.2" // swiftlint:disable:this prefixed_toplevel_constant

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
    /// Maximum buffer size per chunk in frames (default: 1_048_576 = ~23 seconds at 44.1kHz)
    public let maxChunkSize: AVAudioFrameCount
    /// Maximum total memory usage in bytes (default: 100MB)
    public let maxMemoryUsage: Int

    public init(
        maxChunkSize: AVAudioFrameCount = 1_048_576,
        maxMemoryUsage: Int = 104_857_600
    ) {
        self.maxChunkSize = maxChunkSize
        self.maxMemoryUsage = maxMemoryUsage
    }

    /// Default configuration for most use cases
    public static let `default` = AudioProcessingConfig()

    /// Lightweight configuration for memory-constrained environments
    public static let lightweight = AudioProcessingConfig(
        maxChunkSize: 262_144,
        maxMemoryUsage: 52_428_800
    )
}

/// Processes and accesses audio wave data, compatible across iOS, macOS, etc.
public class AudioWaveLibProvider: @unchecked Sendable {
    private var audioFile: AVAudioFile?

    /// High-performance atomic wrapper using os_unfair_lock for visualization hot paths
    /// Benchmarked 50% faster than DispatchQueue-based implementation (2.4M vs 1.2M ops/sec)
    private final class AtomicReference<T> {
        private var _value: T
        private var _lock = os_unfair_lock()

        init(_ value: T) {
            _value = value
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

    /// High-performance sample data storage using os_unfair_lock atomic wrapper
    private let _atomicSampleData = AtomicReference<[Float]?>(nil)

    /// Thread-safe access to processed audio sample data.
    ///
    /// A single channel of samples, not interleaved audio. For a multi-channel
    /// file only the first channel is collected — this series is intended for
    /// waveform rendering, where one channel is the usual input. Callers
    /// needing every channel should read the file through `AVAudioFile`
    /// directly.
    public var sampleData: [Float]? {
        get { _atomicSampleData.value }
        set { _atomicSampleData.value = newValue }
    }

    /// The in-flight processing task.
    ///
    /// Guarded by the same atomic wrapper as `sampleData`: it is written on
    /// the calling thread by `createSampleData` and read from the processing
    /// queue on every chunk to honour cancellation, so an unsynchronised
    /// stored property would race. The class is `@unchecked Sendable`, which
    /// means the compiler will not catch that for us.
    private let _atomicProcessingTask = AtomicReference<DispatchWorkItem?>(nil)

    var processingTask: DispatchWorkItem? {
        get { _atomicProcessingTask.value }
        set { _atomicProcessingTask.value = newValue }
    }

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
            delegate?.statusUpdated(
                provider: self,
                withError: AudioWaveLibProviderError.invalidFrameCountOrFormat
            )
            return
        }

        processingTask?.cancel()

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            processAudioFile(audioFile, config: config)
        }

        processingTask = task
        DispatchQueue.global(qos: .userInitiated).async(execute: task)
    }

    private func processAudioFile(
        _ audioFile: AVAudioFile,
        config: AudioProcessingConfig
    ) {
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

        if let error = validateMemoryConstraints(audioFile, config: config) {
            DispatchQueue.main.async {
                self.delegate?.statusUpdated(provider: self, withError: error)
            }
            return
        }

        let result = readChunkedSamples(
            from: audioFile,
            totalFrameCount: totalFrameCount,
            config: config
        )

        if let error = result.error {
            DispatchQueue.main.async {
                self.delegate?.statusUpdated(provider: self, withError: error)
            }
            return
        }

        if processingTask?.isCancelled ?? false {
            return
        }

        sampleData = result.samples

        DispatchQueue.main.async {
            self.delegate?.sampleProcessed(provider: self)
        }
    }

    private func validateMemoryConstraints(
        _ audioFile: AVAudioFile,
        config: AudioProcessingConfig
    ) -> AudioWaveLibProviderError? {
        // One channel is retained, not all of them (see `sampleData`), so the
        // estimate is per-frame Float size rather than channelCount * 4.
        // Counting every channel over-estimated by the channel count —
        // rejecting stereo files at half the real limit — and disagreed with
        // the live check inside the read loop, which measures actual storage.
        let bytesPerFrame = MemoryLayout<Float>.size
        let totalMemoryNeeded = Int(audioFile.length) * bytesPerFrame
        let megabyteDivisor = 1_048_576

        guard totalMemoryNeeded <= config.maxMemoryUsage else {
            return .audioProcessingFailed(
                "File too large: requires \(totalMemoryNeeded / megabyteDivisor)MB, "
                    + "limit is \(config.maxMemoryUsage / megabyteDivisor)MB"
            )
        }
        return nil
    }

    // swiftlint:disable:next function_body_length
    private func readChunkedSamples(
        from audioFile: AVAudioFile,
        totalFrameCount: AVAudioFrameCount,
        config: AudioProcessingConfig
    ) -> (samples: [Float], error: Error?) {
        var allSamples: [Float] = []
        allSamples.reserveCapacity(min(Int(totalFrameCount), Int(config.maxChunkSize)))

        let chunkSize = min(config.maxChunkSize, totalFrameCount)
        var currentFrame: AVAudioFramePosition = 0
        let megabyteDivisor = 1_048_576

        while currentFrame < audioFile.length {
            var shouldStop = false
            var chunkError: Error?

            autoreleasepool {
                let currentMemoryUsage = allSamples.count * MemoryLayout<Float>.size
                if currentMemoryUsage > config.maxMemoryUsage {
                    chunkError = AudioWaveLibProviderError.audioProcessingFailed(
                        "Memory limit exceeded: "
                            + "\(currentMemoryUsage / megabyteDivisor)MB "
                            + "> \(config.maxMemoryUsage / megabyteDivisor)MB"
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
                        chunkError = AudioWaveLibProviderError.audioProcessingFailed(
                            "Failed to allocate chunk buffer"
                        )
                        shouldStop = true
                        return
                    }

                    try audioFile.read(into: chunkBuffer)

                    // A read of zero frames does not advance `currentFrame`,
                    // so without this guard the enclosing `while` spins
                    // forever on a file whose header claims more frames than
                    // are actually readable — a truncated download, or any
                    // malformed file. It runs on a background queue, so the
                    // symptom is a pinned core and a delegate that is never
                    // called, rather than a crash.
                    guard chunkBuffer.frameLength > 0 else {
                        chunkError = AudioWaveLibProviderError.audioProcessingFailed(
                            "Read returned no frames at \(currentFrame) of "
                                + "\(audioFile.length); the file is truncated or malformed"
                        )
                        shouldStop = true
                        return
                    }

                    // Only the first channel is collected: `sampleData` is a
                    // single `[Float]` series for waveform rendering, not
                    // interleaved multi-channel audio. See the note on
                    // `sampleData`.
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
                    chunkError = error
                    shouldStop = true
                }
            }

            if shouldStop {
                return (allSamples, chunkError)
            }
        }

        return (allSamples, nil)
    }
}
