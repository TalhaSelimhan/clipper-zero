# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clipper Zero is a macOS clipboard history manager with snippet support. Menu bar app built with SwiftUI + SwiftData, targeting macOS 14.0+, Swift 5.

## Architecture

- **Two SwiftData ModelContainers**: Local (ClipItem, ClipCollection, ExcludedApp) and Cloud (SnippetItem with CloudKit sync via iCloud container `iCloud.com.tselim.clipper-zero`)
- **SnippetMigrationService** runs before ModelContainer creation to avoid SQLite conflicts — do not reorder initialization
- **ClipboardMonitor** polls NSPasteboard every 0.5s; deduplicates by matching plaintext and updating `createdAt` instead of creating new entries
- **GlobalHotkeyManager** uses Carbon event taps (not SwiftUI keyboard shortcuts) — requires Accessibility permission
- **PanelController** manages the floating clipboard panel as an NSPanel (AppKit), not a SwiftUI window
- **Sparkle** handles auto-updates with EdDSA-signed appcast hosted on GitHub Pages (`docs/appcast.xml`)

## Build

Use XcodeBuildMCP tools to build, run, and test — not raw xcodebuild commands. The project is `clipper-zero.xcodeproj` with a single scheme.

## Required Entitlements

- Accessibility (global hotkeys + paste injection)
- CloudKit (snippet sync)
- Network client (Sparkle update checks)
- APS environment (push notifications for CloudKit)

## Git Conventions

- Feature branches off `main` (e.g., `feature/xyz`, `fix/abc`)
- Tag `vX.Y` on main to trigger release CI (GitHub Actions builds, notarizes, creates DMG, updates appcast)
- Current version: 2.0.0

## Release Pipeline

The GitHub Actions workflow (`.github/workflows/release.yml`) handles code signing, notarization, DMG creation, Sparkle signing, and GitHub Release — triggered by `v*` tags. Requires repository secrets for Developer ID cert, provisioning profile, Apple ID credentials, and Sparkle EdDSA key.
