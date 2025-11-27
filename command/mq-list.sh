#!/bin/bash
# RabbitMQ 队列详细信息查看脚本

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# RabbitMQ 容器名称
RABBITMQ_CONTAINER="rabbitmq_01"
DEFAULT_VHOST="cw_platform_test"

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
    echo -e "${BLUE}RabbitMQ 队列信息查看工具${NC}"
    echo "========================================="
    echo ""
    echo "使用方法: $0 [命令] [vhost]"
    echo ""
    echo "命令列表:"
    echo -e "  ${GREEN}queues${NC}      查看队列列表（默认）"
    echo -e "  ${GREEN}detail${NC}      查看队列详细信息（含重试配置）"
    echo -e "  ${GREEN}exchanges${NC}   查看 Exchange 列表"
    echo -e "  ${GREEN}bindings${NC}    查看绑定关系"
    echo -e "  ${GREEN}policies${NC}    查看策略列表"
    echo -e "  ${GREEN}vhosts${NC}      查看所有 VHost"
    echo -e "  ${GREEN}stats${NC}       查看统计信息"
    echo -e "  ${GREEN}all${NC}         查看所有信息"
    echo ""
    echo "示例:"
    echo "  $0                          # 查看默认 vhost 的队列"
    echo "  $0 queues my_vhost          # 查看指定 vhost 的队列"
    echo "  $0 detail                   # 查看详细信息（含重试次数）"
    echo "  $0 all                      # 查看所有信息"
    echo ""
    echo "========================================="
}

# 列出队列（简洁模式）
list_queues() {
    local vhost=$1
    
    echo -e "${BLUE}📋 队列列表 (VHost: $vhost)${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
        -p "$vhost" \
        name messages messages_ready messages_unacknowledged consumers \
        --formatter pretty_table
    echo ""
}

# 查看队列详细信息（含重试配置）
show_queue_details() {
    local vhost=$1
    
    echo -e "${BLUE}📊 队列详细信息 (VHost: $vhost)${NC}"
    echo "========================================="
    
    # 获取所有队列名称
    local queues=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
        -p "$vhost" \
        name --formatter json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$queues" ]; then
        echo -e "${YELLOW}⚠️  没有找到队列${NC}"
        echo ""
        return
    fi
    
    # 逐个显示队列详情
    for queue in $queues; do
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}队列名称:${NC} $queue"
        echo "----------------------------------------"
        
        # 基本信息
        docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
            -p "$vhost" \
            name messages consumers messages_ready messages_unacknowledged \
            state --formatter pretty_table 2>/dev/null | grep -A 1 "$queue" || true
        
        echo ""
        echo -e "${YELLOW}队列参数 (Arguments):${NC}"
        # 显示队列参数（包含重试配置）
        local queue_info=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
            -p "$vhost" \
            name arguments --formatter json 2>/dev/null | grep -A 50 "\"name\":\"$queue\"")
        
        # 解析关键参数
        if echo "$queue_info" | grep -q "x-max-retries"; then
            local max_retries=$(echo "$queue_info" | grep -o '"x-max-retries":[0-9]*' | cut -d':' -f2)
            echo -e "  ${GREEN}最大重试次数 (x-max-retries):${NC} $max_retries"
        else
            echo -e "  ${YELLOW}最大重试次数:${NC} 未配置"
        fi
        
        if echo "$queue_info" | grep -q "x-message-ttl"; then
            local ttl=$(echo "$queue_info" | grep -o '"x-message-ttl":[0-9]*' | cut -d':' -f2)
            echo -e "  ${GREEN}消息 TTL (x-message-ttl):${NC} ${ttl}ms"
        fi
        
        if echo "$queue_info" | grep -q "x-dead-letter-exchange"; then
            local dlx=$(echo "$queue_info" | grep -o '"x-dead-letter-exchange":"[^"]*"' | cut -d'"' -f4)
            echo -e "  ${GREEN}死信交换机 (x-dead-letter-exchange):${NC} $dlx"
        fi
        
        if echo "$queue_info" | grep -q "x-dead-letter-routing-key"; then
            local dlrk=$(echo "$queue_info" | grep -o '"x-dead-letter-routing-key":"[^"]*"' | cut -d'"' -f4)
            echo -e "  ${GREEN}死信路由键 (x-dead-letter-routing-key):${NC} $dlrk"
        fi
        
        if echo "$queue_info" | grep -q "x-max-length"; then
            local max_len=$(echo "$queue_info" | grep -o '"x-max-length":[0-9]*' | cut -d':' -f2)
            echo -e "  ${GREEN}最大长度 (x-max-length):${NC} $max_len"
        fi
        
        if echo "$queue_info" | grep -q "x-queue-mode"; then
            local queue_mode=$(echo "$queue_info" | grep -o '"x-queue-mode":"[^"]*"' | cut -d'"' -f4)
            echo -e "  ${GREEN}队列模式 (x-queue-mode):${NC} $queue_mode"
        fi
        
        # 显示原始参数（JSON 格式）
        echo ""
        echo -e "${YELLOW}完整参数 (JSON):${NC}"
        echo "$queue_info" | grep -o '"arguments":{[^}]*}' | sed 's/^/  /'
        
        echo ""
    done
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 列出 Exchanges
list_exchanges() {
    local vhost=$1
    
    echo -e "${BLUE}🔀 Exchange 列表 (VHost: $vhost)${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_exchanges \
        -p "$vhost" \
        name type durable auto_delete \
        --formatter pretty_table
    echo ""
}

# 列出 Bindings
list_bindings() {
    local vhost=$1
    
    echo -e "${BLUE}🔗 绑定关系 (VHost: $vhost)${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_bindings \
        -p "$vhost" \
        source_name source_kind destination_name destination_kind routing_key \
        --formatter pretty_table
    echo ""
}

# 列出 Policies
list_policies() {
    local vhost=$1
    
    echo -e "${BLUE}📜 策略列表 (VHost: $vhost)${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_policies \
        -p "$vhost" \
        --formatter pretty_table 2>/dev/null || echo "暂无策略"
    echo ""
}

# 列出所有 VHosts
list_vhosts() {
    echo -e "${BLUE}🏠 VHost 列表${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_vhosts \
        name tracing \
        --formatter pretty_table
    echo ""
}

# 显示统计信息
show_stats() {
    local vhost=$1
    
    echo -e "${BLUE}📈 统计信息 (VHost: $vhost)${NC}"
    echo "========================================="
    
    # 队列统计
    local queue_count=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
        -p "$vhost" --formatter json 2>/dev/null | grep -c '"name":')
    
    # 消息统计
    local total_messages=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
        -p "$vhost" messages --formatter json 2>/dev/null | \
        grep -o '"messages":[0-9]*' | cut -d':' -f2 | awk '{sum+=$1} END {print sum+0}')
    
    local ready_messages=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
        -p "$vhost" messages_ready --formatter json 2>/dev/null | \
        grep -o '"messages_ready":[0-9]*' | cut -d':' -f2 | awk '{sum+=$1} END {print sum+0}')
    
    local unacked_messages=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
        -p "$vhost" messages_unacknowledged --formatter json 2>/dev/null | \
        grep -o '"messages_unacknowledged":[0-9]*' | cut -d':' -f2 | awk '{sum+=$1} END {print sum+0}')
    
    # 消费者统计
    local total_consumers=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
        -p "$vhost" consumers --formatter json 2>/dev/null | \
        grep -o '"consumers":[0-9]*' | cut -d':' -f2 | awk '{sum+=$1} END {print sum+0}')
    
    # Exchange 统计
    local exchange_count=$(docker exec $RABBITMQ_CONTAINER rabbitmqctl list_exchanges \
        -p "$vhost" --formatter json 2>/dev/null | grep -c '"name":')
    
    echo "队列总数:           $queue_count"
    echo "Exchange 总数:      $exchange_count"
    echo "消费者总数:         $total_consumers"
    echo ""
    echo "消息总数:           $total_messages"
    echo "  - 待处理:         $ready_messages"
    echo "  - 未确认:         $unacked_messages"
    echo ""
}

# 显示所有信息
show_all() {
    local vhost=$1
    
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  RabbitMQ 完整信息概览${NC}"
    echo -e "${BLUE}  VHost: $vhost${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    show_stats "$vhost"
    list_queues "$vhost"
    list_exchanges "$vhost"
    list_bindings "$vhost"
    list_policies "$vhost"
}

# 主逻辑
main() {
    check_rabbitmq
    
    local cmd=${1:-queues}
    local vhost=${2:-$DEFAULT_VHOST}
    
    # 如果第一个参数不是命令，则认为是 vhost
    case $cmd in
        queues|detail|exchanges|bindings|policies|vhosts|stats|all|help|-h|--help)
            # 是命令，使用第二个参数作为 vhost
            ;;
        *)
            # 不是命令，第一个参数作为 vhost
            vhost=$cmd
            cmd="queues"
            ;;
    esac
    
    case $cmd in
        queues)
            list_queues "$vhost"
            ;;
        detail)
            show_queue_details "$vhost"
            ;;
        exchanges)
            list_exchanges "$vhost"
            ;;
        bindings)
            list_bindings "$vhost"
            ;;
        policies)
            list_policies "$vhost"
            ;;
        vhosts)
            list_vhosts
            ;;
        stats)
            show_stats "$vhost"
            ;;
        all)
            show_all "$vhost"
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