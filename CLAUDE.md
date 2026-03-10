# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS voice assistant project based on **chatllm.cpp**, designed to run LLM-based ASR (speech recognition), LLM (dialogue), and TTS (speech synthesis) locally on Apple Silicon devices.

**Development Strategy:** Three-phase approach:
1. Phase 1: Linux/Mac validation of ASR → LLM → TTS pipeline
2. Phase 2: iOS port for TTS-only audiobook feature
3. Phase 3: Full voice assistant with ASR + LLM + TTS

## Architecture

```
┌─────────────────────────────────────────────┐
│           iOS Application (Swift)           │
├─────────────────────────────────────────────┤
│  Swift-C++ Bridge Layer (C API wrapper)     │
├─────────────────────────────────────────────┤
│  chatllm.cpp Core (git submodule)           │
│  ├── Qwen3-ASR (speech recognition)         │
│  ├── Qwen3 LLM (dialogue generation)        │
│  └── Qwen3-TTS (speech synthesis)           │
├─────────────────────────────────────────────┤
│  ggml Backend (Metal GPU acceleration)      │
└─────────────────────────────────────────────┘
```

## Key Paths

| Path | Description |
|------|-------------|
| `chatllm.cpp/` | Submodule → `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp` |
| `models/` | Model files (qwen3-0.6b.bin, qwen3-asr-0.6b.bin, qwen3-tts-12hz-0.6b-base.bin) |
| `scripts/` | Test and utility scripts |
| `output/` | Generated audio files (PCM/WAV) |
| `docs/plans/` | Design documents and implementation plans |

## Running Commands

### Docker Environment (Required on Linux)

The project uses Docker (`tts-cpp:latest`) because chatllm.cpp requires GCC 11+ with C++20 support.

```bash
# Build chatllm.cpp inside Docker
docker run --rm -v /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp:/chatllm -w /chatllm tts-cpp:latest cmake -B build
docker run --rm -v /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp:/chatllm -w /chatllm tts-cpp:latest cmake --build build -j$(nproc)

# Run chatllm.cpp main binary
./scripts/run_in_docker.sh <args>
```

### Test Commands

```bash
# TTS test: text → audio
./scripts/run_chatllm.sh tts "你好，这是一个测试"

# LLM test: prompt → response
./scripts/run_chatllm.sh llm "你是谁"

# Full pipeline: input → LLM → TTS → audio
./scripts/run_chatllm.sh pipeline "你好"

# Interactive chat mode
./scripts/run_chatllm.sh chat
# Or use the simpler wrapper:
./scripts/voice_chat.sh
```

### Direct chatllm.cpp Commands (inside Docker)

```bash
# TTS: Generate speech from text
docker run --rm \
    -v /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp:/chatllm \
    -v $(pwd)/models:/models \
    -v $(pwd)/output:/output \
    -w /chatllm tts-cpp:latest \
    ./build/bin/main -m /models/qwen3-tts-12hz-0.6b-base.bin \
    -p "要合成的文本" --tts_export /output/output.pcm

# LLM: Generate response
docker run --rm \
    -v /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp:/chatllm \
    -v $(pwd)/models:/models \
    -w /chatllm tts-cpp:latest \
    ./build/bin/main -m /models/qwen3-0.6b.bin -l 300 -p "你的问题"

# Convert PCM to WAV
ffmpeg -y -f s16le -ar 24000 -ac 1 -i output/audio.pcm output/audio.wav
```

## Models

This project uses **chatllm.cpp** (https://github.com/foldl/chatllm.cpp), NOT llama.cpp. chatllm.cpp uses **GGML format** (`.bin` files), which is different from llama.cpp's GGUF format.

### Source Models (HuggingFace safetensors)
| Model | Architecture | Source Location | Purpose |
|-------|--------------|-----------------|---------|
| Qwen3-0.6B | `Qwen3ForCausalLM` | `/Volumes/Expansion/models/Qwen3-0.6B` | Dialogue generation |
| Qwen3-ASR-0.6B | `Qwen3ASRForConditionalGeneration` | `/Volumes/Expansion/models/Qwen3-ASR-0.6B` | Speech recognition |
| Qwen3-TTS-12Hz-0.6B-Base | `Qwen3TTSForConditionalGeneration` | `/Volumes/Expansion/models/Qwen3-TTS-12Hz-0.6B-Base` | Speech synthesis |

### Converting Models to GGML Format

**Prerequisite:** Clone chatllm.cpp to get the conversion tools:
```bash
git clone --recursive https://github.com/foldl/chatllm.cpp.git
cd chatllm.cpp
pip install -r requirements.txt
```

**Convert each model:**
```bash
# Qwen3 LLM
python convert.py -i /Volumes/Expansion/models/Qwen3-0.6B -t q8_0 -o /Volumes/Expansion/models/qwen3-0.6b.bin --name Qwen3

# Qwen3 ASR
python convert.py -i /Volumes/Expansion/models/Qwen3-ASR-0.6B -t q8_0 -o /Volumes/Expansion/models/qwen3-asr-0.6b.bin --name Qwen3-ASR

# Qwen3 TTS (no -a flag needed, auto-detected)
python convert.py -i /Volumes/Expansion/models/Qwen3-TTS-12Hz-0.6B-Base -t q8_0 -o /Volumes/Expansion/models/qwen3-tts-12hz-0.6b-base.bin --name "Qwen3-TTS"
```

**Important notes:**
- chatllm.cpp generates `.bin` files (GGML format), NOT `.gguf` files
- The `-t q8_0` flag quantizes to 8-bit (recommended for local deployment)
- Use `--help` to see all quantization options (q4_k_m, q8_0, f16, etc.)

## Important Notes

### Qwen3 Thinking Mode
Qwen3 models generate thinking content before the actual response. The scripts extract content after `</think/>` marker:
```bash
response=$(echo "${full_output}" | sed -n 's/.*<\/think\/>//p' | head -1)
```

### TTS Character Limit
TTS has a ~200 character limit. Long responses are truncated:
```bash
MAX_CHARS=200
if [ ${#text} -gt ${MAX_CHARS} ]; then
    text="${text:0:${MAX_CHARS}}..."
fi
```

### Known Issues
1. **ASR file path issue**: ASR model has trouble with Docker mount paths - needs Mac environment testing
2. **Memory cleanup warning**: TTS may show "free(): invalid pointer" but output is correct

## Design Documents

- `docs/plans/2026-03-06-ios-voice-assistant-design.md` - Full iOS app architecture
- `docs/plans/2026-03-06-phase1-linux-validation.md` - Phase 1 implementation plan
- `docs/plans/phase1_report.md` - Phase 1 test results and performance data
