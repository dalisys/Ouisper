import Foundation

protocol TextCorrectionService {
    func correct(text: String, apiKey: String, model: String) async throws -> String
}

class OpenAITextCorrectionService: TextCorrectionService {
    func correct(text: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw TranscriptionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = "You are a helpful assistant that formats and corrects dictation text. Fix punctuation, grammar, and capitalization errors. Do not change the meaning. Return only the corrected text."
        
        let json: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown API Error"
            throw TranscriptionError.apiError(errorMsg)
        }
        
        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? text
    }
}

class GeminiTextCorrectionService: TextCorrectionService {
    func correct(text: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw TranscriptionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = "Fix punctuation, grammar, and capitalization errors in the following text. Do not change the meaning. Return only the corrected text:\n\n\(text)"
        
        let json: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown API Error"
            throw TranscriptionError.apiError(errorMsg)
        }
        
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return decoded.candidates?.first?.content.parts.first?.text ?? text
    }
}

class MistralTextCorrectionService: TextCorrectionService {
    func correct(text: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.mistral.ai/v1/chat/completions") else {
            throw TranscriptionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = "You are a helpful assistant that formats and corrects dictation text. Fix punctuation, grammar, and capitalization errors. Do not change the meaning. Return only the corrected text."
        
        let json: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown API Error"
            throw TranscriptionError.apiError(errorMsg)
        }
        
        if let content = extractMistralContent(from: data), !content.isEmpty {
            return content
        }
        
        return text
    }
    
    private func extractMistralContent(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"]
        else {
            return nil
        }
        
        if let contentString = content as? String {
            return contentString
        }
        
        if let parts = content as? [[String: Any]] {
            let texts = parts.compactMap { $0["text"] as? String }
            return texts.joined()
        }
        
        return nil
    }
}

// Minimal OpenAI Response Model
struct OpenAIChatResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIMessage: Codable {
    let content: String
}
