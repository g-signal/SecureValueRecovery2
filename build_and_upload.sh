#!/bin/bash
# SVR2 Build and Docker Upload Script for Azure SGX VM
# Based on config/build.properties and README.md

set -euo pipefail

# 读取配置文件
CONFIG_FILE="config/build.properties"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

# 配置变量
DOCKER_REPO="${docker_repo}"
BUILD_PUSH="${build_push}"
LATEST_TAG="${build_latest_tag}"
PROJECT_NAME="svr2"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Docker镜像标签
IMAGE_BASE="${DOCKER_REPO}/${PROJECT_NAME}"
IMAGE_TAG="${IMAGE_BASE}:${GIT_COMMIT}-${TIMESTAMP}"
LATEST_IMAGE="${IMAGE_BASE}:latest"

echo "=== SVR2 Build and Upload Script ==="
echo "Docker Repository: $DOCKER_REPO"
echo "Image Tag: $IMAGE_TAG"
echo "Push Enabled: $BUILD_PUSH"
echo "Latest Tag: $LATEST_TAG"
echo

# 2. 初始化Git子模块
echo "2. Initializing Git submodules..."
git submodule update --init --recursive
echo "✓ Git submodules updated"

# 3. 构建Docker基础镜像
echo "3. Building Docker base image..."
export DOCKER_BUILD_ARGS="--platform=linux/amd64"

# 8. 构建最终Docker镜像
echo "8. Building final Docker image..."
docker buildx build "$DOCKER_BUILD_ARGS" --load -f docker/Dockerfile -t "$IMAGE_TAG" --target=sgxrun .



if [[ "$LATEST_TAG" == "true" ]]; then
    docker tag "$IMAGE_TAG" "$LATEST_IMAGE"
fi

echo "✓ Docker image built: $IMAGE_TAG"


# 10. 上传Docker镜像
if [[ "$BUILD_PUSH" == "true" ]]; then
    echo "10. Pushing Docker images..."


    # 推送镜像
    echo "Pushing $IMAGE_TAG..."
    docker push "$IMAGE_TAG"

    if [[ "$LATEST_TAG" == "true" ]]; then
        echo "Pushing $LATEST_IMAGE..."
        docker push "$LATEST_IMAGE"
    fi

    echo "✓ Docker images pushed successfully"
else
    echo "10. Skipping push (BUILD_PUSH=false)"
fi

# 11. 清理
echo "11. Cleaning up..."
rm -f Dockerfile.svr2
echo "✓ Cleanup completed"

# 12. 输出MRENCLAVE信息
echo "12. MRENCLAVE Information:"
for enclave_file in enclave/build/enclave.Standard_DC*s_v3; do
    if [[ -f "$enclave_file" ]]; then
        echo "File: $(basename "$enclave_file")"
        /opt/openenclave/bin/oesign dump -e "$enclave_file" | grep -i mrenclave || true
        echo
    fi
done

echo "=== Build Summary ==="
echo "✓ SVR2 build completed successfully"
echo "✓ Docker image: $IMAGE_TAG"
if [[ "$LATEST_TAG" == "true" ]]; then
    echo "✓ Latest image: $LATEST_IMAGE"
fi
if [[ "$BUILD_PUSH" == "true" ]]; then
    echo "✓ Images pushed to registry"
fi
echo
echo "To run the container:"
echo "docker run -d --name svr2 \\"
echo "  --device=/dev/sgx_enclave \\"
echo "  --device=/dev/sgx_provision \\"
echo "  -v /var/run/aesmd:/var/run/aesmd \\"
echo "  -v /etc/sgx_default_qcnl.conf:/etc/sgx_default_qcnl.conf:ro \\"
echo "  -p 8080:8080 \\"
echo "  $IMAGE_TAG"
echo
echo "=== Build Complete ==="
