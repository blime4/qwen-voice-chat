import Foundation
import AVFoundation

@MainActor
final class ChatLLMService: ObservableObject {
    @Published var isLoaded: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func loadModel(path: String) async throws {
        await MainActor.run { isLoading = true }
        
        // Stub: just mark as loaded
        await MainActor.run {
            isLoading = false
            isLoaded = true
        }
    }

    func generateSpeech(text: String) throws -> Data {
        // Stub: generate 1 second of sine wave
        let sampleRate: Int32 = 24000
        let samples = Int(sampleRate)
        
        var pcmData = Data(capacity: samples * 2)
        for i in 0..<samples {
            let sample = Float(0.1 * sin(2.0 * Double.pi * 440.0 * Double(i) / Double(sampleRate)))
            let intSample = Int16(sample * 32767.0)
            pcmData.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }
        
        return pcmData
    }

    func unload() {
        isLoaded = false
    }

    deinit {
    }
}

enum ChatLLMError: LocalizedError {
    case notLoaded
    case generationFailed
    case noAudioGenerated
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .notLoaded: return "Model not loaded"
        case .generationFailed: return "Speech generation failed"
        case .noAudioGenerated: return "No audio was generated"
        case .modelNotFound: return "Model file not found"
        }
    }
}
