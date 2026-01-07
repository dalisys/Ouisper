import Foundation

enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case whisper = "OpenAI Whisper"
    case gemini = "Google Gemini"
    case voxtral = "Mistral Voxtral"
    
    var id: String { rawValue }
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var id: String { rawValue }
}
