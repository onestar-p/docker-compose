#!/bin/bash
# RabbitMQ VHost 管理脚本

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# RabbitMQ 容器名称
RABBITMQ_CONTAINER="rabbitmq"

# 默认用户名和密码
DEFAULT_USER="admin"

# 检查容器是否运行
check_rabbitmq() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${RABBITMQ_CONTAINER}$"; then
        echo -e "${RED}❌ 错误: RabbitMQ 容器 '${RABBITMQ_CONTAINER}' 未运行${NC}"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo "========================================="
    echo -e "${BLUE}RabbitMQ VHost 管理工具${NC}"
    echo "========================================="
    echo ""
    echo "使用方法: $0 <命令> [参数]"
    echo ""
    echo "命令列表:"
    echo -e "  ${GREEN}create <vhost> [user]${NC}       创建 VHost 并配置权限"
    echo -e "  ${GREEN}delete <vhost>${NC}               删除 VHost"
    echo -e "  ${GREEN}list${NC}                         查看所有 VHost"
    echo -e "  ${GREEN}permissions <vhost> [user]${NC}  查看 VHost 权限"
    echo -e "  ${GREEN}grant <vhost> <user>${NC}        授予用户权限"
    echo -e "  ${GREEN}revoke <vhost> <user>${NC}       撤销用户权限"
    echo -e "  ${GREEN}users${NC}                        查看所有用户"
    echo ""
    echo "示例:"
    echo "  $0 list                            # 查看所有 VHost"
    echo "  $0 create my_vhost                 # 创建 VHost（使用默认用户 admin）"
    echo "  $0 create my_vhost myuser          # 创建 VHost 并授予 myuser 权限"
    echo "  $0 delete my_vhost                 # 删除 VHost"
    echo "  $0 permissions my_vhost            # 查看 VHost 权限"
    echo "  $0 grant my_vhost newuser          # 授予用户权限"
    echo ""
    echo "========================================="
}

# 创建 VHost
create_vhost() {
    local vhost=$1
    local user=${2:-$DEFAULT_USER}
    
    if [ -z "$vhost" ]; then
        echo -e "${RED}❌ 错误: 请指定 VHost 名称${NC}"
        echo ""
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  创建 RabbitMQ VHost${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    echo -e "${YELLOW}VHost 名称:${NC} $vhost"
    echo -e "${YELLOW}授权用户:${NC} $user"
    echo ""
    
    # 检查 VHost 是否已存在
    if docker exec $RABBITMQ_CONTAINER rabbitmqctl list_vhosts --formatter json 2>/dev/null | grep -q "\"name\":\"$vhost\""; then
        echo -e "${YELLOW}⚠️  VHost '$vhost' 已存在${NC}"
        echo ""
        
        echo -n "是否继续配置权限？(yes/no): "
        read -r response
        
        if [[ "$response" != "yes" ]]; then
            echo -e "${BLUE}已取消${NC}"
            exit 0
        fi
    else
        # 步骤 1: 创建 VHost
        echo -e "${BLUE}[1/2] 创建 VHost...${NC}"
        if docker exec $RABBITMQ_CONTAINER rabbitmqctl add_vhost "$vhost"; then
            echo -e "${GREEN}✅ VHost '$vhost' 创建成功${NC}"
        else
            echo -e "${RED}❌ VHost 创建失败${NC}"
            exit 1
        fi
        echo ""
    fi
    
    # 步骤 2: 设置权限
    echo -e "${BLUE}[2/2] 配置权限...${NC}"
    
    # 检查用户是否存在
    if ! docker exec $RABBITMQ_CONTAINER rabbitmqctl list_users --formatter json 2>/dev/null | grep -q "\"user\":\"$user\""; then
        echo -e "${YELLOW}⚠️  用户 '$user' 不存在${NC}"
        echo -n "是否创建用户？(yes/no): "
        read -r create_user
        
        if [[ "$create_user" == "yes" ]]; then
            echo -n "请输入密码: "
            read -s password
            echo ""
            
            if docker exec $RABBITMQ_CONTAINER rabbitmqctl add_user "$user" "$password"; then
                echo -e "${GREEN}✅ 用户 '$user' 创建成功${NC}"
                
                # 设置用户标签（可选）
                echo -n "是否设置为管理员？(yes/no): "
                read -r set_admin
                if [[ "$set_admin" == "yes" ]]; then
                    docker exec $RABBITMQ_CONTAINER rabbitmqctl set_user_tags "$user" administrator
                    echo -e "${GREEN}✅ 用户 '$user' 已设置为管理员${NC}"
                fi
            else
                echo -e "${RED}❌ 用户创建失败${NC}"
                exit 1
            fi
        else
            echo -e "${BLUE}已取消${NC}"
            exit 0
        fi
    fi
    
    # 授予权限（配置、写入、读取）
    if docker exec $RABBITMQ_CONTAINER rabbitmqctl set_permissions -p "$vhost" "$user" ".*" ".*" ".*"; then
        echo -e "${GREEN}✅ 权限配置成功${NC}"
    else
        echo -e "${RED}❌ 权限配置失败${NC}"
        exit 1
    fi
    echo ""
    
    # 显示结果
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  创建完成！${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    echo -e "${YELLOW}📋 VHost 信息:${NC}"
    echo "  名称: $vhost"
    echo "  授权用户: $user"
    echo ""
    
    echo -e "${YELLOW}📊 权限详情:${NC}"
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_permissions -p "$vhost" --formatter pretty_table
    echo ""
    
    echo -e "${YELLOW}💡 连接信息:${NC}"
    echo "  VHost: $vhost"
    echo "  用户: $user"
    echo "  URL 示例: amqp://$user:password@localhost:5672/$vhost"
    echo ""
}

# 删除 VHost
delete_vhost() {
    local vhost=$1
    
    if [ -z "$vhost" ]; then
        echo -e "${RED}❌ 错误: 请指定 VHost 名称${NC}"
        echo ""
        show_help
        exit 1
    fi
    
    # 检查 VHost 是否存在
    if ! docker exec $RABBITMQ_CONTAINER rabbitmqctl list_vhosts --formatter json 2>/dev/null | grep -q "\"name\":\"$vhost\""; then
        echo -e "${RED}❌ VHost '$vhost' 不存在${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  警告: 删除 VHost '$vhost'${NC}"
    echo ""
    echo "这将删除该 VHost 下的所有资源："
    echo "  - 所有队列"
    echo "  - 所有交换机"
    echo "  - 所有绑定关系"
    echo "  - 所有权限设置"
    echo ""
    
    # 显示当前状态
    echo -e "${YELLOW}当前资源统计:${NC}"
    local queue_count=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues -p "$vhost" --formatter json 2>/dev/null | grep -c '"name":' || echo "0")
    local exchange_count=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_exchanges -p "$vhost" --formatter json 2>/dev/null | grep -c '"name":' || echo "0")
    echo "  队列数: $queue_count"
    echo "  交换机数: $exchange_count"
    echo ""
    
    echo -n "确认删除？(输入 vhost 名称以确认): "
    read -r confirm
    
    if [[ "$confirm" == "$vhost" ]]; then
        echo ""
        echo -e "${BLUE}正在删除 VHost...${NC}"
        
        if docker exec $RABBITMQ_CONTAINER rabbitmqctl delete_vhost "$vhost"; then
            echo -e "${GREEN}✅ VHost '$vhost' 删除成功${NC}"
        else
            echo -e "${RED}❌ VHost 删除失败${NC}"
            exit 1
        fi
    else
        echo ""
        echo -e "${BLUE}已取消删除${NC}"
    fi
    echo ""
}

# 列出所有 VHost
list_vhosts() {
    echo -e "${BLUE}🏠 VHost 列表${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_vhosts \
        name tracing \
        --formatter pretty_table
    echo ""
    
    # 显示每个 VHost 的统计信息
    echo -e "${BLUE}📊 VHost 统计信息${NC}"
    echo "========================================="
    
    local vhosts=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_vhosts --formatter json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    
    for vhost in $vhosts; do
        local queue_count=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues -p "$vhost" --formatter json 2>/dev/null | grep -c '"name":' || echo "0")
        local exchange_count=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_exchanges -p "$vhost" --formatter json 2>/dev/null | grep -c '"name":' || echo "0")
        local user_count=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_permissions -p "$vhost" --formatter json 2>/dev/null | grep -c '"user":' || echo "0")
        
        echo -e "${YELLOW}$vhost${NC}"
        echo "  队列: $queue_count | 交换机: $exchange_count | 授权用户: $user_count"
    done
    echo ""
}

# 查看权限
show_permissions() {
    local vhost=$1
    local user=${2:-}
    
    if [ -z "$vhost" ]; then
        echo -e "${RED}❌ 错误: 请指定 VHost 名称${NC}"
        echo ""
        show_help
        exit 1
    fi
    
    # 检查 VHost 是否存在
    if ! docker exec $RABBITMQ_CONTAINER rabbitmqctl list_vhosts --formatter json 2>/dev/null | grep -q "\"name\":\"$vhost\""; then
        echo -e "${RED}❌ VHost '$vhost' 不存在${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔐 权限列表 (VHost: $vhost)${NC}"
    echo "========================================="
    
    if [ -z "$user" ]; then
        # 显示所有用户权限
        docker exec $RABBITMQ_CONTAINER rabbitmqctl list_permissions \
            -p "$vhost" \
            --formatter pretty_table
    else
        # 显示指定用户权限
        docker exec $RABBITMQ_CONTAINER rabbitmqctl list_user_permissions "$user" \
            --formatter pretty_table | grep "$vhost" || echo "用户 '$user' 在 VHost '$vhost' 无权限"
    fi
    echo ""
}

# 授予权限
grant_permissions() {
    local vhost=$1
    local user=$2
    
    if [ -z "$vhost" ] || [ -z "$user" ]; then
        echo -e "${RED}❌ 错误: 请指定 VHost 名称和用户名${NC}"
        echo ""
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}授予权限${NC}"
    echo "========================================="
    echo "VHost: $vhost"
    echo "用户: $user"
    echo ""
    
    # 检查用户是否存在
    if ! docker exec $RABBITMQ_CONTAINER rabbitmqctl list_users --formatter json 2>/dev/null | grep -q "\"user\":\"$user\""; then
        echo -e "${RED}❌ 用户 '$user' 不存在${NC}"
        exit 1
    fi
    
    # 自定义权限（默认全部权限）
    echo "权限模式:"
    echo "  1) 完全权限（推荐）"
    echo "  2) 只读权限"
    echo "  3) 只写权限"
    echo "  4) 自定义权限"
    echo ""
    echo -n "选择模式 (1-4, 默认 1): "
    read -r mode
    mode=${mode:-1}
    
    local configure=".*"
    local write=".*"
    local read=".*"
    
    case $mode in
        1)
            # 完全权限
            configure=".*"
            write=".*"
            read=".*"
            echo "模式: 完全权限"
            ;;
        2)
            # 只读
            configure=""
            write=""
            read=".*"
            echo "模式: 只读权限"
            ;;
        3)
            # 只写
            configure=""
            write=".*"
            read=""
            echo "模式: 只写权限"
            ;;
        4)
            # 自定义
            echo -n "配置权限 (正则，默认 .*): "
            read -r configure
            configure=${configure:-".*"}
            
            echo -n "写入权限 (正则，默认 .*): "
            read -r write
            write=${write:-".*"}
            
            echo -n "读取权限 (正则，默认 .*): "
            read -r read
            read=${read:-".*"}
            
            echo "模式: 自定义权限"
            ;;
        *)
            echo -e "${RED}❌ 无效选择${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    if docker exec $RABBITMQ_CONTAINER rabbitmqctl set_permissions -p "$vhost" "$user" "$configure" "$write" "$read"; then
        echo -e "${GREEN}✅ 权限授予成功${NC}"
        echo ""
        
        echo -e "${YELLOW}权限详情:${NC}"
        docker exec $RABBITMQ_CONTAINER rabbitmqctl list_permissions -p "$vhost" --formatter pretty_table | grep "$user"
    else
        echo -e "${RED}❌ 权限授予失败${NC}"
        exit 1
    fi
    echo ""
}

# 撤销权限
revoke_permissions() {
    local vhost=$1
    local user=$2
    
    if [ -z "$vhost" ] || [ -z "$user" ]; then
        echo -e "${RED}❌ 错误: 请指定 VHost 名称和用户名${NC}"
        echo ""
        show_help
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  撤销权限${NC}"
    echo "========================================="
    echo "VHost: $vhost"
    echo "用户: $user"
    echo ""
    
    echo -n "确认撤销？(yes/no): "
    read -r confirm
    
    if [[ "$confirm" == "yes" ]]; then
        if docker exec $RABBITMQ_CONTAINER rabbitmqctl clear_permissions -p "$vhost" "$user"; then
            echo ""
            echo -e "${GREEN}✅ 权限撤销成功${NC}"
        else
            echo ""
            echo -e "${RED}❌ 权限撤销失败${NC}"
            exit 1
        fi
    else
        echo -e "${BLUE}已取消${NC}"
    fi
    echo ""
}

# 列出所有用户
list_users() {
    echo -e "${BLUE}👥 用户列表${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_users \
        --formatter pretty_table
    echo ""
}

# 主逻辑
main() {
    check_rabbitmq
    
    local cmd=${1:-help}
    shift || true
    
    case $cmd in
        create)
            create_vhost "$@"
            ;;
        delete)
            delete_vhost "$@"
            ;;
        list)
            list_vhosts
            ;;
        permissions)
            show_permissions "$@"
            ;;
        grant)
            grant_permissions "$@"
            ;;
        revoke)
            revoke_permissions "$@"
            ;;
        users)
            list_users
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}❌ 未知命令: $cmd${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"

