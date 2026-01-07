import Foundation
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("selectedProvider") var provider: TranscriptionProvider = .whisper
    @AppStorage("selectedLanguage") var language: String = "en" // Default to English, maybe "auto" later
    @AppStorage("audioQuality") var audioQuality: AudioQuality = .medium
    @AppStorage("soundFeedback") var soundFeedback: Bool = true
    @AppStorage("useTextCorrection") var useTextCorrection: Bool = false
    
    // Model Settings
    @AppStorage("openAISTTModel") var openAISTTModel: String = "whisper-1"
    @AppStorage("openAILLMModel") var openAILLMModel: String = "gpt-4o-mini"
    @AppStorage("geminiSTTModel") var geminiSTTModel: String = "gemini-1.5-flash"
    @AppStorage("geminiLLMModel") var geminiLLMModel: String = "gemini-1.5-flash"
    @AppStorage("mistralSTTModel") var mistralSTTModel: String = "voxtral-mini-latest"
    @AppStorage("mistralLLMModel") var mistralLLMModel: String = "mistral-small-latest"
    
    // API Keys are not stored in AppStorage for security
    @Published var openAIKey: String = ""
    @Published var geminiKey: String = ""
    @Published var mistralKey: String = ""
    
    private init() {
        // Load keys from Keychain on init
        self.openAIKey = KeychainManager.shared.load(key: "openai_api_key") ?? ""
        self.geminiKey = KeychainManager.shared.load(key: "gemini_api_key") ?? ""
        self.mistralKey = KeychainManager.shared.load(key: "mistral_api_key") ?? ""
    }
    
    func saveOpenAIKey(_ key: String) {
        if KeychainManager.shared.save(key: "openai_api_key", value: key) {
            self.openAIKey = key
        }
    }
    
    func saveGeminiKey(_ key: String) {
        if KeychainManager.shared.save(key: "gemini_api_key", value: key) {
            self.geminiKey = key
        }
    }

    func saveMistralKey(_ key: String) {
        if KeychainManager.shared.save(key: "mistral_api_key", value: key) {
            self.mistralKey = key
        }
    }
    
    func getApiKey(for provider: TranscriptionProvider) -> String? {
        switch provider {
        case .whisper:
            return openAIKey
        case .gemini:
            return geminiKey
        case .voxtral:
            return mistralKey
        }
    }
}
