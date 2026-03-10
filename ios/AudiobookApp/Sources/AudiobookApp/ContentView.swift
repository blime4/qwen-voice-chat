import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var ttsService = ChatLLMService()
    @StateObject private var player = AudioPlayerService()

    @State private var text: String = ""
    @State private var modelPath: String = ""
    @State private var showFilePicker: Bool = false
    @State private var isGenerating: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                modelStatusView

                textInputView

                controlButtons

                progressView

                Spacer()
            }
            .padding()
            .navigationTitle("Audiobook")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Load Model") {
                        showFilePicker = true
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            try? await ttsService.loadModel(path: url.path)
                        }
                    }
                case .failure(let error):
                    ttsService.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var modelStatusView: some View {
        HStack {
            Circle()
                .fill(ttsService.isLoaded ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            Text(ttsService.isLoaded ? "Model Loaded" : "No Model")
                .font(.caption)

            if ttsService.errorMessage != nil {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
            }
        }
    }

    private var textInputView: some View {
        VStack(alignment: .leading) {
            Text("Text to speak:")
                .font(.headline)

            TextEditor(text: $text)
                .border(Color.secondary.opacity(0.3), width: 1)
                .frame(height: 200)
                .disabled(!ttsService.isLoaded || isGenerating)

            Text("\(text.count) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 20) {
            Button {
                generateAndPlay()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .disabled(text.isEmpty || !ttsService.isLoaded || isGenerating)

            Button {
                player.pause()
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .disabled(!player.isPlaying)

            Button {
                player.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(!player.isPlaying && player.currentProgress == 0)
        }
        .buttonStyle(.bordered)
    }

    private var progressView: some View {
        VStack {
            ProgressView(value: player.currentProgress)
                .progressViewStyle(.linear)

            if isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Generating...")
                        .font(.caption)
                }
            }
        }
    }

    private func generateAndPlay() {
        guard ttsService.isLoaded else { return }

        isGenerating = true

        Task {
            defer { isGenerating = false }

            do {
                let pcmData = try ttsService.generateSpeech(text: text)
                try player.playPCM(pcmData, sampleRate: 24000)
            } catch {
                ttsService.errorMessage = error.localizedDescription
            }
        }
    }
}
