<!-- markdownlint-disable MD033 MD041 -->

<img
  align="right"
  alt="Logo of the AudioWaveLib"
  height="261"
  src="https://kura.pro/audiowave/images/logos/audiowave.svg"
  title="Logo of the AudioWaveLib"
  width="261"
  />

<!-- markdownlint-enable MD033 MD041 -->

# AudioWaveLib

A Swift library for processing audio files and generating waveform visualizations across iOS, macOS, watchOS, and tvOS.

## Features

- Process audio files using AVFoundation (MP3, WAV, M4A, AIFF)
- Extract PCM sample data with thread-safe access
- Generate high-quality waveform visualizations
- Asynchronous processing with GCD
- Cross-platform support with AppKit and CoreGraphics integration

## Quick Start

### Basic Usage

```swift
import AudioWaveLib

// Initialize with audio file URL
do {
    let audioURL = URL(fileURLWithPath: "/path/to/your/audio.mp3")
    let provider = try AudioWaveLibProvider(url: audioURL)
    provider.delegate = self
    provider.createSampleData()
} catch {
    print("Failed to initialize provider: \(error)")
}
```

### Implementing the Delegate

```swift
class AudioProcessor: AudioWaveLibProviderDelegate {
    func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let sampleData = provider.sampleData else { return }
        print("Processed \(sampleData.count) audio samples")

        // Generate waveform visualization
        let waveformImage = generateWaveform(from: sampleData)
        displayWaveform(waveformImage)
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        if let audioError = error as? AudioWaveLibProviderError {
            switch audioError {
            case .invalidURL:
                print("Invalid audio file URL")
            case .fileInitializationFailed(let message):
                print("File initialization failed: \(message)")
            case .invalidFrameCountOrFormat:
                print("Invalid audio format or frame count")
            case .audioProcessingFailed(let message):
                print("Processing failed: \(message)")
            }
        }
    }
}
```

## Usage Examples

### Example 1: Processing MP3 Files

```swift
import AudioWaveLib

let audioProcessor = AudioProcessor()

do {
    // Process an MP3 file
    let mp3URL = URL(fileURLWithPath: "/Users/username/Music/song.mp3")
    let provider = try AudioWaveLibProvider(url: mp3URL)
    provider.delegate = audioProcessor
    provider.createSampleData()
} catch AudioWaveLibProviderError.invalidURL {
    print("MP3 file URL is invalid")
} catch AudioWaveLibProviderError.fileInitializationFailed(let message) {
    print("Could not read MP3 file: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Example 2: Processing WAV Files with Waveform Generation

```swift
import AudioWaveLib
import Cocoa

class WaveformGenerator: AudioWaveLibProviderDelegate {
    func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let sampleData = provider.sampleData else { return }

        // Create waveform image
        let imageSize = CGSize(width: 800, height: 200)
        if let waveformImage = createWaveformImage(
            from: sampleData,
            size: imageSize,
            strokeColor: .blue,
            backgroundColor: .white
        ) {
            saveWaveformImage(waveformImage, to: "waveform.png")
        }
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        print("Error processing WAV: \(error.localizedDescription)")
    }

    private func createWaveformImage(
        from sampleData: [Float],
        size: CGSize,
        strokeColor: NSColor,
        backgroundColor: NSColor
    ) -> NSImage? {
        // Custom waveform rendering implementation
        return generateWaveformVisualization(sampleData, size, strokeColor, backgroundColor)
    }
}

// Usage
let waveformGenerator = WaveformGenerator()
do {
    let wavURL = URL(fileURLWithPath: "/Users/username/Desktop/recording.wav")
    let provider = try AudioWaveLibProvider(url: wavURL)
    provider.delegate = waveformGenerator
    provider.createSampleData()
} catch {
    print("WAV processing failed: \(error)")
}
```

### Example 3: Batch Processing Multiple Audio Formats

```swift
import AudioWaveLib

class BatchAudioProcessor: AudioWaveLibProviderDelegate {
    private var processedFiles: [String] = []
    private var currentFile: String = ""

    func processAudioFiles(_ urls: [URL]) {
        for url in urls {
            currentFile = url.lastPathComponent

            do {
                let provider = try AudioWaveLibProvider(url: url)
                provider.delegate = self
                provider.createSampleData()
            } catch {
                print("Failed to process \(currentFile): \(error)")
            }
        }
    }

    func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let sampleData = provider.sampleData else { return }

        processedFiles.append(currentFile)
        print("✓ Processed \(currentFile) - \(sampleData.count) samples")

        // Extract audio metrics
        let maxAmplitude = sampleData.max() ?? 0.0
        let minAmplitude = sampleData.min() ?? 0.0
        let rmsLevel = calculateRMS(sampleData)

        print("  Max: \(maxAmplitude), Min: \(minAmplitude), RMS: \(rmsLevel)")
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        print("✗ Error processing \(currentFile): \(error.localizedDescription)")
    }

    private func calculateRMS(_ samples: [Float]) -> Float {
        let sumSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumSquares / Float(samples.count))
    }
}

// Usage
let batchProcessor = BatchAudioProcessor()
let audioFiles = [
    URL(fileURLWithPath: "/Users/username/Audio/track1.mp3"),
    URL(fileURLWithPath: "/Users/username/Audio/track2.wav"),
    URL(fileURLWithPath: "/Users/username/Audio/track3.m4a"),
    URL(fileURLWithPath: "/Users/username/Audio/track4.aiff")
]

batchProcessor.processAudioFiles(audioFiles)
```

### Example 4: Real-time Waveform Display

```swift
import AudioWaveLib
import Cocoa

class RealtimeWaveformView: NSView, AudioWaveLibProviderDelegate {
    private var sampleData: [Float] = []
    private var waveformPath: NSBezierPath?

    func loadAudioFile(_ url: URL) {
        do {
            let provider = try AudioWaveLibProvider(url: url)
            provider.delegate = self
            provider.createSampleData()
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let data = provider.sampleData else { return }

        DispatchQueue.main.async {
            self.sampleData = data
            self.generateWaveformPath()
            self.needsDisplay = true
        }
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        DispatchQueue.main.async {
            // Show error state in UI
            self.displayError(error)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let path = waveformPath else { return }

        NSColor.black.setStroke()
        path.lineWidth = 1.0
        path.stroke()
    }

    private func generateWaveformPath() {
        guard !sampleData.isEmpty else { return }

        let path = NSBezierPath()
        let width = bounds.width
        let height = bounds.height
        let midY = height / 2

        path.move(to: NSPoint(x: 0, y: midY))

        for (index, sample) in sampleData.enumerated() {
            let x = (CGFloat(index) / CGFloat(sampleData.count)) * width
            let y = midY + (CGFloat(sample) * midY * 0.8)
            path.line(to: NSPoint(x: x, y: y))
        }

        waveformPath = path
    }

    private func displayError(_ error: Error) {
        // Custom error display implementation
    }
}

// Usage
let waveformView = RealtimeWaveformView(frame: NSRect(x: 0, y: 0, width: 600, height: 150))
waveformView.loadAudioFile(URL(fileURLWithPath: "/path/to/audio/file.mp3"))
```

### Example 5: Console Waveform Output

```swift
import AudioWaveLib

class ConsoleWaveformProcessor: AudioWaveLibProviderDelegate {
    func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let sampleData = provider.sampleData else { return }

        renderConsoleWaveform(sampleData)
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        print("Console processor error: \(error.localizedDescription)")
    }

    private func renderConsoleWaveform(_ samples: [Float]) {
        let consoleWidth = 80
        let consoleHeight = 20

        guard let maxValue = samples.max(),
              let minValue = samples.min() else { return }

        var waveform = Array(repeating: Array(repeating: " ", count: consoleWidth), count: consoleHeight)

        for columnIndex in 0..<consoleWidth {
            let startIndex = columnIndex * samples.count / consoleWidth
            let endIndex = min((columnIndex + 1) * samples.count / consoleWidth, samples.count)
            let columnSamples = Array(samples[startIndex..<endIndex])

            guard let columnMax = columnSamples.max(),
                  let columnMin = columnSamples.min() else { continue }

            let maxRow = scaleToRow(columnMax, minValue, maxValue, consoleHeight)
            let minRow = scaleToRow(columnMin, minValue, maxValue, consoleHeight)

            for rowIndex in minRow..<maxRow {
                waveform[rowIndex][columnIndex] = "█"
            }
        }

        print("\nAudio Waveform:")
        print(String(repeating: "-", count: consoleWidth + 2))

        for row in waveform.reversed() {
            print("|" + row.joined() + "|")
        }

        print(String(repeating: "-", count: consoleWidth + 2))
        print("Duration: \(samples.count) samples | Range: \(minValue)...\(maxValue)")
    }

    private func scaleToRow(_ value: Float, _ minValue: Float, _ maxValue: Float, _ height: Int) -> Int {
        let normalized = (value - minValue) / (maxValue - minValue)
        return Int(normalized * Float(height))
    }
}

// Usage
let consoleProcessor = ConsoleWaveformProcessor()
do {
    let audioURL = URL(fileURLWithPath: "/Users/username/test-audio.mp3")
    let provider = try AudioWaveLibProvider(url: audioURL)
    provider.delegate = consoleProcessor
    provider.createSampleData()
} catch {
    print("Console processing failed: \(error)")
}
```

## Platform Support

- **iOS 13.0+** - Full audio processing and waveform generation
- **macOS 10.15+** - Complete feature set with AppKit integration
- **watchOS 6.0+** - Audio processing (limited visualization)
- **tvOS 13.0+** - Audio processing with UIKit integration

## Installation

### Swift Package Manager

Add AudioWaveLib as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sebastienrousseau/AudioWaveLib.git", from: "0.0.2")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter repository URL
3. Select version and target

## API Reference

### AudioWaveLibProvider

Main class for audio processing.

**Initialization:**
- `init(url: URL) throws` - Initialize with audio file URL

**Properties:**
- `sampleData: [Float]?` - Thread-safe access to processed audio samples
- `delegate: AudioWaveLibProviderDelegate?` - Delegate for callbacks

**Methods:**
- `createSampleData()` - Start asynchronous audio processing

### AudioWaveLibProviderDelegate

Protocol for receiving processing updates.

**Required Methods:**
- `sampleProcessed(provider: AudioWaveLibProvider)` - Called when processing completes
- `statusUpdated(provider: AudioWaveLibProvider, withError error: Error)` - Called on errors

### AudioWaveLibProviderError

Enumeration of possible errors:
- `invalidURL` - The provided URL is invalid
- `fileInitializationFailed(String)` - Cannot read the audio file
- `invalidFrameCountOrFormat` - Invalid audio format or frame count
- `audioProcessingFailed(String)` - Processing operation failed

## Requirements

- **Xcode 13.0+**
- **Swift 5.5+**
- **Deployment targets:** iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+

## Contributing

Read our [Contributing Guide](CONTRIBUTING.md) for development setup and guidelines.

## License

AudioWaveLib is released under the [zlib License](LICENSE.txt).
