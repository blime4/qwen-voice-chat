#!/bin/bash
# 语音对话流程测试脚本
# 流程: 文本输入 -> LLM -> TTS -> 语音输出
# 使用 docker 容器运行 chatllm.cpp

set -e

# 配置路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHATLLM_DIR="/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp"
MODELS_DIR="${PROJECT_DIR}/models"
OUTPUT_DIR="${PROJECT_DIR}/output"
DOCKER_IMAGE="tts-cpp:latest"

# 模型路径（容器内）
ASR_MODEL="/models/qwen3-asr-0.6b.bin"
LLM_MODEL="/models/qwen3-0.6b.bin"
TTS_MODEL="/models/qwen3-tts-12hz-0.6b-base.bin"

# 创建输出目录
mkdir -p "${OUTPUT_DIR}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Docker 运行命令
docker_run() {
    docker run --rm \
        -v "${CHATLLM_DIR}:/chatllm" \
        -v "${MODELS_DIR}:/models" \
        -v "${OUTPUT_DIR}:/output" \
        -w /chatllm \
        "${DOCKER_IMAGE}" \
        "$@"
}

# TTS 测试
test_tts() {
    local text="$1"
    local output_file="${2:-/output/tts_output.pcm}"
    local max_chars=200  # TTS 最大字符数限制

    # 截断过长的文本
    if [ ${#text} -gt ${max_chars} ]; then
        log_warn "文本过长 (${#text} 字符)，截断到 ${max_chars} 字符"
        text="${text:0:${max_chars}}..."
    fi

    log_info "TTS: 生成语音..."
    log_info "  输入文本: ${text}"
    log_info "  输出文件: ${output_file}"

    # TTS 可能会有 "free(): invalid pointer" 清理错误，但不影响输出
    docker_run bash -c "
        ./build/bin/main -m ${TTS_MODEL} \
            -p \"${text}\" \
            --tts_export ${output_file} 2>&1 | grep -v -E 'ffplay|invalid pointer' || true
    "

    if [ -f "${OUTPUT_DIR}/$(basename ${output_file})" ]; then
        local size=$(stat -c%s "${OUTPUT_DIR}/$(basename ${output_file})")
        log_info "TTS 成功! 文件大小: ${size} bytes"

        # 转换为 WAV
        local wav_file="${output_file%.pcm}.wav"
        ffmpeg -y -f s16le -ar 24000 -ac 1 -i "${OUTPUT_DIR}/$(basename ${output_file})" \
            "${OUTPUT_DIR}/$(basename ${wav_file})" 2>/dev/null
        log_info "WAV 文件: ${OUTPUT_DIR}/$(basename ${wav_file})"
    else
        log_error "TTS 失败!"
        return 1
    fi
}

# LLM 测试
test_llm() {
    local prompt="$1"

    log_info "LLM: 生成回复..."
    log_info "  输入: ${prompt}"

    # 获取 LLM 输出，Qwen3 会先生成思考内容再生成实际回复
    # 使用 max_length 限制总 token 数，需要足够长以包含思考和回复
    local full_output=$(docker_run timeout 300 ./build/bin/main -m ${LLM_MODEL} -l 300 -p "${prompt}" 2>&1 | grep -v "^timings:" || true)

    # 提取 </think/> 后的内容作为实际回复
    local response=$(echo "${full_output}" | sed -n 's/.*<\/think\/>//p' | head -1)
    if [ -z "$response" ]; then
        # 如果没有 </think/> 标记，提取最后一个非空行
        response=$(echo "${full_output}" | grep -v "^$" | tail -1)
    fi

    log_info "LLM 回复:"
    echo "${response}"

    echo "${response}"
}

# 完整流程测试
test_pipeline() {
    local user_input="$1"

    echo ""
    echo "=========================================="
    echo "       语音对话流程测试"
    echo "=========================================="
    echo ""

    # Step 1: LLM 生成回复
    log_info "Step 1: LLM 生成回复"
    local ai_response=$(test_llm "${user_input}")
    echo ""

    # Step 2: TTS 生成语音
    log_info "Step 2: TTS 生成语音"
    test_tts "${ai_response}" "/output/pipeline_response.pcm"
    echo ""

    log_info "流程测试完成!"
    log_info "音频文件: ${OUTPUT_DIR}/pipeline_response.wav"
}

# 主菜单
main() {
    if [ -z "$1" ]; then
        echo "用法: $0 <命令> [参数]"
        echo ""
        echo "命令:"
        echo "  tts <文本>           - TTS 测试"
        echo "  llm <提示>           - LLM 测试"
        echo "  pipeline <输入>      - 完整流程测试"
        echo "  chat                 - 交互式对话"
        exit 1
    fi

    case "$1" in
        tts)
            test_tts "$2"
            ;;
        llm)
            test_llm "$2"
            ;;
        pipeline)
            test_pipeline "$2"
            ;;
        chat)
            interactive_chat
            ;;
        *)
            log_error "未知命令: $1"
            exit 1
            ;;
    esac
}

# 交互式对话
interactive_chat() {
    echo ""
    echo "=========================================="
    echo "       交互式语音对话 (文本模式)"
    echo "  输入 'quit' 退出"
    echo "=========================================="
    echo ""

    while true; do
        read -p "你 > " user_input

        if [ "$user_input" = "quit" ]; then
            log_info "再见!"
            break
        fi

        if [ -z "$user_input" ]; then
            continue
        fi

        test_pipeline "$user_input"
        echo ""
    done
}

main "$@"
