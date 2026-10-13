# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.3] - 2026-10-13

### Added

- Canonical README documentation conforming to repository gold standards.
- Project governance documentation including AGENTS.md, SECURITY.md, and DEVELOPMENT.md.

### Changed

- Updated version constant and test expectations to 0.0.3.
- Aligned documentation license pointers with dual Apache-2.0 OR MIT grants.

## [0.0.2] - 2026-10-13

### Added

- Chunked memory allocation with configurable memory pressure handling.
- Autoreleasepool cleanup and thread-safe copy-on-write semantics.
- Comprehensive batch processing and waveform visualization examples.
- Dual licensing under Apache-2.0 OR MIT with aligned SPDX identifiers.

### Fixed

- Resolved data race conditions on sample data via NSLock synchronization.
- Guarded chunk processing loop against zero-frame reads.
- Synchronized processing task cancellation checks across queues.
- Resolved SwiftLint violations across source and test files.

## [0.0.1] - 2024-06-05

### Added

- Initial release of AudioWaveLib.
- AVFoundation audio file processing for waveform visualizations across Apple platforms.
