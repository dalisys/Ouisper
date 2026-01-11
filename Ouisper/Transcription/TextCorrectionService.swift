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
        return try await withCheckedThrowingContinuation { continuation in
            let prompt = "Fix punctuation, grammar, and capitalization errors in the following text. Do not change the meaning. Return only the corrected text:\n\n\(text)"
            
            let jsonDict: [String: Any] = [
                "contents": [
                    [
                        "parts": [
                            ["text": prompt]
                        ]
                    ]
                ]
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                continuation.resume(throwing: TranscriptionError.apiError("Failed to encode JSON"))
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            
            process.arguments = [
                "--http1.1",
                "--ipv4",
                "-H", "Expect:",
                "-s",
                "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)",
                "-H", "Content-Type: application/json",
                "-d", jsonString
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus == 0 {
                    let decoded = try JSONDecoder().decode(GeminiResponse.self, from: outputData)
                    let resultText = decoded.candidates?.first?.content.parts.first?.text ?? text
                    continuation.resume(returning: resultText)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Curl failed"
                    continuation.resume(throwing: TranscriptionError.apiError(errorMsg))
                }
            } catch {
                continuation.resume(throwing: TranscriptionError.apiError("Failed to launch curl: \(error.localizedDescription)"))
            }
        }
    }
}

class MistralTextCorrectionService: TextCorrectionService {
    func correct(text: String, apiKey: String, model: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            
            let systemPrompt = "You are a helpful assistant that formats and corrects dictation text. Fix punctuation, grammar, and capitalization errors. Do not change the meaning. Return only the corrected text."
            
            let jsonDict: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": text]
                ],
                "temperature": 0.3
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                continuation.resume(throwing: TranscriptionError.apiError("Failed to encode JSON"))
                return
            }
            
            // Force HTTP/1.1
            process.arguments = [
                "--http1.1",
                "--ipv4",
                "-H", "Expect:",
                "-s",
                "https://api.mistral.ai/v1/chat/completions",
                "-H", "Authorization: Bearer \(apiKey)",
                "-H", "Content-Type: application/json",
                "-d", jsonString
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus == 0 {
                    if let content = extractMistralContent(from: outputData), !content.isEmpty {
                        continuation.resume(returning: content)
                    } else {
                        let errorMsg = String(data: outputData, encoding: .utf8) ?? "Unknown response"
                        continuation.resume(throwing: TranscriptionError.apiError(errorMsg))
                    }
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Curl failed"
                    continuation.resume(throwing: TranscriptionError.apiError(errorMsg))
                }
            } catch {
                continuation.resume(throwing: TranscriptionError.apiError("Failed to launch curl: \(error.localizedDescription)"))
            }
        }
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
