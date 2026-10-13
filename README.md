<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

<p align="center">
  <img src="https://kura.pro/audiowave/images/logos/audiowave.svg" alt="AudioWaveLib logo" width="128" />
</p>

<h1 align="center">AudioWaveLib</h1>

<p align="center">
  A high-performance Swift library for processing audio files and generating waveform visualizations across Apple platforms.
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/AudioWaveLib/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/AudioWaveLib/build.yml?style=for-the-badge&logo=github" alt="Build" height="28" /></a>
  <a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SwiftPM-compatible-orange?style=for-the-badge&logo=swift" alt="SwiftPM" height="28" /></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/AudioWaveLib"><img src="https://img.shields.io/ossf-scorecard/github.com/sebastienrousseau/AudioWaveLib?style=for-the-badge&label=OpenSSF%20Scorecard&logo=openssf" alt="OpenSSF Scorecard" height="28" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg?style=for-the-badge" alt="License: Apache-2.0 OR MIT" height="28" /></a>
  <a href="Package.swift"><img src="https://img.shields.io/badge/Swift-5.5+-93450a.svg?style=for-the-badge&logo=swift" alt="Swift 5.5+" height="28" /></a>
</p>

---

## Contents

**Getting started**

- [Install](#install) - Swift Package Manager dependency
- [Requirements](#requirements) - toolchain floor and supported platforms
- [Quick Start](#quick-start) - basic audio provider setup

**Library reference**

- [Capabilities at a glance](#capabilities-at-a-glance) - core features and processing pipeline
- [API Reference](#api-reference) - provider, protocols, and error types
- [Examples](#examples) - visual waveform and batch processing

**Operational**

- [When not to use AudioWaveLib](#when-not-to-use-audiowavelib) - limitations
- [Development](#development) - building and running tests
- [Security](#security) - reporting vulnerabilities
- [Documentation](#documentation) - reference guides
- [Stability guarantees](#stability-guarantees) - SemVer policy
- [License](#license) - Apache-2.0 OR MIT

---

## Install

### As a Swift Package

Add AudioWaveLib to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/sebastienrousseau/AudioWaveLib.git", from: "0.0.3")
]
```

Or add it directly in Xcode via **File > Add Packages...** using the repository URL.

---

## Requirements

- **Swift**: 5.5 or later
- **Xcode**: 13.0 or later
- **Platform targets**:
  - macOS 10.15+
  - iOS 13.0+
  - tvOS 13.0+
  - watchOS 6.0+

---

## Quick Start

```swift
import AudioWaveLib
import Foundation

// Initialize with an audio file URL
do {
    let audioURL = URL(fileURLWithPath: "/path/to/audio.mp3")
    let provider = try AudioWaveLibProvider(url: audioURL)
    provider.delegate = self
    provider.createSampleData()
} catch {
    print("Failed to initialize provider: \(error)")
}
```

Implement the delegate protocol to receive samples:

```swift
extension MyAudioVisualizer: AudioWaveLibProviderDelegate {
    func sampleProcessed(provider: AudioWaveLibProvider) {
        guard let samples = provider.sampleData else { return }
        print("Processed \(samples.count) audio samples")
    }

    func statusUpdated(provider: AudioWaveLibProvider, withError error: Error) {
        print("Processing error: \(error.localizedDescription)")
    }
}
```

---

## Capabilities at a glance

- **AVFoundation Integration**: Decodes MP3, WAV, M4A, and AIFF audio files.
- **Chunked Allocation**: Bounded memory footprint with autoreleasepool chunk collection.
- **Thread Safety**: NSLock synchronized access to sample data and cancellation tokens.
- **Cross-Platform**: Zero third-party dependencies; uses native Apple frameworks only.

---

## API Reference

### AudioWaveLibProvider

Primary processing engine for audio files.

- `init(url: URL) throws`: Initialise with a file URL.
- `var sampleData: [Float]?`: Thread-safe access to processed float samples.
- `weak var delegate: AudioWaveLibProviderDelegate?`: Callback receiver for results.
- `func createSampleData()`: Dispatches asynchronous decoding and normalization.

### AudioWaveLibProviderDelegate

Protocol for receiving callbacks:
- `func sampleProcessed(provider: AudioWaveLibProvider)`: Invoked when sample extraction finishes.
- `func statusUpdated(provider: AudioWaveLibProvider, withError error: Error)`: Invoked on errors.

### AudioWaveLibProviderError

- `invalidURL`: The specified URL is invalid or inaccessible.
- `fileInitializationFailed(String)`: AVAudioFile failed to open the resource.
- `invalidFrameCountOrFormat`: Audio format contains invalid channels or zero frame count.
- `audioProcessingFailed(String)`: Processing encountered an unrecoverable failure.

---

## Examples

Runnable example projects are located in [`Examples/`](Examples/):
- **ConsoleWaveform**: Generates ASCII waveform previews directly in the terminal.
- **BatchProcessing**: Processes multiple audio files concurrently.
- **AudioWaveLibSample**: AppKit waveform drawing canvas.

---

## When not to use AudioWaveLib

- **Non-Apple platforms**: AVFoundation is an Apple platform framework; Linux/Windows builds are unsupported.
- **Real-time microphone input**: AudioWaveLib is designed for static audio file processing, not live audio stream buffering.

---

## Development

```bash
# Build library targets
swift build

# Run unit and performance test suite
swift test
```

---

## Security

Report vulnerabilities according to [`SECURITY.md`](SECURITY.md).

---

## Documentation

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

---

## Stability guarantees

AudioWaveLib adheres to [Semantic Versioning 2.0.0](https://semver.org/). Public API surfaces remain backward-compatible within major versions.

---

## License

Copyright © 2026 <a href="https://sebastienrousseau.com/" rel="author">Sebastien Rousseau</a>. All rights reserved.

Licensed under either the [Apache License, Version 2.0](LICENSE-APACHE) or the [MIT License](LICENSE-MIT) at your option.
