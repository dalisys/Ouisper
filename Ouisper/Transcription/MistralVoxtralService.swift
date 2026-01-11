import Foundation

class MistralVoxtralService: TranscriptionService {
    func transcribe(audioURL: URL, apiKey: String, language: String, model: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            
            print("Launching curl for Mistral Transcription...")
            
            // Force HTTP/1.1 to avoid UDP/QUIC "Message too long" errors on macOS
            var arguments = [
                "--http1.1",
                "--ipv4", // Force IPv4
                "-H", "Expect:", // Disable Expect: 100-continue
                "-s", // Silent mode
                "https://api.mistral.ai/v1/audio/transcriptions",
                "-H", "Authorization: Bearer \(apiKey)",
                "-F", "file=@\(audioURL.path)",
                "-F", "model=\(model)"
            ]
            
            let apiLanguage = LanguagePreference.apiLanguage(language)
            if !apiLanguage.isEmpty {
                arguments.append("-F")
                arguments.append("language=\(apiLanguage)")
            }
            
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus == 0 {
                    if let decoded = try? JSONDecoder().decode(MistralTranscriptionResponse.self, from: outputData) {
                        continuation.resume(returning: decoded.text)
                    } else {
                        // Try to parse error from output or stderr
                        let errorMsg = extractErrorMessage(from: outputData) ?? String(data: errorData, encoding: .utf8) ?? "Unknown curl error"
                        continuation.resume(throwing: TranscriptionError.apiError(errorMsg))
                    }
                } else {
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Curl failed with exit code \(process.terminationStatus)"
                    continuation.resume(throwing: TranscriptionError.apiError(errorMsg))
                }
            } catch {
                continuation.resume(throwing: TranscriptionError.apiError("Failed to launch curl: \(error.localizedDescription)"))
            }
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String {
                return message
            }
            if let type = error["type"] as? String {
                return type
            }
        }
        if let message = json["message"] as? String {
            return message
        }
        return nil
    }
}

struct MistralTranscriptionResponse: Codable {
    let text: String
}
