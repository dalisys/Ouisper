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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(languageOptions, id: \.self) { code in
                        Toggle(code.uppercased(), isOn: Binding(
                            get: { selectedLanguages.contains(code) },
                            set: { isOn in
                                if isOn {
                                    selectedLanguages.insert(code)
                                } else {
                                    selectedLanguages.remove(code)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .pointerOnHover()
                    }
                }
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
        .onChange(of: selectedLanguages) { _ in
            let joined = selectedLanguages.sorted().joined(separator: ", ")
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

    private let languageOptions: [String] = [
        "en", "de", "fr", "es", "it", "pt", "nl", "sv", "no", "da", "fi",
        "pl", "cs", "tr", "ru", "uk", "ar", "he", "hi", "ja", "ko", "zh"
    ]

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
