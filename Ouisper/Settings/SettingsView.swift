import SwiftUI
import AVFoundation
import ApplicationServices

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        ZStack {
            OuisperTheme.backgroundGradient
                .ignoresSafeArea()
            HStack(spacing: 18) {
                sidebar
                content
            }
            .padding(20)
        }
        .frame(minWidth: 860, minHeight: 620)
    }
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ouisper")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(OuisperTheme.mist)
            
            VStack(alignment: .leading, spacing: 10) {
                sidebarButton(title: "General", icon: "gearshape", tab: .general)
                sidebarButton(title: "Providers", icon: "network", tab: .providers)
            }
            .padding(12)
            .background(OuisperTheme.slate.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            Spacer()
            
            Text("System dictation control deck.")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(OuisperTheme.mist.opacity(0.6))
        }
        .frame(width: 200)
    }
    
    private func sidebarButton(title: String, icon: String, tab: SettingsTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(selectedTab == tab ? OuisperTheme.neon : OuisperTheme.mist.opacity(0.6))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(selectedTab == tab ? OuisperTheme.mist : OuisperTheme.mist.opacity(0.7))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedTab == tab ? OuisperTheme.ink.opacity(0.8) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .pointerOnHover()
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedTab == .general ? "General Settings" : "Provider Settings")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(OuisperTheme.mist)
            
            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView()
                    case .providers:
                        APISettingsView()
                    }
                }
                .padding(10)
            }
            .background(OuisperTheme.slate.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case providers
    var id: String { rawValue }
}

struct GeneralSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var dictationState = DictationState.shared
    @State private var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
    @State private var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var permissionMessage: String?
    @State private var selectedLanguages: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            permissionsSection
                .glassCard()
            injectionStatus
            
            Text("Core")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(OuisperTheme.mist)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activation Key")
                        .foregroundStyle(OuisperTheme.mist.opacity(0.8))
                    Spacer()
                    Picker("", selection: $settings.hotkey) {
                        ForEach(HotkeyOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .pointerOnHover()
                    .frame(width: 160)
                }
                
                if settings.hotkey == .custom {
                    HStack {
                        Text("Custom Shortcut")
                            .foregroundStyle(OuisperTheme.mist.opacity(0.8))
                        Spacer()
                        ShortcutRecorderView()
                            .frame(width: 160)
                    }
                }
                
                // Debugging for Hotkeys
                if settings.hotkey == .insert {
                    HStack {
                        Text("Debug: Press your key. Last Code:")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(OuisperTheme.mist.opacity(0.5))
                        Text("\(HotkeyManager.shared.lastDetectedKeyCode)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(OuisperTheme.neon)
                    }
                }

                HStack {
                    Text("Audio Quality")
                        .foregroundStyle(OuisperTheme.mist.opacity(0.8))
                    Spacer()
                    Picker("", selection: $settings.audioQuality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .pointerOnHover()
                    .frame(width: 160)
                }

                Toggle("Play Sound Effects", isOn: $settings.soundFeedback)
                    .pointerOnHover()
                Toggle("Format Text (LLM)", isOn: $settings.useTextCorrection)
                    .pointerOnHover()
                Text("Disable to reduce latency; raw transcription is pasted instantly.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(OuisperTheme.mist.opacity(0.7))
            }
            .glassCard()

            Text("Transcription")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(OuisperTheme.mist)

            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(languageOptions, id: \.code) { lang in
                            Toggle(isOn: Binding(
                                get: { selectedLanguages.contains(lang.code) },
                                set: { isOn in
                                    if isOn {
                                        selectedLanguages.insert(lang.code)
                                    } else {
                                        selectedLanguages.remove(lang.code)
                                    }
                                }
                            )) {
                                HStack {
                                    Text(lang.name)
                                        .font(.system(size: 13, weight: .medium, design: .default))
                                        .foregroundStyle(OuisperTheme.mist)
                                    Spacer()
                                    Text(lang.code.uppercased())
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(OuisperTheme.mist.opacity(0.5))
                                }
                                .padding(.vertical, 2)
                            }
                            .toggleStyle(.checkbox)
                            .pointerOnHover()
                        }
                    }
                    .padding(8)
                }
                .frame(height: 200) // Fixed height scrollable area
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Select multiple languages. Leave empty for auto-detection.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(OuisperTheme.mist.opacity(0.7))
            }
            .glassCard()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            refreshPermissions()
            if selectedLanguages.isEmpty {
                selectedLanguages = Set(LanguagePreference.parse(settings.language))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
        .onChange(of: selectedLanguages) { _, newValue in
            let joined = newValue.sorted().joined(separator: ", ")
            settings.language = joined.isEmpty ? "auto" : joined
        }
    }
    
    private var injectionStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Status")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(OuisperTheme.mist)
            if dictationState.lastInjectionError.isEmpty {
                Text("Ready.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(OuisperTheme.mist.opacity(0.7))
            } else {
                Text(dictationState.lastInjectionError)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(OuisperTheme.ember)
            }
        }
        .glassCard()
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(OuisperTheme.mist)
            
            HStack(alignment: .top, spacing: 12) {
                permissionCard(
                    title: "Microphone",
                    icon: "mic",
                    status: microphoneStatusText,
                    statusColor: microphoneStatusColor,
                    actionTitle: "Request Access",
                    action: requestMicrophoneAccess
                )
                .frame(maxWidth: .infinity)
                permissionCard(
                    title: "Accessibility",
                    icon: "hand.point.up.left",
                    status: isAccessibilityTrusted ? "Granted" : "Not Granted",
                    statusColor: isAccessibilityTrusted ? .green : .red,
                    actionTitle: "Request Access",
                    action: requestAccessibilityAccess
                )
                .frame(maxWidth: .infinity)
            }
            
            if let permissionMessage {
                Text(permissionMessage)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(OuisperTheme.mist.opacity(0.7))
            }
        }
    }

    struct LanguageOption: Hashable {
        let code: String
        let name: String
    }

    private let languageOptions: [LanguageOption] = [
        .init(code: "en", name: "English"),
        .init(code: "de", name: "German"),
        .init(code: "fr", name: "French"),
        .init(code: "es", name: "Spanish"),
        .init(code: "it", name: "Italian"),
        .init(code: "pt", name: "Portuguese"),
        .init(code: "nl", name: "Dutch"),
        .init(code: "sv", name: "Swedish"),
        .init(code: "no", name: "Norwegian"),
        .init(code: "da", name: "Danish"),
        .init(code: "fi", name: "Finnish"),
        .init(code: "pl", name: "Polish"),
        .init(code: "cs", name: "Czech"),
        .init(code: "tr", name: "Turkish"),
        .init(code: "ru", name: "Russian"),
        .init(code: "uk", name: "Ukrainian"),
        .init(code: "ar", name: "Arabic"),
        .init(code: "he", name: "Hebrew"),
        .init(code: "hi", name: "Hindi"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "zh", name: "Chinese")
    ].sorted { $0.name < $1.name }

    private func permissionCard(title: String, icon: String, status: String, statusColor: Color, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(OuisperTheme.neon)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(OuisperTheme.mist)
            }
            Text(status)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(statusColor)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(OuisperTheme.neon)
                .pointerOnHover()
        }
        .glassCard()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var microphoneStatusText: String {
        switch microphoneStatus {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    private var microphoneStatusColor: Color {
        switch microphoneStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }

    private func refreshPermissions() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    private func requestMicrophoneAccess() {
        permissionMessage = nil
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                if !granted {
                    permissionMessage = "Microphone access denied. Enable it in System Settings > Privacy & Security > Microphone."
                }
            }
        }
    }

    private func requestAccessibilityAccess() {
        permissionMessage = nil
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAccessibilityTrusted = AXIsProcessTrusted()
            if !isAccessibilityTrusted {
                permissionMessage = "Accessibility access not granted. Enable it in System Settings > Privacy & Security > Accessibility."
            }
        }
    }
}

struct APISettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var openAIKeyInput: String = ""
    @State private var geminiKeyInput: String = ""
    @State private var mistralKeyInput: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Provider")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(OuisperTheme.mist)

            VStack(alignment: .leading, spacing: 8) {
                Text("Provider")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(OuisperTheme.mist.opacity(0.7))
                Picker("", selection: $settings.provider) {
                    ForEach(TranscriptionProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .pointerOnHover()
                .frame(maxWidth: 240, alignment: .leading)
            }
            .glassCard()

            Text("Credentials & Models")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(OuisperTheme.mist)

            VStack(alignment: .leading, spacing: 10) {
                if settings.provider == .whisper {
                    SecureField("OpenAI API Key", text: $openAIKeyInput)
                        .onChange(of: openAIKeyInput) { _, newValue in
                            settings.saveOpenAIKey(newValue)
                        }
                        .onAppear {
                            openAIKeyInput = settings.openAIKey
                        }
                    Text("Stored: " + (settings.openAIKey.isEmpty ? "No" : "Yes"))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(OuisperTheme.mist.opacity(0.7))
                    TextField("Transcription Model (STT)", text: $settings.openAISTTModel)
                    TextField("Correction Model (LLM)", text: $settings.openAILLMModel)
                } else if settings.provider == .gemini {
                    SecureField("Google Gemini API Key", text: $geminiKeyInput)
                        .onChange(of: geminiKeyInput) { _, newValue in
                            settings.saveGeminiKey(newValue)
                        }
                        .onAppear {
                            geminiKeyInput = settings.geminiKey
                        }
                    Text("Stored: " + (settings.geminiKey.isEmpty ? "No" : "Yes"))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(OuisperTheme.mist.opacity(0.7))
                    TextField("Transcription Model (STT)", text: $settings.geminiSTTModel)
                    TextField("Correction Model (LLM)", text: $settings.geminiLLMModel)
                } else {
                    SecureField("Mistral API Key", text: $mistralKeyInput)
                        .onChange(of: mistralKeyInput) { _, newValue in
                            settings.saveMistralKey(newValue)
                        }
                        .onAppear {
                            mistralKeyInput = settings.mistralKey
                        }
                    Text("Stored: " + (settings.mistralKey.isEmpty ? "No" : "Yes"))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(OuisperTheme.mist.opacity(0.7))
                    TextField("Transcription Model (STT)", text: $settings.mistralSTTModel)
                    TextField("Correction Model (LLM)", text: $settings.mistralLLMModel)
                    Text("If you see “Message too long”, it’s a network/transport issue. Try a VPN or switch provider.")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(OuisperTheme.mist.opacity(0.7))
                }
            }
            .glassCard()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct ShortcutRecorderView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var isRecording = false
    @State private var monitor: Any?
    
    var body: some View {
        Button(action: toggleRecording) {
            HStack {
                if isRecording {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 8))
                        .opacity(Double(Int(Date().timeIntervalSince1970 * 2) % 2 == 0 ? 1 : 0)) // blink
                    Text("Press Keys...")
                        .foregroundStyle(OuisperTheme.mist)
                } else {
                    if settings.customHotkeyKeyCode != -1 {
                        Text(keyString)
                            .foregroundStyle(OuisperTheme.neon)
                    } else {
                        Text("Click to Record")
                            .foregroundStyle(OuisperTheme.mist.opacity(0.7))
                    }
                }
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecording ? OuisperTheme.neon : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var keyString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: UInt(bitPattern: settings.customHotkeyModifiers))
        if flags.contains(.command) { parts.append("Cmd") }
        if flags.contains(.option) { parts.append("Opt") }
        if flags.contains(.control) { parts.append("Ctrl") }
        if flags.contains(.shift) { parts.append("Shift") }
        
        // Convert keycode to string (basic mapping)
        let key = keyCodeToString(UInt16(settings.customHotkeyKeyCode))
        parts.append(key)
        
        return parts.joined(separator: " + ")
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        // Monitor for local events
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            saveShortcut(event)
            return nil // Consume event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    private func saveShortcut(_ event: NSEvent) {
        settings.customHotkeyKeyCode = Int(event.keyCode)
        settings.customHotkeyModifiers = Int(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
        stopRecording()
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        // Simple mapping for common keys
        switch keyCode {
        case 114: return "Insert"
        case 36: return "Enter"
        case 49: return "Space"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        // TODO: Use a proper CGKeyCode mapping for full coverage
        default: return String(format: "Key %d", keyCode)
        }
    }
}
