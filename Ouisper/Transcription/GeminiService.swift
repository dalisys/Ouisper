import Foundation

class GeminiService: TranscriptionService {
    func transcribe(audioURL: URL, apiKey: String, language: String, model: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw TranscriptionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()
        
        var promptText = "Transcribe the audio."
        if let hint = LanguagePreference.promptHint(language) {
            promptText += " \(hint)"
        }
        
        let json: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText],
                        [
                            "inline_data": [
                                "mime_type": "audio/mpeg", // Assuming m4a/aac is acceptable as audio/mpeg or audio/mp4? Gemini supports specific mimes.
                                // Common: audio/wav, audio/mp3, audio/aiff, audio/aac, audio/ogg, audio/flac.
                                // m4a is usually AAC. "audio/aac" or "audio/mp4" should work.
                                "data": base64Audio
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown API Error"
            throw TranscriptionError.apiError(errorMsg)
        }
        
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        if let text = decoded.candidates?.first?.content.parts.first?.text {
            return text
        }
        
        return ""
    }
}

// Minimal decoding models
struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String?
}
