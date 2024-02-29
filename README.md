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

AudioWaveLib is a Swift library for processing audio files and generating waveform visualizations.

## Features

- Read audio files using AVFoundation
- Extract PCM sample data from audio files
- Generate waveform images from sample data
- Asynchronous processing using GCD
- Support for macOS AppKit graphics and waveform rendering

## Usage

To use AudioWaveLib:

1. Create an `AudioWaveLibProvider` instance with audio file URL
2. Set a delegate to receive callbacks
3. Call `createSampleData()` to process the file

```swift
let url = URL(filePath: "file.mp3")
let provider = AudioWaveLibProvider(url: url)
provider.delegate = self
provider.createSampleData()
```

Implement the `AudioWaveLibProviderDelegate` to handle updates:

```swift
func sampleProcessed(provider: AudioWaveLibProvider) {
  if let data = provider.getSampleData() {
    // Render waveform from sample data
  }
}

func statusUpdated(provider: AudioWaveLibProvider, error: Error) {
  // Handle error
}
```

Use AppKit to render waveform images:

```swift
let image = generateWaveformImage(sampleData: data, size: CGSize(width: 400, height: 100))
```

See `main.swift` for a complete AppKit waveform rendering example.

## Requirements

- iOS 13+
- macOS 10.15+
- Xcode 13+
- Swift 5.5+

## Installation

Add AudioWaveLib as a Swift Package dependency.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

AudioWaveLib is released under the [zlib License](LICENSE.txt).
