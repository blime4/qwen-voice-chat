# AudiobookApp - iOS TTS Application

Native iOS text-to-speech app using chatllm.cpp for local inference.

## Requirements

- Xcode 15+
- iOS 17.0+ / macOS 14.0+
- Apple Silicon Mac (for Metal acceleration)
- TTS Model: `qwen3-tts-12hz-0.6b-base.bin` (~1.2GB)

## Setup

1. Open `Package.swift` in Xcode
2. Build and run on simulator or device
3. Import TTS model via the app's file picker
4. Enter text and tap Play

## Project Structure

```
AudiobookApp/
├── Package.swift
├── Sources/
│   ├── AudiobookApp/              # Swift app code
│   │   ├── AudiobookAppApp.swift  # App entry point
│   │   ├── ContentView.swift      # Main UI
│   │   ├── ChatLLMService.swift   # TTS service wrapper
│   │   ├── AudioPlayerService.swift # Audio playback
│   │   └── ModelManagerView.swift # Model import UI
│   └── ChatLLMBridge/             # C++ bridge
│       ├── include/chatllm_bridge.h
│       └── src/chatllm_bridge.cpp
└── Tests/
    └── AudiobookAppTests/
        └── SimpleTests.swift
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

## Building

### macOS (Command Line)
```bash
cd ios/AudiobookApp
swift build
```

### iOS Simulator (Requires Xcode)
```bash
swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "arm64-apple-ios17.0-simulator"
```

## Testing

```bash
swift test
```

## Model Conversion

Convert HuggingFace models to chatllm.cpp GGML format:

```bash
# Clone chatllm.cpp
git clone https://github.com/foldl/chatllm.cpp.git

# Convert TTS model
python convert.py -i /path/to/Qwen3-TTS-12Hz-0.6B-Base -t q8_0 -o qwen3-tts-12hz-0.6b-base.bin --name "Qwen3-TTS"
```

## Known Issues

- iOS simulator build requires full Xcode installation
- Real TTS integration requires CMake build of chatllm.cpp
- TTS character limit: ~200 chars for best quality
- First generation may be slower due to model warm-up

## License

MIT
