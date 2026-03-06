#!/bin/bash
# 简单的命令行语音对话工具
# 输入文本 -> LLM -> TTS 输出音频

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CHATLLM_DIR="/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp"
MODELS_DIR="${PROJECT_DIR}/models"
OUTPUT_DIR="${PROJECT_DIR}/output"
DOCKER_IMAGE="tts-cpp:latest"

LLM_MODEL="/models/qwen3-0.6b.bin"
TTS_MODEL="/models/qwen3-tts-12hz-0.6b-base.bin"

mkdir -p ${OUTPUT_DIR}

echo ""
echo "=========================================="
echo "   语音对话工具 (文本输入模式)"
echo "   输入 'quit' 退出"
echo "=========================================="
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
    # Qwen3 会先生成思考内容再生成实际回复，限制总长度，增加超时
    AI_FULL_RESPONSE=$(timeout 300 docker run --rm \
        -v ${CHATLLM_DIR}:/chatllm \
        -v ${MODELS_DIR}:/models \
        -w /chatllm \
        ${DOCKER_IMAGE} \
        ./build/bin/main -m ${LLM_MODEL} -l 300 -p "${USER_INPUT}" 2>&1 | grep -v "^timings:" || true)

    # 提取 </think/> 后的内容作为实际回复
    AI_RESPONSE=$(echo "${AI_FULL_RESPONSE}" | sed -n 's/.*<\/think\/>//p' | head -1)
    if [ -z "$AI_RESPONSE" ]; then
        AI_RESPONSE=$(echo "${AI_FULL_RESPONSE}" | grep -v "^$" | tail -1)
    fi

    # 截断过长的文本（TTS 限制）
    MAX_CHARS=200
    if [ ${#AI_RESPONSE} -gt ${MAX_CHARS} ]; then
        AI_RESPONSE="${AI_RESPONSE:0:${MAX_CHARS}}..."
    fi

    echo "AI > ${AI_RESPONSE}"

    # TTS 生成音频
    docker run --rm \
        -v ${CHATLLM_DIR}:/chatllm \
        -v ${MODELS_DIR}:/models \
        -v ${OUTPUT_DIR}:/output \
        -w /chatllm \
        ${DOCKER_IMAGE} \
        bash -c "./build/bin/main -m ${TTS_MODEL} -p \"${AI_RESPONSE}\" --tts_export /output/last_response.pcm 2>&1 | grep -v -E 'ffplay|invalid pointer' || true" > /dev/null

    # 转换为 WAV
    ffmpeg -y -f s16le -ar 24000 -ac 1 -i ${OUTPUT_DIR}/last_response.pcm \
        ${OUTPUT_DIR}/last_response.wav 2>/dev/null

    echo "    [音频已生成: ${OUTPUT_DIR}/last_response.wav]"
    echo ""
done
