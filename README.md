# Ouisper

AI-powered, system-wide dictation for macOS. Trigger recording with a global hotkey and paste transcription into the active app.

## Features
- Menubar app with recording status overlay
- Global hotkey trigger (Fn/Globe)
- OpenAI Whisper, Google Gemini, and Mistral Voxtral transcription
- Optional text formatting via LLM
- Clipboard fallback for terminal/CLI apps

## Requirements
- macOS 15+
- Microphone permission
- Accessibility permission (for text injection)

## Standalone Usage (No Xcode required after build)
1. Build once in Xcode:
   - Open `Ouisper.xcodeproj`
   - `Cmd + B`
2. Locate the built app:
   - In Xcode, Products → right‑click `Ouisper.app` → “Show in Finder”
3. Move `Ouisper.app` to `/Applications` (recommended).
4. Run the app from Finder.
5. Grant permissions in **General** tab:
   - Microphone
   - Accessibility
6. Select provider and paste API key in **Providers** tab.
7. Press and release **Fn/Globe** to dictate.

## Debug Mode (Xcode)
1. Open `Ouisper.xcodeproj`
2. `Cmd + R` to run under debugger
3. Permissions and provider setup same as above

Notes:
- In Debug builds, API keys are stored in **UserDefaults** to avoid repeated Keychain prompts.
- In Release builds, API keys use **Keychain** for security.

## Provider Notes
### Mistral Voxtral
If you see **“Message too long”**, it is a network/transport issue.  
Try a **VPN** or switch providers (OpenAI/Gemini).

### Terminal/CLI apps
Some terminals block text injection. In these apps, Ouisper copies to the clipboard.  
Press **Cmd+V** to paste.

## License
MIT
