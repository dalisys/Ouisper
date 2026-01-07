import Foundation

class MistralVoxtralService: TranscriptionService {
    func transcribe(audioURL: URL, apiKey: String, language: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.mistral.ai/v1/audio/transcriptions") else {
            throw TranscriptionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // Some Mistral endpoints accept x-api-key; keeping both helps compatibility.
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: audioURL)
        
        var body = Data()
        
        // File
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Language (optional)
        if !language.isEmpty && language != "auto" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body

        let session = URLSession(configuration: makeConfiguration())
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = extractErrorMessage(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown API Error"
            throw TranscriptionError.apiError(errorMsg)
        }
        
        let decoded = try JSONDecoder().decode(MistralTranscriptionResponse.self, from: data)
        return decoded.text
    }

    private func makeConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        // Disable HTTP/3 (QUIC) via KVC when supported to avoid UDP "Message too long" errors.
        if config.responds(to: Selector(("setSupportsHTTP3:"))) {
            config.setValue(false, forKey: "supportsHTTP3")
        }
        return config
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
