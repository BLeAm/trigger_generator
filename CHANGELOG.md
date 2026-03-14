# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-05

### Added
- Implement lazy singleton pattern for `Trigger` instances.
- Integration with `UpdateScheduler` for improved state notification management.
- Support for `Master Effects` declaration directly in `@TriggerGen` annotation.
- Automatic wrapping of `List`, `Map`, and `Set` in unmodifiable views for enhanced data integrity.
- `multiSet` support for batch updates with a single notification.
- Detailed `README.md` with usage instructions and feature overview.

### Changed
- **Performance**: Reimplemented `TriggerGenerator` to use index-based field access, providing O(1) performance for state updates.
- Updated `analyzer` and `source_gen` dependencies.

### Fixed
- Improved generated file ignore headers for better IDE experience and reduced warnings.

## [0.0.1] - 2026-02-11

### Added
- Initial development version.
- Basic code generation for `Trigger` classes from annotated definitions.
