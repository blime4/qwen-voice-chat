# Phase 1: Linux 验证 - ASR/LLM/TTS 核心流程实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Linux 服务器上验证 chatllm.cpp 的 ASR → LLM → TTS 完整流程，确保模型推理正确。

**Architecture:** 直接使用 chatllm.cpp 命令行工具，分别验证 TTS（语音合成）、ASR（语音识别）、LLM（对话）三个模块，最后组合成完整的语音对话流程。

**Tech Stack:** chatllm.cpp (C++/ggml), Qwen3-ASR, Qwen3-TTS, Qwen3 LLM

---

## 前置条件

- Linux 服务器（当前环境）
- chatllm.cpp 代码库位于：`/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp`
- 工作目录：`/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook`
- ffmpeg 用于音频处理

---

### Task 1: 编译 chatllm.cpp

**Files:**
- 使用: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp`

**Step 1: 检查编译依赖**

```bash
# 检查 cmake 版本
cmake --version

# 检查 g++ 版本
g++ --version

# 检查 ffmpeg（用于音频处理）
ffmpeg -version
```

**Step 2: 编译 chatllm.cpp**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

# 创建 build 目录并编译
cmake -B build
cmake --build build -j$(nproc)
```

**Step 3: 验证编译成功**

```bash
# 检查可执行文件
ls -la build/bin/main

# 查看帮助信息
./build/bin/main -h | head -50
```

**Expected:** 编译成功，生成 `build/bin/main` 可执行文件

**Step 4: Commit**

```bash
# 记录编译成功状态
echo "chatllm.cpp compiled successfully at $(date)" >> /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/docs/plans/build.log
```

---

### Task 2: 下载 TTS 模型 (Qwen3-TTS)

**Files:**
- 下载到: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/`

**Step 1: 创建模型目录**

```bash
mkdir -p /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models
```

**Step 2: 下载 Qwen3-TTS 模型**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

# 使用 model_downloader 下载 TTS 模型
python scripts/model_downloader.py -m qwen3-tts:0.6b-base:q8 -o /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/
```

**Expected:** 下载 `qwen3-tts-12hz-0.6b-base.bin` (~1.2GB)

**Step 3: 验证模型文件**

```bash
ls -lh /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/
```

---

### Task 3: 验证 TTS 功能

**Files:**
- 使用: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/qwen3-tts-12hz-0.6b-base.bin`
- 输出: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/tts_test.pcm`

**Step 1: 创建输出目录**

```bash
mkdir -p /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output
```

**Step 2: 运行 TTS 测试**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

# TTS: 将文本转换为语音
./build/bin/main -m /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/qwen3-tts-12hz-0.6b-base.bin \
    -p "你好，这是一个语音合成测试。" \
    --tts_export /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/tts_test.pcm
```

**Step 3: 验证输出文件**

```bash
ls -lh /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/tts_test.pcm

# 检查文件大小（应该有内容）
file /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/tts_test.pcm
```

**Step 4: 转换 PCM 为 WAV（可选，方便播放）**

```bash
# PCM 参数: 24000 Hz, 16-bit, mono
ffmpeg -f s16le -ar 24000 -ac 1 -i /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/tts_test.pcm \
    /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/tts_test.wav

ls -lh /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/tts_test.wav
```

**Expected:** 生成 PCM 音频文件，可转换为 WAV 格式

---

### Task 4: 下载 ASR 模型 (Qwen3-ASR)

**Files:**
- 下载到: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/`

**Step 1: 下载 Qwen3-ASR 模型**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

# 使用 model_downloader 下载 ASR 模型（小模型方便测试）
python scripts/model_downloader.py -m qwen3-asr:0.6b:q8 -o /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/
```

**Expected:** 下载 `qwen3-asr-0.6b.bin` (~1GB)

**Step 2: 验证模型文件**

```bash
ls -lh /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/
```

---

### Task 5: 验证 ASR 功能

**Files:**
- 使用: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/qwen3-asr-0.6b.bin`
- 输入: 测试音频文件

**Step 1: 准备测试音频**

```bash
# 方法1: 使用 TTS 生成的音频
# 先用 TTS 生成一段测试音频
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

./build/bin/main -m /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/qwen3-tts-12hz-0.6b-base.bin \
    -p "今天天气真好，适合外出散步。" \
    --tts_export /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/asr_test_input.pcm

# 转换为 WAV
ffmpeg -f s16le -ar 24000 -ac 1 -i /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/asr_test_input.pcm \
    /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/asr_test_input.wav
```

**Step 2: 运行 ASR 测试**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

# ASR: 识别音频中的语音
./build/bin/main -m /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/qwen3-asr-0.6b.bin \
    -p "{{audio:/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/output/asr_test_input.wav}}" \
    --multimedia_file_tags {{ }}
```

**Expected:** 输出识别的文本，应与 TTS 输入的文本相似

---

### Task 6: 下载 LLM 模型 (Qwen3)

**Files:**
- 下载到: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/`

**Step 1: 下载 Qwen3 小模型**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

# 使用 model_downloader 下载 Qwen3-0.6B 模型
python scripts/model_downloader.py -m qwen3:0.6b:q4_k_m -o /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/
```

**Expected:** 下载 Qwen3-0.6B 量化模型 (~400MB)

**Step 2: 验证模型文件**

```bash
ls -lh /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/
```

---

### Task 7: 验证 LLM 对话功能

**Files:**
- 使用: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/qwen3-0.6b-*.bin`

**Step 1: 运行 LLM 单次对话测试**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

# LLM: 对话测试
./build/bin/main -m /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/qwen3-0.6b-q4_k_m.bin \
    -p "你好，请用一句话介绍一下你自己。"
```

**Expected:** 输出合理的对话回复

**Step 2: 运行 LLM 交互模式测试**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp

# LLM: 交互式对话（需要手动输入）
./build/bin/main -m /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/models/qwen3-0.6b-q4_k_m.bin \
    -i
```

**Expected:** 进入交互模式，可以连续对话

---

### Task 8: 创建完整流程测试脚本

**Files:**
- 创建: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/scripts/voice_pipeline_test.sh`

**Step 1: 创建测试脚本**

```bash
mkdir -p /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/scripts

cat > /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/scripts/voice_pipeline_test.sh << 'EOF'
#!/bin/bash
# 语音对话流程测试脚本
# 流程: 用户语音 -> ASR -> LLM -> TTS -> 语音输出

set -e

# 配置路径
CHATLLM_DIR="/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp"
WORK_DIR="/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook"
MODELS_DIR="${WORK_DIR}/models"
OUTPUT_DIR="${WORK_DIR}/output"

# 模型路径
ASR_MODEL="${MODELS_DIR}/qwen3-asr-0.6b.bin"
LLM_MODEL="${MODELS_DIR}/qwen3-0.6b-q4_k_m.bin"
TTS_MODEL="${MODELS_DIR}/qwen3-tts-12hz-0.6b-base.bin"

# 可执行文件
MAIN="${CHATLLM_DIR}/build/bin/main"

echo "=== 语音对话流程测试 ==="
echo ""

# Step 1: 如果有输入音频，进行 ASR
if [ -f "${OUTPUT_DIR}/user_input.wav" ]; then
    echo "Step 1: ASR - 语音识别"
    USER_TEXT=$(${MAIN} -m ${ASR_MODEL} \
        -p "{{audio:${OUTPUT_DIR}/user_input.wav}}" \
        --multimedia_file_tags {{ }} 2>/dev/null | tail -1)
    echo "识别结果: ${USER_TEXT}"
else
    # 使用默认文本
    USER_TEXT="你好，请简单介绍一下你自己。"
    echo "Step 1: 使用默认文本: ${USER_TEXT}"
fi
echo ""

# Step 2: LLM 生成回复
echo "Step 2: LLM - 生成回复"
AI_RESPONSE=$(${MAIN} -m ${LLM_MODEL} -p "${USER_TEXT}" 2>/dev/null | tail -5)
echo "AI 回复: ${AI_RESPONSE}"
echo ""

# Step 3: TTS 生成语音
echo "Step 3: TTS - 语音合成"
${MAIN} -m ${TTS_MODEL} \
    -p "${AI_RESPONSE}" \
    --tts_export "${OUTPUT_DIR}/ai_response.pcm" 2>/dev/null

# 转换为 WAV
ffmpeg -y -f s16le -ar 24000 -ac 1 -i "${OUTPUT_DIR}/ai_response.pcm" \
    "${OUTPUT_DIR}/ai_response.wav" 2>/dev/null

echo "输出音频: ${OUTPUT_DIR}/ai_response.wav"
echo ""

echo "=== 测试完成 ==="
EOF

chmod +x /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/scripts/voice_pipeline_test.sh
```

**Step 2: 运行完整流程测试**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook
./scripts/voice_pipeline_test.sh
```

**Expected:** 完整流程运行成功，生成 AI 回复的音频文件

---

### Task 9: 创建简单的 CLI 交互工具

**Files:**
- 创建: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/scripts/voice_chat.sh`

**Step 1: 创建交互式语音对话脚本**

```bash
cat > /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/scripts/voice_chat.sh << 'EOF'
#!/bin/bash
# 简单的命令行语音对话工具
# 输入文本 -> LLM -> TTS 输出音频

set -e

CHATLLM_DIR="/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp"
WORK_DIR="/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook"
MODELS_DIR="${WORK_DIR}/models"
OUTPUT_DIR="${WORK_DIR}/output"

LLM_MODEL="${MODELS_DIR}/qwen3-0.6b-q4_k_m.bin"
TTS_MODEL="${MODELS_DIR}/qwen3-tts-12hz-0.6b-base.bin"
MAIN="${CHATLLM_DIR}/build/bin/main"

mkdir -p ${OUTPUT_DIR}

echo "=== 语音对话工具 (文本输入模式) ==="
echo "输入 'quit' 退出"
echo ""

while true; do
    read -p "你 > " USER_INPUT

    if [ "$USER_INPUT" = "quit" ]; then
        echo "再见！"
        break
    fi

    if [ -z "$USER_INPUT" ]; then
        continue
    fi

    # LLM 生成回复
    echo "AI > 正在思考..."
    AI_RESPONSE=$(${MAIN} -m ${LLM_MODEL} -p "${USER_INPUT}" 2>/dev/null | grep -v "^$" | tail -1)
    echo "AI > ${AI_RESPONSE}"

    # TTS 生成音频
    ${MAIN} -m ${TTS_MODEL} -p "${AI_RESPONSE}" \
        --tts_export "${OUTPUT_DIR}/last_response.pcm" 2>/dev/null

    ffmpeg -y -f s16le -ar 24000 -ac 1 -i "${OUTPUT_DIR}/last_response.pcm" \
        "${OUTPUT_DIR}/last_response.wav" 2>/dev/null

    echo "    [音频已生成: ${OUTPUT_DIR}/last_response.wav]"
    echo ""
done
EOF

chmod +x /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/scripts/voice_chat.sh
```

**Step 2: 测试交互工具**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook
./scripts/voice_chat.sh
```

**Expected:** 可以通过命令行进行简单的文本对话，并生成语音输出

---

### Task 10: 记录测试结果和性能数据

**Files:**
- 创建: `/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/docs/plans/phase1_report.md`

**Step 1: 创建测试报告模板**

```bash
cat > /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook/docs/plans/phase1_report.md << 'EOF'
# Phase 1 测试报告

## 测试环境

- 服务器: [填写服务器信息]
- OS: [填写操作系统]
- CPU: [填写 CPU 信息]
- 内存: [填写内存大小]

## 模型信息

| 模型 | 大小 | 用途 |
|------|------|------|
| Qwen3-ASR-0.6B | ~1GB | 语音识别 |
| Qwen3-0.6B | ~400MB | 对话生成 |
| Qwen3-TTS-0.6B | ~1.2GB | 语音合成 |

## 测试结果

### TTS 测试

- 输入文本: "你好，这是一个语音合成测试。"
- 输出文件: output/tts_test.wav
- 状态: [ ] 通过 / [ ] 失败
- 备注:

### ASR 测试

- 输入音频: [TTS 生成的测试音频]
- 识别结果:
- 状态: [ ] 通过 / [ ] 失败
- 备注:

### LLM 测试

- 输入: "你好，请用一句话介绍一下你自己。"
- 输出:
- 状态: [ ] 通过 / [ ] 失败
- 备注:

### 完整流程测试

- 状态: [ ] 通过 / [ ] 失败
- 备注:

## 性能数据

### TTS 性能

- 推理时间: [填写]
- 音频长度: [填写]
- RTF (Real-Time Factor): [填写]

### ASR 性能

- 推理时间: [填写]
- 音频长度: [填写]
- RTF: [填写]

### LLM 性能

- 首字延迟: [填写]
- 生成速度: [tokens/s]

### 内存占用

- TTS 模型内存: [填写]
- ASR 模型内存: [填写]
- LLM 模型内存: [填写]
- 总内存: [填写]

## 问题记录

1. [问题1]
2. [问题2]

## 下一步计划

1. 在 Mac 上验证 Metal 加速
2. 移植到 iOS
3. 实现 Swift-C++ 桥接
EOF

echo "测试报告模板已创建"
```

**Step 2: Commit 所有更改**

```bash
cd /LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook

git add .
git commit -m "$(cat <<'EOF'
feat: add Phase 1 implementation plan and test scripts

- Task 1-7: Build chatllm.cpp, download and test TTS/ASR/LLM models
- Task 8-9: Create voice pipeline test and interactive chat scripts
- Task 10: Create test report template

Models: Qwen3-ASR-0.6B, Qwen3-0.6B, Qwen3-TTS-0.6B
EOF
)"
```

---

## 验收标准

- [ ] chatllm.cpp 编译成功
- [ ] Qwen3-TTS 模型下载并测试通过
- [ ] Qwen3-ASR 模型下载并测试通过
- [ ] Qwen3-LLM 模型下载并测试通过
- [ ] 完整的 ASR → LLM → TTS 流程测试通过
- [ ] 交互式命令行工具可用
- [ ] 测试报告填写完整

## 预计时间

- Task 1: 10 分钟
- Task 2-4: 30 分钟（模型下载时间取决于网络）
- Task 5-7: 20 分钟
- Task 8-9: 20 分钟
- Task 10: 10 分钟

**总计**: 约 1.5 小时（不含模型下载时间）
