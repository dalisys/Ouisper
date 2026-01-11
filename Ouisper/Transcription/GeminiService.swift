import Foundation

class GeminiService: TranscriptionService {
    func transcribe(audioURL: URL, apiKey: String, language: String, model: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let audioData = try? Data(contentsOf: audioURL)
            let base64Audio = audioData?.base64EncodedString() ?? ""
            
            var promptText = "Transcribe the audio."
            if let hint = LanguagePreference.promptHint(language) {
                promptText += " \(hint)"
            }
            
            let jsonDict: [String: Any] = [
                "contents": [
                    [
                        "parts": [
                            ["text": promptText],
                            [
                                "inline_data": [
                                    "mime_type": "audio/wav",
                                    "data": base64Audio
                                ]
                            ]
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
                    if let text = decoded.candidates?.first?.content.parts.first?.text {
                        continuation.resume(returning: text)
                    } else {
                        continuation.resume(returning: "")
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
