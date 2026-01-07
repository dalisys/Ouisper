import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    
    @Published var isRecording: Bool = false
    @Published var audioLevel: Float = 0.0
    
    private var recordingURL: URL?
    
    override init() {
        super.init()
        // Do not setup engine here. Accessing inputNode triggers permission check or crash if not authorized.
    }
    
    private func setupEngine() {
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
            guard let engine = audioEngine else { return }
            // Force creation of the output node to avoid AVAudioEngineGraph init failures.
            let _ = engine.mainMixerNode
        }
    }
    
    func startRecording() throws {
        // Check permissions
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"])
        }
        
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] allowed in
                if allowed {
                    DispatchQueue.main.async {
                        try? self?.startRecording()
                    }
                }
            }
            return
        }
        
        // Setup engine now that we have permissions
        setupEngine()
        
        guard let engine = audioEngine else {
            throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio engine"])
        }
        
        // If engine is running, stop it to reset
        if engine.isRunning {
            engine.stop()
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording-\(UUID().uuidString).wav"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        if format.channelCount == 0 || format.sampleRate == 0 {
            throw NSError(domain: "AudioRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "No audio input device available"])
        }
        
        // Create audio file (PCM WAV)
        audioFile = try AVAudioFile(forWriting: recordingURL!, settings: format.settings)
        
        // Ensure the graph has a valid path by connecting input to mainMixer.
        engine.connect(inputNode, to: engine.mainMixerNode, format: format)
        // Mute monitoring so we don't hear ourselves.
        engine.mainMixerNode.outputVolume = 0
        
        // Install tap directly on input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
            guard let self = self else { return }
            
            // Calculate level for visual feedback
            let channelData = buffer.floatChannelData?[0]
            let channelDataValue = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            
            var sum: Float = 0
            for value in channelDataValue {
                sum += value * value
            }
            let average = sqrt(sum / Float(buffer.frameLength))
            
            DispatchQueue.main.async {
                self.audioLevel = average
            }
            
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("Error writing audio: \(error)")
            }
        }
        
        engine.prepare()
        try engine.start()
        isRecording = true
    }
    
    func stopRecording() -> URL? {
        guard let engine = audioEngine else { return nil }
        
        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil // Close file
        
        isRecording = false
        return recordingURL
    }
}
