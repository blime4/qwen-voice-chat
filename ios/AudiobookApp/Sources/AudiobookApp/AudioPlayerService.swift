import Foundation
import AVFoundation
import Combine
import QuartzCore

@MainActor
final class AudioPlayerService: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentProgress: Double = 0.0

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    func playPCM(_ pcmData: Data, sampleRate: Int32 = 24000) throws {
        stop()

        let wavData = createWavHeader(
            pcmData: pcmData,
            sampleRate: sampleRate,
            channels: 1,
            bitsPerSample: 16
        )

#if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
#endif

        audioPlayer = try AVAudioPlayer(data: wavData)
        audioPlayer?.delegate = AudioPlayerDelegate.shared
        audioPlayer?.prepareToPlay()

        AudioPlayerDelegate.shared.onFinish = { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
                self?.currentProgress = 1.0
            }
        }

        audioPlayer?.play()
        isPlaying = true
        currentProgress = 0.0
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentProgress = 0.0
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }

    private func createWavHeader(
        pcmData: Data,
        sampleRate: Int32,
        channels: Int16,
        bitsPerSample: Int16
    ) -> Data {
        let dataSize = Int32(pcmData.count)
        let byteRate = sampleRate * Int32(channels) * Int32(bitsPerSample) / 8
        let blockAlign = Int16(channels * bitsPerSample / 8)

        var header = Data()
        header.reserveCapacity(44)

        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: (36 + dataSize).littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)

        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        return header + pcmData
    }
}

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
