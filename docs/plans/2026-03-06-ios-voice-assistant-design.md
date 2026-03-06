# iOS 语音助手应用设计文档

> 基于 chatllm.cpp 的端侧语音模型应用

## 1. 项目概述

### 1.1 目标

开发一个 iOS 应用，利用 Apple Silicon 芯片在本地运行语音模型，支持：

1. **听书功能**：将文本转换为语音播放（TTS）
2. **语音对话**：语音输入 → 识别 → 对话 → 语音输出（ASR + LLM + TTS）

### 1.2 技术核心

- **基础库**：chatllm.cpp（基于 ggml）
- **语音模型**：Qwen3-ASR（语音识别）+ Qwen3-TTS（语音合成）
- **对话模型**：Qwen3 系列（0.6B/1.7B/4B 可选）
- **加速方案**：Metal（Apple Silicon GPU 加速）
- **架构**：原生 Swift + C++ 混合开发

### 1.3 开发策略

采用分层渐进式开发，降低风险：

- **Phase 1**：Mac 上验证 ASR + LLM + TTS 流程
- **Phase 2**：移植到 iOS，实现纯 TTS 听书功能
- **Phase 3**：增加 ASR 和 LLM，实现完整语音对话

---

## 2. 系统架构

### 2.1 整体架构图

```
┌────────────────────────────────────────────────��────────────┐
│                    iOS Application                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   UI Layer  │  │  Audio I/O  │  │   Text/File Input   │  │
│  │   (Swift)   │  │   (Swift)   │  │      (Swift)        │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         ▼                ▼                     ▼             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Swift-C++ Bridge Layer                     ││
│  │         (C API wrapper for chatllm.cpp)                 ││
│  └─────────────────────────────┬───────────────────────────┘│
├────────────────────────────────┼────────────────────────────┤
│                    chatllm.cpp Core                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │ Qwen-ASR │  │   LLM    │  │ Qwen-TTS │  │  Tokenizer │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────┬──────┘  │
│       └─────────────┴─────────────┴──────────────┘         │
│                           │                                 │
│  ┌────────────────────────▼─────────────────────────────┐  │
│  │                   ggml Backend                        │  │
│  │  ┌─────────┐  ┌──────────┐  ┌────────────────────┐   │  │
│  │  │  Metal  │  │   CPU    │  │   Memory Manager   │   │  │
│  │  └─────────┘  └──────────┘  └────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心组件说明

| 组件 | 语言 | 职责 |
|------|------|------|
| UI Layer | Swift/SwiftUI | 用户界面、交互逻辑 |
| Audio I/O | Swift | 麦克风录音、扬声器播放（AVFoundation）|
| Bridge Layer | C/C++ | 将 chatllm.cpp 封装为 C 接口 |
| chatllm.cpp Core | C++ | ASR、LLM、TTS 模型推理 |
| ggml Backend | C/Metal | 底层计算、Metal GPU 加速 |

---

## 3. Phase 1 - Mac 验证阶段

### 3.1 目标

在 macOS 上验证 ASR → LLM → TTS 的完整流程，确保模型推理正确。

### 3.2 环境准备

```bash
# 克隆 chatllm.cpp
git clone --recursive https://github.com/foldl/chatllm.cpp.git
cd chatllm.cpp

# 编译（启用 Metal）
cmake -B build -DGGML_METAL=1
cmake --build build -j
```

### 3.3 模型准备

需要三个量化模型：

| 模型 | 用途 | 推荐量化 | 预估大小 |
|------|------|---------|---------|
| Qwen3-ASR | 语音识别 | Q8_0 | ~200MB |
| Qwen3-0.6B/1.7B | 对话生成 | Q4_K_M | 400MB-1.2GB |
| Qwen3-TTS | 语音合成 | Q8_0 | ~500MB |

### 3.4 验证流程

```
┌─────────────────────────────────────────────────────────────┐
│                    Phase 1 验证流程                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [音频文件] ──► ASR ──► [文本]                              │
│                              │                              │
│                              ▼                              │
│  [音频输出] ◄── TTS ◄── [回复文本] ◄── LLM ◄── [用户输入]   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**验证步骤**：

1. **ASR 验证**：输入测试音频 → 输出识别文本
2. **LLM 验证**：输入文本 → 输出回复
3. **TTS 验证**：输入文本 → 输出音频文件
4. **完整流程**：麦克风录音 → ASR → LLM → TTS → 播放

### 3.5 交付物

- [ ] 可运行的命令行 Demo
- [ ] 模型加载和推理的基准性能数据
- [ ] 内存占用评估报告

---

## 4. Phase 2 - iOS 听书应用

### 4.1 目标

将 chatllm.cpp 移植到 iOS，实现纯 TTS 听书功能。

### 4.2 项目结构

```
AudiobookApp/
├── App/
│   ├── AudiobookAppApp.swift        # App 入口
│   ├── ContentView.swift            # 主界面
│   ├── PlayerView.swift             # 播放控制
│   └── SettingsView.swift           # 设置
├── Models/
│   ├── AudiobookPlayer.swift        # 播放器逻辑
│   └── TextProcessor.swift          # 文本处理
├── Bridge/
│   ├── chatllm_bridge.h             # C 接口头文件
│   ├── chatllm_bridge.cpp           # C 接口实现
│   └── ChatLLMWrapper.swift         # Swift 封装
├── chatllm.cpp/                      # chatllm.cpp 源码 (git submodule)
└── Models/                           # 模型文件 (用户导入)
```

### 4.3 TTS 核心流程

```
┌──────────────────────────────────────────────────────────┐
│                    TTS 播放流程                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  [文本输入]                                              │
│      │                                                   │
│      ▼                                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────────┐       │
│  │ 文本分段 │───►│ TTS 推理 │───►│ 音频缓冲队列 │       │
│  │ (分句)   │    │ (流式)   │    │              │       │
│  └──────────┘    └──────────┘    └──────┬───────┘       │
│                                          │               │
│                                          ▼               │
│                                   ┌──────────────┐       │
│                                   │ 音频播放     │       │
│                                   │(AVAudioPlayer)│      │
│                                   └──────────────┘       │
└──────────────────────────────────────────────────────────┘
```

### 4.4 关键技术点

| 功能 | 实现方案 |
|------|---------|
| 文本分段 | 按标点符号分句，每段 50-100 字符 |
| 流式 TTS | 边生成边播放，降低首字延迟 |
| 音频播放 | AVAudioPlayer + 缓冲队列 |
| 模型管理 | Files App 共享，用户手动导入 |

### 4.5 UI 设计

```
┌────────────────────────────────────────┐
│  ┌──────────────────────────────────┐  │
│  │     文本输入区域 / 导入文件      │  │
│  │                                  │  │
│  │  这是一段示例文本，用户可以...   │  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                                        │
│  ┌──────┐ ┌──────┐ ┌──────┐           │
│  │ 播放 │ │ 暂停 │ │ 停止 │           │
│  └──────┘ └──────┘ └──────┘           │
│                                        │
│  进度: ████████░░░░░░░░  52%           │
│                                        │
│  语速: ──●────────── 1.0x              │
│  音色: [ speaker_1           ▼ ]       │
└────────────────────────────────────────┘
```

### 4.6 交付物

- [ ] 可运行的 iOS App（支持文本输入和文件导入）
- [ ] 基本的播放控制（播放/暂停/停止/进度）
- [ ] 语速和音色选择功能

---

## 5. Phase 3 - 完整语音助手

### 5.1 目标

在 Phase 2 基础上增加 ASR 和 LLM，实现完整的语音对话功能。

### 5.2 完整对话流程

```
┌─────────────────────────────────────────────────────────────┐
│                    语音对话流程                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐                                               │
│  │ 麦克风   │                                               │
│  │ 录音     │                                               │
│  └────┬─────┘                                               │
│       │                                                     │
│       ▼                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  VAD     │───►│   ASR    │───►│  文本    │              │
│  │ 语音检测 │    │ 语音识别 │    │          │              │
│  └──────────┘    └────┬─────┘    └────┬─────┘              │
│                       │              │                     │
│                       ▼              ▼                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  TTS     │◄───│   LLM    │◄───│  Prompt  │              │
│  │ 语音合成 │    │ 对话生成 │    │  构建    │              │
│  └────┬─────┘    └──────────┘    └──────────┘              │
│       │                                                     │
│       ▼                                                     │
│  ┌──────────┐                                               │
│  │ 扬声器   │                                               │
│  │ 播放     │                                               │
│  └──────────┘                                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 关键技术点

| 功能 | 实现方案 |
|------|---------|
| VAD 语音检测 | 使用 Apple 原生 SFSpeechRecognition 或简单能量检测 |
| 流式 ASR | 实时音频流 → 实时文本输出 |
| 对话上下文 | 滑动窗口保留最近 N 轮对话 |
| 语音克隆（可选） | Qwen3-TTS 支持 speaker embedding |

### 5.4 模式切换

```
┌─────────────────────────────────────────────────────────────┐
│                    App 模式                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────┐          ┌─────────────┐                 │
│   │   听书模式   │          │  对话模式   │                 │
│   │             │          │             │                 │
│   │  文本 → TTS │          │ ASR→LLM→TTS │                 │
│   └─────────────┘          └─────────────┘                 │
│                                                             │
│              用户可通过 Tab 切换                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 5.5 性能优化策略

| 策略 | 说明 |
|------|------|
| 模型预加载 | App 启动时加载所有模型到内存 |
| 流式推理 | ASR/LLM/TTS 都支持流式输出 |
| Metal 加速 | 充分利用 Apple Silicon GPU |
| 量化模型 | 使用 Q4_K_M 或 INT4 量化降低内存 |
| 后台预计算 | TTS 可以预生成下一段音频 |

### 5.6 内存估算

| 模型 | 量化 | 内存占用 |
|------|------|---------|
| Qwen3-ASR | Q8_0 | ~200MB |
| Qwen3-0.6B | Q4_K_M | ~400MB |
| Qwen3-TTS | Q8_0 | ~500MB |
| **总计** | | **~1.1GB** |

> 注：实际占用需要实测，iPhone 15 Pro 有 8GB 内存应该足够。

### 5.7 交付物

- [ ] 完整的语音对话功能
- [ ] 听书模式和对话模式切换
- [ ] 对话上下文管理
- [ ] 性能优化达到可用水平

---

## 6. 技术实现细节

### 6.1 Swift-C++ 桥接方案

**C API 设计**（chatllm_bridge.h）

```c
#ifdef __cplusplus
extern "C" {
#endif

// 上下文管理
void* chatllm_create_context(const char* model_path);
void chatllm_free_context(void* ctx);

// TTS 接口
int chatllm_tts_generate(void* ctx,
                         const char* text,
                         float** out_audio,
                         int* out_samples,
                         int* out_sample_rate);

// ASR 接口
int chatllm_asr_transcribe(void* ctx,
                           const float* audio,
                           int samples,
                           int sample_rate,
                           char** out_text);

// LLM 接口
int chatllm_llm_chat(void* ctx,
                     const char* input,
                     char** out_response);

// 释放内存
void chatllm_free_string(char* str);
void chatllm_free_audio(float* audio);

#ifdef __cplusplus
}
#endif
```

**Swift 调用示例**

```swift
class ChatLLMWrapper {
    private var ctx: UnsafeMutableRawPointer?

    init(modelPath: String) {
        ctx = chatllm_create_context(modelPath)
    }

    func generateSpeech(text: String) -> Data? {
        var audioPtr: UnsafeMutablePointer<Float>?
        var samples: Int32 = 0
        var sampleRate: Int32 = 0

        let result = chatllm_tts_generate(
            ctx, text, &audioPtr, &samples, &sampleRate
        )

        guard result == 0, let ptr = audioPtr else { return nil }
        // 转换为 PCM 数据...
    }
}
```

### 6.2 iOS 构建配置

**CMake 配置要点**

```cmake
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(GGML_METAL ON)
set(ENABLE_BITCODE OFF)  # ggml 不支持 bitcode
```

**Xcode Build Settings**

- `ENABLE_BITCODE`: NO
- `Other C++ Flags`: `-std=c++17 -O3`
- `Header Search Paths`: 包含 chatllm.cpp 路径

### 6.3 模型文件管理

**推荐方案**：使用 Files App 共享目录

```
App Documents/
├── Models/
│   ├── qwen3_asr_q8.bin
│   ├── qwen3_0.6b_q4.bin
│   └── qwen3_tts_q8.bin
└── Audiobooks/
    └── sample.txt
```

用户通过 Files App 或 AirDrop 导入模型文件。

---

## 7. 开发里程碑

| 阶段 | 任务 | 预计时间 |
|------|------|---------|
| Phase 1.1 | Mac 环境搭建、模型准备 | 1-2 天 |
| Phase 1.2 | 命令行 ASR/LLM/TTS 验证 | 2-3 天 |
| Phase 1.3 | 完整流程集成测试 | 1-2 天 |
| Phase 2.1 | iOS 项目搭建、chatllm 编译 | 2-3 天 |
| Phase 2.2 | Swift-C++ 桥接、TTS 集成 | 3-4 天 |
| Phase 2.3 | UI 开发、播放器实现 | 2-3 天 |
| Phase 3.1 | ASR 集成、麦克风录音 | 3-4 天 |
| Phase 3.2 | LLM 集成、对话管理 | 2-3 天 |
| Phase 3.3 | 完整流程优化、测试 | 2-3 天 |
| **总计** | | **18-27 天** |

---

## 8. 参考资源

- [chatllm.cpp 仓库](https://github.com/foldl/chatllm.cpp)
- [ggml 库](https://github.com/ggml-org/ggml)
- [Qwen3-TTS 模型](https://huggingface.co/Qwen)
- [Qwen3-ASR 模型](https://huggingface.co/Qwen)
- [Apple Metal 文档](https://developer.apple.com/metal/)
