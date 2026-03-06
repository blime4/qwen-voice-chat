#!/bin/bash
# 在 docker 容器内运行 chatllm.cpp 命令
# 用法: ./run_in_docker.sh <chatllm 命令参数...>

set -e

CHATLLM_DIR="/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/chatllm.cpp"
WORK_DIR="/LocalRun/shaobo.xie/2_Pytorch/docker/test/debug/T/boooook"
# 使用 tts-cpp 镜像（包含 GCC 11 和必要库）
# 如果镜像不存在，使用 ubuntu:22.04 并安装编译工具
if docker images tts-cpp:latest | grep -q tts-cpp 2>/dev/null; then
    IMAGE="tts-cpp:latest"
else
    IMAGE="ubuntu:22.04"
fi

# 运行命令
docker run --rm \
    -v ${CHATLLM_DIR}:/chatllm \
    -v ${WORK_DIR}:/work \
    -w /work \
    ${IMAGE} \
    /chatllm/build/bin/main "$@"
