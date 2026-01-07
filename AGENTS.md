# Repository Guidelines

## Project Structure & Module Organization
- `Ouisper/` contains the Swift source. Key folders map to features: `Core/`, `Audio/`, `Transcription/`, `Accessibility/`, `Settings/`, `UI/`, `Models/`, and `Extensions/`.
- Assets and app metadata live in `Ouisper/Assets.xcassets`, `Ouisper/Info.plist`, and `Ouisper/Ouisper.entitlements`.
- The app entry points are `Ouisper/OuisperApp.swift` and `Ouisper/AppDelegate.swift`.
- `Ouisper.xcodeproj` is the Xcode project file.

## Build, Test, and Development Commands
- Open in Xcode: `open Ouisper.xcodeproj`.
- Build in Xcode: `Cmd + B`.
- Run in Xcode: `Cmd + R`.
- CLI build (optional): `xcodebuild -project Ouisper.xcodeproj -scheme Ouisper build`.

## Coding Style & Naming Conventions
- Swift 5.9+ using SwiftUI and AppKit where needed.
- Indentation: 4 spaces; prefer Xcode’s default formatting.
- Naming: `UpperCamelCase` for types/files, `lowerCamelCase` for properties and functions.
- Organize files by feature area (e.g., `Audio/AudioRecorder.swift`).

## Testing Guidelines
- No automated test target is present yet. If you add tests, prefer XCTest and mirror module folders (e.g., `OuisperTests/Audio/AudioRecorderTests.swift`).
- Manual testing should include microphone permission flow, Accessibility text injection, and hotkey behavior across apps.

## Commit & Pull Request Guidelines
- No commit convention is established (this repo is not currently a Git repo). If you initialize Git, use short, imperative commit messages (e.g., “Add menubar state model”).
- PRs should describe the feature, mention permissions impacted (Microphone/Accessibility), and include screenshots or short recordings for UI changes.

## Security & Configuration Tips
- Store API keys in Keychain, not UserDefaults.
- Ensure `Ouisper.entitlements` and `Info.plist` include microphone and automation usage descriptions before testing dictation features.
- Avoid persisting raw audio; clear buffers after transcription.
