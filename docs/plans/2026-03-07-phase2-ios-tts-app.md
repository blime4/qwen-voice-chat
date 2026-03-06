# Phase 2: iOS TTS Audiobook App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native iOS app that uses chatllm.cpp to convert text to speech locally on Apple Silicon devices.

**Architecture:** Swift + SwiftUI for UI, C++ for chatllm.cpp core, C API bridge layer for Swift-C++ interop. TTS model runs locally with Metal GPU acceleration.

**Tech Stack:** Swift 5.9, SwiftUI, AVFoundation, chatllm.cpp (C++), Metal, C interop

---

## Prerequisites

- **Mac with Apple Silicon** (M1/M2/M3) for Metal acceleration
- **Xcode 15+** with iOS 17 SDK
- **TTS Model** downloaded: `qwen3-tts-12hz-0.6b-base.bin` (~1.2GB)
- **Phase 1 Complete**: TTS verified working on Linux/Docker

---

## Task 1: Create Xcode Project Structure

**Files:**
- Create: `ios/AudiobookApp/AudiobookApp.xcodeproj`
- Create: `ios/AudiobookApp/AudiobookApp/AudiobookAppApp.swift`
- Create: `ios/AudiobookApp/AudiobookApp/ContentView.swift`

**Step 1: Create project directory**

```bash
mkdir -p ios/AudiobookApp/AudiobookApp
cd ios/AudiobookApp
```

**Step 2: Create Xcode project using command line**

```bash
# Create Swift Package with SwiftUI
mkdir -p AudiobookApp
cd AudiobookApp

# Create Package.swift for local development first
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudiobookApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AudiobookApp", targets: ["AudiobookApp"]),
    ],
    targets: [
        .target(name: "AudiobookApp", dependencies: ["ChatLLMBridge"]),
        .target(name: "ChatLLMBridge", dependencies: []),
    ]
)
EOF
```

**Step 3: Create app entry point**

```bash
mkdir -p Sources/AudiobookApp
cat > Sources/AudiobookApp/AudiobookAppApp.swift << 'EOF'
import SwiftUI

@main
struct AudiobookAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF
```

**Step 4: Create main view**

```bash
cat > Sources/AudiobookApp/ContentView.swift << 'EOF'
import SwiftUI

struct ContentView: View {
    @State private var text: String = ""
    @State private var isPlaying: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            TextEditor(text: $text)
                .border(Color.gray, width: 1)
                .frame(height: 200)
                .padding()

            HStack(spacing: 20) {
                Button("Play") {
                    isPlaying = true
                }
                .disabled(text.isEmpty || isPlaying)

                Button("Stop") {
                    isPlaying = false
                }
                .disabled(!isPlaying)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Audiobook")
    }
}

#Preview {
    ContentView()
}
EOF
```

**Step 5: Verify structure**

```bash
tree Sources/
```

**Expected:**
```
Sources/
└── AudiobookApp/
    ├── AudiobookAppApp.swift
    └── ContentView.swift
```

---

## Task 2: Add chatllm.cpp as Local Dependency

**Files:**
- Modify: `ios/AudiobookApp/Package.swift`

**Step 1: Update Package.swift with chatllm.cpp path**

```bash
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudiobookApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AudiobookApp", targets: ["AudiobookApp"]),
    ],
    dependencies: [
        // Local path to chatllm.cpp (relative from ios/AudiobookApp)
        // We'll create a wrapper package for it
    ],
    targets: [
        .target(
            name: "AudiobookApp",
            dependencies: ["ChatLLMBridge"]
        ),
        .target(
            name: "ChatLLMBridge",
            dependencies: [],
            path: "Sources/ChatLLMBridge",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("chatllm.cpp"),
                .headerSearchPath("chatllm.cpp/src"),
                .define("GGML_USE_METAL", to: "1"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
EOF
```

**Step 2: Create bridge directory structure**

```bash
mkdir -p Sources/ChatLLMBridge/include
mkdir -p Sources/ChatLLMBridge/src
```

**Step 3: Create symlink to chatllm.cpp**

```bash
# From ios/AudiobookApp/Sources/ChatLLMBridge
cd Sources/ChatLLMBridge
ln -s ../../../../chatllm.cpp chatllm.cpp
ls -la
```

**Expected:** Symlink to chatllm.cpp exists

---

## Task 3: Design C API Bridge Header

**Files:**
- Create: `ios/AudiobookApp/Sources/ChatLLMBridge/include/chatllm_bridge.h`

**Step 1: Create C API header**

```bash
cat > Sources/ChatLLMBridge/include/chatllm_bridge.h << 'EOF'
#ifndef CHATLLM_BRIDGE_H
#define CHATLLM_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle to chatllm context
typedef void* chatllm_context_t;

/// Error codes
typedef enum {
    CHATLLM_OK = 0,
    CHATLLM_ERROR_NULL_CONTEXT = -1,
    CHATLLM_ERROR_MODEL_LOAD = -2,
    CHATLLM_ERROR_TTS_GENERATE = -3,
    CHATLLM_ERROR_INVALID_TEXT = -4,
    CHATLLM_ERROR_MEMORY = -5,
} chatllm_error_t;

/// Create a new chatllm context with TTS model
/// @param model_path Path to the TTS model file (.bin)
/// @return Opaque context handle, or NULL on failure
chatllm_context_t chatllm_create(const char* model_path);

/// Free chatllm context and release resources
/// @param ctx Context to free
void chatllm_free(chatllm_context_t ctx);

/// Generate speech from text
/// @param ctx ChatLLM context
/// @param text UTF-8 text to convert to speech (max 200 chars recommended)
/// @param out_audio Output pointer to audio samples (caller must free with chatllm_free_audio)
/// @param out_samples Output number of audio samples
/// @param out_sample_rate Output sample rate (typically 24000)
/// @return CHATLLM_OK on success, error code otherwise
chatllm_error_t chatllm_tts_generate(
    chatllm_context_t ctx,
    const char* text,
    float** out_audio,
    int32_t* out_samples,
    int32_t* out_sample_rate
);

/// Free audio buffer returned by chatllm_tts_generate
/// @param audio Audio buffer to free
void chatllm_free_audio(float* audio);

/// Get last error message
/// @param ctx Context to query
/// @return Error message string (do not free, valid until next call)
const char* chatllm_get_error(chatllm_context_t ctx);

#ifdef __cplusplus
}
#endif

#endif // CHATLLM_BRIDGE_H
EOF
```

**Step 2: Verify header syntax**

```bash
clang -fsyntax-only Sources/ChatLLMBridge/include/chatllm_bridge.h
echo "Header syntax OK"
```

**Expected:** No errors

---

## Task 4: Implement C API Bridge (Stub First)

**Files:**
- Create: `ios/AudiobookApp/Sources/ChatLLMBridge/src/chatllm_bridge.cpp`

**Step 1: Create stub implementation**

```bash
cat > Sources/ChatLLMBridge/src/chatllm_bridge.cpp << 'EOF'
#include "chatllm_bridge.h"
#include <cstring>
#include <cstdlib>

// Stub implementation for initial testing
// Will be replaced with actual chatllm.cpp integration

struct chatllm_context {
    char error_msg[256];
    bool initialized;
};

chatllm_context_t chatllm_create(const char* model_path) {
    if (!model_path) return nullptr;

    auto* ctx = new chatllm_context();
    ctx->initialized = true;
    strcpy(ctx->error_msg, "");
    return ctx;
}

void chatllm_free(chatllm_context_t ctx) {
    if (ctx) {
        delete ctx;
    }
}

chatllm_error_t chatllm_tts_generate(
    chatllm_context_t ctx,
    const char* text,
    float** out_audio,
    int32_t* out_samples,
    int32_t* out_sample_rate
) {
    if (!ctx) return CHATLLM_ERROR_NULL_CONTEXT;
    if (!text || !out_audio || !out_samples || !out_sample_rate) {
        return CHATLLM_ERROR_INVALID_TEXT;
    }

    // Stub: generate 1 second of silence at 24kHz
    const int32_t sample_rate = 24000;
    const int32_t samples = sample_rate;  // 1 second

    float* audio = (float*)malloc(samples * sizeof(float));
    if (!audio) return CHATLLM_ERROR_MEMORY;

    // Generate simple sine wave for testing
    for (int32_t i = 0; i < samples; i++) {
        audio[i] = 0.1f * sinf(2.0f * 3.14159f * 440.0f * i / sample_rate);
    }

    *out_audio = audio;
    *out_samples = samples;
    *out_sample_rate = sample_rate;

    return CHATLLM_OK;
}

void chatllm_free_audio(float* audio) {
    if (audio) {
        free(audio);
    }
}

const char* chatllm_get_error(chatllm_context_t ctx) {
    if (!ctx) return "Null context";
    return ctx->error_msg;
}
EOF
```

**Step 2: Build and verify**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/ios/AudiobookApp
swift build 2>&1 | head -20
```

**Expected:** Build succeeds with stub implementation

---

## Task 5: Create Swift Wrapper

**Files:**
- Create: `ios/AudiobookApp/Sources/AudiobookApp/ChatLLMService.swift`

**Step 1: Create Swift service class**

```bash
cat > Sources/AudiobookApp/ChatLLMService.swift << 'EOF'
import Foundation
import AVFoundation

/// Service for text-to-speech using ChatLLM
@MainActor
final class ChatLLMService: ObservableObject {
    @Published var isLoaded: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var context: UnsafeMutableRawPointer?

    /// Load TTS model from file path
    func loadModel(path: String) async throws {
        await MainActor.run { isLoading = true }

        let success = path.withCString { pathPtr in
            context = chatllm_create(pathPtr)
            return context != nil
        }

        await MainActor.run {
            isLoading = false
            isLoaded = success
            if !success {
                errorMessage = "Failed to load model"
            }
        }
    }

    /// Generate speech from text
    /// - Parameter text: Text to convert (max ~200 chars for best results)
    /// - Returns: PCM audio data at 24kHz, mono, 16-bit
    func generateSpeech(text: String) throws -> Data {
        guard let ctx = context else {
            throw ChatLLMError.notLoaded
        }

        var audioPtr: UnsafeMutablePointer<Float>?
        var samples: Int32 = 0
        var sampleRate: Int32 = 0

        let result = text.withCString { textPtr in
            chatllm_tts_generate(
                ctx,
                textPtr,
                &audioPtr,
                &samples,
                &sampleRate
            )
        }

        guard result == CHATLLM_OK.rawValue else {
            throw ChatLLMError.generationFailed
        }

        guard let audio = audioPtr, samples > 0 else {
            throw ChatLLMError.noAudioGenerated
        }

        // Convert float samples to 16-bit PCM
        var pcmData = Data(capacity: Int(samples) * 2)
        for i in 0..<Int(samples) {
            let sample = audio[i]
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * 32767.0)
            pcmData.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }

        chatllm_free_audio(audio)

        return pcmData
    }

    /// Cleanup resources
    func unload() {
        if let ctx = context {
            chatllm_free(ctx)
            context = nil
        }
        isLoaded = false
    }

    deinit {
        unload()
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
EOF
```

**Step 2: Build to verify Swift compiles**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/ios/AudiobookApp
swift build 2>&1 | tail -10
```

**Expected:** Build succeeds

---

## Task 6: Create Audio Player Service

**Files:**
- Create: `ios/AudiobookApp/Sources/AudiobookApp/AudioPlayerService.swift`

**Step 1: Create audio player**

```bash
cat > Sources/AudiobookApp/AudioPlayerService.swift << 'EOF'
import Foundation
import AVFoundation
import Combine

/// Manages audio playback for generated speech
@MainActor
final class AudioPlayerService: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentProgress: Double = 0.0

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    /// Play PCM audio data
    /// - Parameters:
    ///   - pcmData: Raw PCM data (16-bit, mono)
    ///   - sampleRate: Sample rate (typically 24000)
    func playPCM(_ pcmData: Data, sampleRate: Int32 = 24000) throws {
        stop()

        // Create WAV header
        let wavData = createWavHeader(
            pcmData: pcmData,
            sampleRate: sampleRate,
            channels: 1,
            bitsPerSample: 16
        )

        // Configure audio session
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)

        // Create player
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

    /// Stop playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentProgress = 0.0
    }

    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    /// Resume playback
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }

    // MARK: - Private

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

        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: (36 + dataSize).littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) })  // chunk size
        header.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) })   // PCM format
        header.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        return header + pcmData
    }
}

// MARK: - Delegate

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
EOF
```

**Step 2: Build to verify**

```bash
swift build 2>&1 | tail -5
```

**Expected:** Build succeeds

---

## Task 7: Update ContentView with TTS Integration

**Files:**
- Modify: `ios/AudiobookApp/Sources/AudiobookApp/ContentView.swift`

**Step 1: Update ContentView**

```bash
cat > Sources/AudiobookApp/ContentView.swift << 'EOF'
import SwiftUI

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
                // Model status
                modelStatusView

                // Text input
                textInputView

                // Controls
                controlButtons

                // Progress
                progressView

                Spacer()
            }
            .padding()
            .navigationTitle("Audiobook")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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

    // MARK: - Subviews

    private var modelStatusView: some View {
        HStack {
            Circle()
                .fill(ttsService.isLoaded ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            Text(ttsService.isLoaded ? "Model Loaded" : "No Model")
                .font(.caption)

            if let error = ttsService.errorMessage {
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

    // MARK: - Actions

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

#Preview {
    ContentView()
}
EOF
```

**Step 2: Build**

```bash
swift build 2>&1 | tail -10
```

**Expected:** Build succeeds

---

## Task 8: Create Xcode Project File

**Files:**
- Create: `ios/AudiobookApp/AudiobookApp.xcodeproj/project.pbxproj`

**Step 1: Generate Xcode project**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/ios/AudiobookApp

# Generate Xcode project from Package.swift
swift package generate-xcodeproj 2>&1 || echo "Note: May need Xcode for full iOS project"
```

**Alternative: Create project manually in Xcode**

1. Open Xcode
2. File → New → Project
3. iOS → App
4. Name: "AudiobookApp"
5. Interface: SwiftUI
6. Language: Swift
7. Save to: `ios/`

---

## Task 9: Integrate Real chatllm.cpp TTS

**Files:**
- Modify: `ios/AudiobookApp/Sources/ChatLLMBridge/src/chatllm_bridge.cpp`

**Step 1: Update to use real chatllm.cpp**

This requires adapting chatllm.cpp's TTS interface. The key integration points:

```cpp
// Include chatllm.cpp headers
#include "src/chat.h"
#include "src/common.h"

// In chatllm_create:
// - Load TTS model using chatllm::create_context()
// - Configure for TTS mode

// In chatllm_tts_generate:
// - Call TTS generation
// - Extract audio samples
// - Return to Swift
```

**Note:** This step requires detailed analysis of chatllm.cpp's internal API.
See `chatllm.cpp/src/chat.h` for available interfaces.

---

## Task 10: Add Document Browser for Model Import

**Files:**
- Create: `ios/AudiobookApp/Sources/AudiobookApp/ModelManagerView.swift`

**Step 1: Create model manager**

```bash
cat > Sources/AudiobookApp/ModelManagerView.swift << 'EOF'
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

            // Copy to app documents directory
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

#Preview {
    ModelManagerView(modelPath: .constant(""), isLoaded: .constant(false))
}
EOF
```

---

## Task 11: Add Unit Tests

**Files:**
- Create: `ios/AudiobookApp/Tests/AudiobookAppTests/ChatLLMBridgeTests.swift`

**Step 1: Create test file**

```bash
mkdir -p Tests/AudiobookAppTests

cat > Tests/AudiobookAppTests/ChatLLMBridgeTests.swift << 'EOF'
import XCTest
@testable import AudiobookApp

final class ChatLLMBridgeTests: XCTestCase {

    // MARK: - C API Tests

    func testCreateAndFreeContext() {
        let ctx = chatllm_create("/dummy/path/model.bin")
        XCTAssertNotNil(ctx, "Context should be created")
        chatllm_free(ctx)
    }

    func testCreateWithNullPath() {
        let ctx = chatllm_create(nil)
        XCTAssertNil(ctx, "Context should be nil with null path")
    }

    func testTTSGenerateWithNullContext() {
        var audioPtr: UnsafeMutablePointer<Float>?
        var samples: Int32 = 0
        var sampleRate: Int32 = 0

        let result = chatllm_tts_generate(
            nil,
            "test",
            &audioPtr,
            &samples,
            &sampleRate
        )

        XCTAssertEqual(result, CHATLLM_ERROR_NULL_CONTEXT.rawValue)
    }

    // MARK: - Swift Service Tests

    func testServiceNotLoadedByDefault() {
        let service = ChatLLMService()
        XCTAssertFalse(service.isLoaded)
    }

    func testGenerateThrowsWhenNotLoaded() {
        let service = ChatLLMService()

        XCTAssertThrowsError(try service.generateSpeech(text: "test")) { error in
            XCTAssertTrue(error is ChatLLMError)
        }
    }
}
EOF
```

**Step 2: Update Package.swift with test target**

```bash
# Add to targets array in Package.swift:
        .testTarget(
            name: "AudiobookAppTests",
            dependencies: ["AudiobookApp"]
        ),
```

**Step 3: Run tests**

```bash
swift test 2>&1 | tail -20
```

**Expected:** Tests pass

---

## Task 12: Build for iOS Simulator

**Files:**
- Build configuration

**Step 1: Build for simulator**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/ios/AudiobookApp

# Build for iOS simulator (arm64)
swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "arm64-apple-ios17.0-simulator" 2>&1 | tail -20
```

**Step 2: Open in Xcode for full build**

```bash
open AudiobookApp.xcodeproj 2>/dev/null || open Package.swift
```

---

## Task 13: Create README for iOS Project

**Files:**
- Create: `ios/AudiobookApp/README.md`

**Step 1: Create README**

```bash
cat > README.md << 'EOF'
# AudiobookApp - iOS TTS Application

Native iOS text-to-speech app using chatllm.cpp for local inference.

## Requirements

- Xcode 15+
- iOS 17.0+
- Apple Silicon Mac (for Metal acceleration)
- TTS Model: `qwen3-tts-12hz-0.6b-base.bin` (~1.2GB)

## Setup

1. Open `AudiobookApp.xcodeproj` in Xcode
2. Build and run on simulator or device
3. Import TTS model via the app's file picker
4. Enter text and tap Play

## Project Structure

```
AudiobookApp/
├── Sources/
│   ├── AudiobookApp/          # Swift app code
│   │   ├── AudiobookAppApp.swift
│   │   ├── ContentView.swift
│   │   ├── ChatLLMService.swift
│   │   ├── AudioPlayerService.swift
│   │   └── ModelManagerView.swift
│   └── ChatLLMBridge/         # C++ bridge
│       ├── include/chatllm_bridge.h
│       ├── src/chatllm_bridge.cpp
│       └── chatllm.cpp -> (symlink)
└── Tests/
    └── AudiobookAppTests/
```

## Architecture

```
SwiftUI Views
     │
     ▼
ChatLLMService (Swift)
     │
     ▼
chatllm_bridge.h (C API)
     │
     ▼
chatllm.cpp (C++)
     │
     ▼
ggml + Metal
```

## Testing

```bash
swift test
```

## Known Issues

- ASR requires Mac environment (file path issues in Docker)
- TTS character limit: ~200 chars for best quality
- First generation may be slower due to model warm-up
EOF
```

---

## Task 14: Update Phase 1 Report with Phase 2 Status

**Files:**
- Modify: `docs/plans/phase1_report.md`

**Step 1: Append Phase 2 status**

```bash
cat >> /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/docs/plans/phase1_report.md << 'EOF'

---

## Phase 2 Status (2026-03-07)

### Completed Tasks
- [x] Xcode project structure created
- [x] C API bridge header designed
- [x] Stub C API implementation
- [x] Swift wrapper (ChatLLMService)
- [x] Audio player service
- [x] SwiftUI ContentView
- [x] Model import UI
- [x] Unit tests

### Pending Tasks
- [ ] Integrate real chatllm.cpp TTS (requires chatllm.cpp API analysis)
- [ ] Build on physical iOS device
- [ ] Test with actual TTS model
- [ ] Performance optimization

### iOS Project Location
`ios/AudiobookApp/`

EOF
```

---

## Acceptance Criteria

- [ ] Xcode project builds without errors
- [ ] C API bridge compiles with C++20
- [ ] Swift wrapper connects to C API
- [ ] Audio player plays generated PCM data
- [ ] UI allows text input and playback control
- [ ] Model import via file picker works
- [ ] Unit tests pass
- [ ] App runs on iOS simulator

---

## Estimated Time

| Task | Time |
|------|------|
| 1-2: Project setup | 20 min |
| 3-4: C API bridge | 30 min |
| 5-6: Swift services | 30 min |
| 7: UI integration | 20 min |
| 8-9: Xcode + chatllm | 40 min |
| 10-11: Model import + tests | 30 min |
| 12-14: Build + docs | 20 min |
| **Total** | **~3 hours** |

---

## Dependencies

- **Phase 1 Complete**: TTS model verified working
- **Mac with Xcode**: Required for iOS development
- **chatllm.cpp API**: Internal interfaces need analysis for integration
