#!/bin/bash

# Docker Compose 中间件管理脚本
# 支持启动、停止、重启全部或指定的服务

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 所有可用的服务列表
SERVICES=("kafka" "mongodb" "mysql" "nacos" "rabbitmq" "redis")

# 打印带颜色的消息
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

# 显示横幅
show_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║   Docker Compose 中间件管理工具        ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 显示帮助信息
show_help() {
    show_banner
    cat << EOF
使用方法:
  $0 [命令] [服务名...]

命令:
  start       启动服务（默认）
  stop        停止服务
  restart     重启服务
  status      查看服务状态
  logs        查看服务日志
  list        列出所有可用服务
  help        显示此帮助信息

服务名:
  all         所有服务（默认）
  kafka       Kafka + Zookeeper + Kafka UI
  mongodb     MongoDB + Mongo Express
  mysql       MySQL 8.0
  nacos       Nacos
  rabbitmq    RabbitMQ
  redis       Redis 7.2

示例:
  $0 start all              # 启动所有服务
  $0 start mysql redis      # 启动 MySQL 和 Redis
  $0 stop kafka             # 停止 Kafka
  $0 restart mongodb        # 重启 MongoDB
  $0 status                 # 查看所有服务状态
  $0 logs mysql             # 查看 MySQL 日志

EOF
}

# 列出所有可用服务
list_services() {
    show_banner
    echo "可用的服务列表:"
    echo ""
    for service in "${SERVICES[@]}"; do
        if [ -d "$SCRIPT_DIR/$service" ] && [ -f "$SCRIPT_DIR/$service/compose.yaml" ]; then
            echo -e "  ${GREEN}●${NC} $service"
        else
            echo -e "  ${RED}○${NC} $service (未找到配置)"
        fi
    done
    echo ""
}

# 检查服务是否存在
check_service() {
    local service=$1
    if [ ! -d "$SCRIPT_DIR/$service" ]; then
        print_error "服务 '$service' 不存在"
        return 1
    fi
    if [ ! -f "$SCRIPT_DIR/$service/compose.yaml" ]; then
        print_error "服务 '$service' 缺少 compose.yaml 文件"
        return 1
    fi
    return 0
}

# 启动服务
start_service() {
    local service=$1
    print_info "正在启动 $service..."
    
    if ! check_service "$service"; then
        return 1
    fi
    
    cd "$SCRIPT_DIR/$service" || return 1
    
    if docker compose up -d; then
        print_success "$service 启动成功"
        return 0
    else
        print_error "$service 启动失败"
        return 1
    fi
}

# 停止服务
stop_service() {
    local service=$1
    print_info "正在停止 $service..."
    
    if ! check_service "$service"; then
        return 1
    fi
    
    cd "$SCRIPT_DIR/$service" || return 1
    
    if docker compose down; then
        print_success "$service 停止成功"
        return 0
    else
        print_error "$service 停止失败"
        return 1
    fi
}

# 重启服务
restart_service() {
    local service=$1
    print_info "正在重启 $service..."
    
    stop_service "$service"
    sleep 2
    start_service "$service"
}

# 查看服务状态
status_service() {
    local service=$1
    
    if ! check_service "$service"; then
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}=== $service 状态 ===${NC}"
    cd "$SCRIPT_DIR/$service" || return 1
    docker compose ps
    echo ""
}

# 查看服务日志
logs_service() {
    local service=$1
    
    if ! check_service "$service"; then
        return 1
    fi
    
    print_info "查看 $service 日志 (按 Ctrl+C 退出)..."
    cd "$SCRIPT_DIR/$service" || return 1
    docker compose logs -f
}

# 执行命令
execute_command() {
    local cmd=$1
    shift
    local services=("$@")
    
    # 如果没有指定服务或指定了 all，则操作所有服务
    if [ ${#services[@]} -eq 0 ] || [ "${services[0]}" == "all" ]; then
        services=("${SERVICES[@]}")
    fi
    
    case $cmd in
        start)
            show_banner
            for service in "${services[@]}"; do
                start_service "$service"
            done
            ;;
        stop)
            show_banner
            for service in "${services[@]}"; do
                stop_service "$service"
            done
            ;;
        restart)
            show_banner
            for service in "${services[@]}"; do
                restart_service "$service"
            done
            ;;
        status)
            show_banner
            for service in "${services[@]}"; do
                status_service "$service"
            done
            ;;
        logs)
            if [ ${#services[@]} -gt 1 ]; then
                print_error "logs 命令一次只能查看一个服务的日志"
                exit 1
            fi
            logs_service "${services[0]}"
            ;;
        list)
            list_services
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $cmd"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 主函数
main() {
    # 检查 Docker 是否安装
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查 Docker Compose 是否可用
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose 不可用，请确保已安装 Docker Compose V2"
        exit 1
    fi
    
    # 如果没有参数，显示帮助
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local cmd=$1
    shift
    
    execute_command "$cmd" "$@"
}

# 运行主函数
main "$@"

