import SwiftUI
import UniformTypeIdentifiers

struct ModelManagerView: View {
    @Binding var modelPath: String
    @Binding var isLoaded: Bool

    @State private var showImporter: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            if isLoaded {
                loadedModelView
            } else {
                noModelView
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "bin")!],
            allowsMultipleSelection: false
        ) { result in
            handleModelSelection(result)
        }
    }

    private var loadedModelView: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)

            Text("Model Loaded")
                .font(.headline)

            Text(URL(fileURLWithPath: modelPath).lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    private var noModelView: some View {
        Button {
            showImporter = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.largeTitle)

                Text("Import TTS Model")
                    .font(.headline)

                Text("Tap to select a .bin model file")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private func handleModelSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let documents = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!

            let destination = documents.appendingPathComponent(url.lastPathComponent)

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: url, to: destination)
                modelPath = destination.path
            } catch {
                print("Error copying model: \(error)")
            }

        case .failure(let error):
            print("Error selecting model: \(error)")
        }
    }
}
