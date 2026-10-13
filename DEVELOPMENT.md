# Development Guide

This document describes how to build, test, and contribute to AudioWaveLib.

## Prerequisites

- macOS 14.0 or later
- Xcode 15 or later with Command Line Tools (`xcode-select --install`)
- Swift 5.9 or later

## Building and Testing

### Swift Package Manager

```bash
# Build all targets in debug mode
swift build

# Run the test suite with code coverage enabled
swift test --enable-code-coverage

# Build release artifacts
swift build -c release
```

## Code Quality and Style

AudioWaveLib enforces code style with SwiftLint and SwiftFormat:

```bash
# Format sources
swiftformat .

# Lint code
swiftlint --strict
```

## Release Workflow

All releases follow semantic versioning incrementing by `0.0.1` per iteration on branch `feat/v<next-version>`.
