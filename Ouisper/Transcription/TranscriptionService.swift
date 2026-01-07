import Foundation

protocol TranscriptionService {
    func transcribe(audioURL: URL, apiKey: String, language: String, model: String) async throws -> String
}

enum TranscriptionError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case noData
}

extension TranscriptionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return "API Error: \(message)"
        case .noData:
            return "No data returned"
        }
    }
}
