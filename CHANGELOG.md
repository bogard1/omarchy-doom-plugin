# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-15

### Changed

- Updated palette references for Omarchy 4.5 / Qt 6.12, where Qt also
  provides a `Color` type.
- Use Omarchy's `ShellIpc` to safely elect one IPC handler when the widget is
  shown on multiple monitors.
- Place new installations in the right bar section by default.

## [0.1.1] - 2026-10-25

### Fixed

- Removed unsupported QML return type annotations from the IPC handler so the
  plugin loads on Omarchy 4.0.6.

## [0.1.0] - 2026-08-22

### Added

- Initial Doom bar-widget plugin with WAD selection and windowed game launch.
- Resolution selection, floating window centering, and pause/hide controls.
