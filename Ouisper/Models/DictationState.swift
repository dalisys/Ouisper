import Foundation
import Combine

enum DictationStatus: Equatable {
    case idle
    case recording
    case processing
    case refining
    case success
    case error(String)
    
    var isReady: Bool {
        switch self {
        case .idle, .success, .error:
            return true
        default:
            return false
        }
    }
}

class DictationState: ObservableObject {
    @Published var status: DictationStatus = .idle
    @Published var errorMessage: String? = nil
    @Published var lastRawText: String = ""
    @Published var lastCorrectedText: String = ""
    @Published var lastInjectedText: String = ""
    @Published var lastError: String = ""
    @Published var lastRecordingPath: String = ""
    @Published var lastRecordingBytes: Int64 = 0
    @Published var lastInjectionError: String = ""
    
    static let shared = DictationState()
    private init() {}
}
