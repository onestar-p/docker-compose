#!/bin/bash

# Docker 镜像加速器配置脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

show_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║   Docker 镜像加速器配置工具            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查是否以 root 权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 sudo 运行此脚本"
        echo "使用方法: sudo $0"
        exit 1
    fi
}

# 备份原配置
backup_config() {
    if [ -f /etc/docker/daemon.json ]; then
        print_info "备份原配置文件..."
        cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
        print_success "备份完成"
    fi
}

# 配置镜像加速器
configure_mirrors() {
    print_info "配置 Docker 镜像加速器..."
    
    mkdir -p /etc/docker
    
    cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
    
    print_success "配置文件已创建"
}

# 重启 Docker 服务
restart_docker() {
    print_info "重启 Docker 服务..."
    
    systemctl daemon-reload
    
    if systemctl restart docker; then
        print_success "Docker 服务重启成功"
    else
        print_error "Docker 服务重启失败"
        exit 1
    fi
    
    # 等待 Docker 完全启动
    sleep 3
}

# 验证配置
verify_config() {
    print_info "验证配置..."
    echo ""
    
    if docker info > /dev/null 2>&1; then
        print_success "Docker 服务运行正常"
        echo ""
        echo -e "${BLUE}当前配置的镜像加速器：${NC}"
        docker info | grep -A 10 "Registry Mirrors" || echo "未找到镜像加速器配置"
        echo ""
    else
        print_error "Docker 服务异常"
        exit 1
    fi
}

# 测试拉取镜像
test_pull() {
    print_info "测试拉取镜像（hello-world）..."
    
    if docker pull hello-world:latest; then
        print_success "镜像拉取成功！配置生效"
        # 清理测试镜像
        docker rmi hello-world:latest > /dev/null 2>&1
    else
        print_warning "镜像拉取失败，请检查网络连接"
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    echo -e "${GREEN}配置完成！${NC}"
    echo ""
    echo "现在可以正常使用 Docker 拉取镜像了："
    echo ""
    echo "  # 拉取镜像"
    echo "  docker pull mysql:8.0"
    echo ""
    echo "  # 启动服务"
    echo "  cd /home/pengyixing/docker-compose"
    echo "  ./manage.sh start mysql"
    echo ""
    echo "配置文件位置: /etc/docker/daemon.json"
    echo ""
    print_info "如果仍然无法拉取镜像，可以尝试："
    echo "  1. 检查网络连接"
    echo "  2. 使用阿里云镜像加速器（需要注册账号）"
    echo "  3. 使用 VPN 或代理"
    echo ""
}

# 主函数
main() {
    show_banner
    
    # 检查 root 权限
    check_root
    
    # 检查 Docker 是否安装
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 备份原配置
    backup_config
    
    # 配置镜像加速器
    configure_mirrors
    
    # 重启 Docker
    restart_docker
    
    # 验证配置
    verify_config
    
    # 测试拉取
    test_pull
    
    # 显示使用说明
    show_usage
}

# 运行主函数
main

