#!/bin/bash
# RabbitMQ 镜像安全验证脚本

echo "========================================="
echo "RabbitMQ 镜像安全验证"
echo "========================================="
echo ""

# 构建镜像
echo "📦 正在构建镜像..."
docker build --no-cache -t rabbitmq-secure:latest -f Dockerfile .

if [ $? -ne 0 ]; then
    echo "❌ 镜像构建失败"
    exit 1
fi

echo "✅ 镜像构建成功"
echo ""

# 检查镜像大小
echo "📏 镜像大小:"
docker images rabbitmq-secure:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
echo ""

# 检查漏洞（如果安装了 trivy）
if command -v trivy &> /dev/null; then
    echo "🔍 使用 Trivy 扫描安全漏洞..."
    trivy image --severity HIGH,CRITICAL rabbitmq-secure:latest
    echo ""
elif command -v docker &> /dev/null && docker inspect anchore/grype &> /dev/null 2>&1; then
    echo "🔍 使用 Grype 扫描安全漏洞..."
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype rabbitmq-secure:latest
    echo ""
else
    echo "⚠️  未检测到安全扫描工具 (trivy 或 grype)"
    echo "   安装方法："
    echo "   - Trivy: https://aquasecurity.github.io/trivy/"
    echo "   - Grype: docker pull anchore/grype"
    echo ""
fi

# 显示镜像层信息
echo "📋 镜像层信息:"
docker history rabbitmq-secure:latest --human=true --format "table {{.CreatedBy}}\t{{.Size}}" | head -10
echo ""

echo "========================================="
echo "✅ 验证完成"
echo "========================================="

