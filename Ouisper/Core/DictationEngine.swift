import Foundation
import Combine
import SwiftUI
import AppKit

class DictationEngine: ObservableObject {
    static let shared = DictationEngine()
    
    private let audioRecorder = AudioRecorder()
    private let settings = SettingsManager.shared
    private var targetApp: NSRunningApplication?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupHotkeys()
    }
    
    private func setupHotkeys() {
        HotkeyManager.shared.onKeyDown
            .sink { [weak self] in
                self?.startDictation()
            }
            .store(in: &cancellables)
        
        HotkeyManager.shared.onKeyUp
            .sink { [weak self] in
                self?.stopDictation()
            }
            .store(in: &cancellables)
    }
    
    func startDictation() {
        guard DictationState.shared.status.isReady else { return }
        
        targetApp = NSWorkspace.shared.frontmostApplication
        DictationState.shared.status = .recording
        DictationState.shared.errorMessage = nil
        
        do {
            try audioRecorder.startRecording()
        } catch {
            DictationState.shared.status = .error("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopDictation() {
        guard DictationState.shared.status == .recording else { return }
        
        guard let url = audioRecorder.stopRecording() else {
            DictationState.shared.status = .error("No recording URL")
            DictationState.shared.lastError = "No recording URL"
            return
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        DictationState.shared.lastRecordingPath = url.path
        DictationState.shared.lastRecordingBytes = fileSize
        if fileSize == 0 {
            DictationState.shared.status = .error("Recording is empty (0 bytes)")
            DictationState.shared.lastError = "Recording is empty (0 bytes)"
            return
        }
        
        DictationState.shared.status = .processing
        
        Task {
            await processAudio(url: url)
        }
    }
    
    private func processAudio(url: URL) async {
        let provider = settings.provider
        guard let apiKey = settings.getApiKey(for: provider), !apiKey.isEmpty else {
            DispatchQueue.main.async {
                DictationState.shared.status = .error("API Key missing for \(provider.rawValue)")
            }
            return
        }
        
        let service: TranscriptionService
        let corrector: TextCorrectionService
        
        // Model names
        let sttModel: String
        let llmModel: String
        
        switch provider {
        case .whisper:
            service = OpenAIWhisperService()
            corrector = OpenAITextCorrectionService()
            sttModel = settings.openAISTTModel
            llmModel = settings.openAILLMModel
        case .gemini:
            service = GeminiService()
            corrector = GeminiTextCorrectionService()
            sttModel = settings.geminiSTTModel
            llmModel = settings.geminiLLMModel
        case .voxtral:
            service = MistralVoxtralService()
            corrector = MistralTextCorrectionService()
            sttModel = settings.mistralSTTModel
            llmModel = settings.mistralLLMModel
        }
        
        do {
            let language = settings.language
            let rawText = try await service.transcribe(audioURL: url, apiKey: apiKey, language: language, model: sttModel)
            DispatchQueue.main.async {
                DictationState.shared.lastRawText = rawText
                DictationState.shared.lastError = ""
            }
            
            if rawText.isEmpty {
                 DispatchQueue.main.async {
                     DictationState.shared.status = .error("No text transcribed")
                     DictationState.shared.lastError = "No text transcribed"
                 }
                 return
            }
            
            let finalText: String
            if settings.useTextCorrection {
                // Step 2: LLM Correction
                DispatchQueue.main.async {
                    DictationState.shared.status = .refining
                }
                
                let correctedText = try await corrector.correct(text: rawText, apiKey: apiKey, model: llmModel)
                DispatchQueue.main.async {
                    DictationState.shared.lastCorrectedText = correctedText
                }
                
                finalText = correctedText.isEmpty ? rawText : correctedText
            } else {
                finalText = rawText
                DispatchQueue.main.async {
                    DictationState.shared.lastCorrectedText = ""
                }
            }
            
            DispatchQueue.main.async {
                self.targetApp?.activate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if VSCodeTerminalInjector.isVSCodeFamily(self.targetApp),
                       let app = self.targetApp,
                       TextInjector.injectVsCodeTerminal(finalText, app: app) {
                        // already injected via VS Code terminal command
                    } else if BrowserPasteInjector.isBrowser(self.targetApp),
                              let app = self.targetApp,
                              TextInjector.injectBrowser(finalText, app: app) {
                        // pasted via browser menu
                    } else if self.isTerminalApp(self.targetApp) {
                        TextInjector.injectTerminal(finalText)
                    } else {
                        TextInjector.inject(finalText)
                    }
                    DictationState.shared.lastInjectedText = finalText
                    DictationState.shared.status = .success
                }
                
                // Reset to idle after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if case .success = DictationState.shared.status {
                        DictationState.shared.status = .idle
                    }
                }
            }
            
        } catch {
            DispatchQueue.main.async {
                let errorText = "Error: \(error.localizedDescription)"
                self.targetApp?.activate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if VSCodeTerminalInjector.isVSCodeFamily(self.targetApp),
                       let app = self.targetApp,
                       TextInjector.injectVsCodeTerminal(errorText, app: app) {
                        // already injected via VS Code terminal command
                    } else if BrowserPasteInjector.isBrowser(self.targetApp),
                              let app = self.targetApp,
                              TextInjector.injectBrowser(errorText, app: app) {
                        // pasted via browser menu
                    } else if self.isTerminalApp(self.targetApp) {
                        TextInjector.injectTerminal(errorText)
                    } else {
                        TextInjector.inject(errorText)
                    }
                }
                DictationState.shared.status = .error(error.localizedDescription)
                DictationState.shared.lastError = error.localizedDescription
            }
        }
        
        // Cleanup file
        try? FileManager.default.removeItem(at: url)
    }

    private func isTerminalApp(_ app: NSRunningApplication?) -> Bool {
        guard let bundleId = app?.bundleIdentifier else { return false }
        let terminalBundleIds: Set<String> = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "net.kovidgoyal.kitty",
            "co.zeit.hyper",
            "org.alacritty",
            "io.wez.wezterm"
        ]
        return terminalBundleIds.contains(bundleId)
    }
}
