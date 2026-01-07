# Ouisper

## Project Overview

**Ouisper** is a native macOS menubar application designed to provide system-wide AI-powered dictation. It allows users to dictate text anywhere on their Mac using a global keyboard shortcut, utilizing OpenAI Whisper or Google Gemini APIs for transcription.

- **Current State:** Initial SwiftUI project boilerplate ("Hello World").
- **Goal:** Implement the full feature set defined in `Ouisper/projectDeatils.md`.

## Key Features (Roadmap)

- **Menubar App:** Persistent status indicator and menu.
- **Global Hotkey:** Trigger recording from anywhere (e.g., `Fn` key hold).
- **Audio Recording:** Real-time capture using `AVFoundation`.
- **Transcription:** Integration with OpenAI Whisper and Google Gemini APIs.
- **Text Injection:** Insert transcribed text into the active application via Accessibility APIs (`AXUIElement`).

## Tech Stack

- **Language:** Swift 5.9+
- **Frameworks:** SwiftUI (UI), AppKit (Menubar/System), AVFoundation (Audio), ApplicationServices (Accessibility).
- **Architecture:** Likely MVVM, with specific controllers for system features (MenuBar, Hotkey, Audio).

## Building and Running

1.  **Open Project:** Open `Ouisper.xcodeproj` in Xcode.
2.  **Build:** Press `Cmd + B`.
3.  **Run:** Press `Cmd + R`.

_Note: As the project evolves to include Menubar and Accessibility features, signing and permissions (Microphone, Accessibility) will be critical for running successfully._

## File Structure

- `Ouisper/OuisperApp.swift`: App entry point.
- `Ouisper/ContentView.swift`: Main view (currently placeholder).
- `Ouisper/projectDeatils.md`: Detailed functional and technical requirements.

## Development Conventions

- **UI:** Use SwiftUI for application windows and settings.
- **System Integration:** Use AppKit/Carbon/CoreGraphics for global hotkeys and menubar management.
- **Code Style:** Standard Swift style guide.
