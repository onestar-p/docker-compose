#!/bin/bash
# RabbitMQ 策略配置脚本
# 用于配置全局重试策略、死信队列等

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

RABBITMQ_CONTAINER="rabbitmq_01"
DEFAULT_VHOST="cw_platform_test"

# 检查容器是否运行
check_rabbitmq() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${RABBITMQ_CONTAINER}$"; then
        echo -e "${RED}❌ 错误: RabbitMQ 容器未运行${NC}"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo "========================================="
    echo -e "${BLUE}RabbitMQ 策略配置工具${NC}"
    echo "========================================="
    echo ""
    echo "使用方法: $0 <命令> [vhost]"
    echo ""
    echo "命令列表:"
    echo -e "  ${GREEN}setup${NC}           配置完整的重试策略（推荐）"
    echo -e "  ${GREEN}basic${NC}           配置基础重试策略（简化版）"
    echo -e "  ${GREEN}list${NC}            查看当前策略"
    echo -e "  ${GREEN}delete${NC}          删除重试策略"
    echo -e "  ${GREEN}custom${NC}          自定义策略配置"
    echo ""
    echo "示例:"
    echo "  $0 setup                    # 在默认 vhost 配置完整重试策略"
    echo "  $0 setup my_vhost           # 在指定 vhost 配置策略"
    echo "  $0 list                     # 查看当前策略"
    echo "  $0 delete                   # 删除策略"
    echo ""
    echo "========================================="
}

# 配置完整的重试策略
setup_retry_policy() {
    local vhost=${1:-$DEFAULT_VHOST}
    
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  配置 RabbitMQ 重试策略${NC}"
    echo -e "${BLUE}  VHost: $vhost${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    # 配置参数
    local MAX_RETRIES=3
    local MESSAGE_TTL=3600000      # 1小时（毫秒）
    local RETRY_TTL=30000          # 重试延迟 30秒
    local MAX_LENGTH=100000        # 队列最大长度
    
    echo -e "${YELLOW}配置参数:${NC}"
    echo "  最大重试次数: $MAX_RETRIES"
    echo "  消息 TTL: ${MESSAGE_TTL}ms ($(($MESSAGE_TTL/1000/60))分钟)"
    echo "  重试延迟: ${RETRY_TTL}ms ($(($RETRY_TTL/1000))秒)"
    echo "  队列最大长度: $MAX_LENGTH"
    echo ""
    
    # 步骤 1: 创建死信交换机（DLX）
    echo -e "${BLUE}[1/4] 创建死信交换机...${NC}"
    docker exec $RABBITMQ_CONTAINER rabbitmqadmin \
        -V "$vhost" \
        declare exchange \
        name="dlx.exchange" \
        type="topic" \
        durable=true
    echo -e "${GREEN}✅ 死信交换机创建成功${NC}"
    echo ""
    
    # 步骤 2: 创建死信队列
    echo -e "${BLUE}[2/4] 创建死信队列...${NC}"
    docker exec $RABBITMQ_CONTAINER rabbitmqadmin \
        -V "$vhost" \
        declare queue \
        name="dlx.queue" \
        durable=true
    echo -e "${GREEN}✅ 死信队列创建成功${NC}"
    echo ""
    
    # 步骤 3: 绑定死信队列到死信交换机
    echo -e "${BLUE}[3/4] 绑定死信队列...${NC}"
    docker exec $RABBITMQ_CONTAINER rabbitmqadmin \
        -V "$vhost" \
        declare binding \
        source="dlx.exchange" \
        destination="dlx.queue" \
        routing_key="#"
    echo -e "${GREEN}✅ 绑定成功${NC}"
    echo ""
    
    # 步骤 4: 创建策略（应用到所有队列）
    echo -e "${BLUE}[4/4] 创建全局策略...${NC}"
    
    # 注意：RabbitMQ 没有原生的 x-max-retries
    # 我们通过 x-dead-letter-exchange 实现重试机制
    # 重试次数需要在消费者代码中通过 x-death header 判断
    
    docker exec $RABBITMQ_CONTAINER rabbitmqctl set_policy \
        -p "$vhost" \
        "retry-policy" \
        ".*" \
        "{\"dead-letter-exchange\":\"dlx.exchange\",\"message-ttl\":$MESSAGE_TTL,\"max-length\":$MAX_LENGTH}" \
        --priority 1 \
        --apply-to queues
    
    echo -e "${GREEN}✅ 策略配置成功${NC}"
    echo ""
    
    # 显示配置结果
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  配置完成！${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    echo -e "${YELLOW}📋 策略详情:${NC}"
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_policies -p "$vhost" --formatter pretty_table
    echo ""
    
    echo -e "${YELLOW}⚠️  重要说明:${NC}"
    echo ""
    echo "1. 所有队列现在都会自动配置:"
    echo "   - 消息 TTL: ${MESSAGE_TTL}ms"
    echo "   - 死信交换机: dlx.exchange"
    echo "   - 队列最大长度: $MAX_LENGTH"
    echo ""
    echo "2. 重试次数控制需要在消费者代码中实现:"
    echo "   - 通过检查消息的 x-death header"
    echo "   - x-death 的长度就是重试次数"
    echo "   - 达到最大次数后，消息会留在 dlx.queue"
    echo ""
    echo "3. 消费者代码示例:"
    echo "   参考下方的 Go 代码实现"
    echo ""
    
    # 生成消费者示例代码
    cat > /tmp/rabbitmq_consumer_example.go <<'EOF'
package main

import (
    "encoding/json"
    "log"
    "github.com/streadway/amqp"
)

const MAX_RETRIES = 3

func consumeWithRetry(delivery amqp.Delivery, ch *amqp.Channel) {
    // 从 x-death header 获取重试次数
    retryCount := 0
    if xDeath, ok := delivery.Headers["x-death"].([]interface{}); ok {
        retryCount = len(xDeath)
    }
    
    log.Printf("处理消息，当前重试次数: %d/%d", retryCount, MAX_RETRIES)
    
    // 尝试处理消息
    if err := processMessage(delivery.Body); err != nil {
        log.Printf("处理失败: %v", err)
        
        if retryCount < MAX_RETRIES {
            // 重试：拒绝消息，不重新入队（触发 DLX）
            log.Printf("将重试，当前: %d/%d", retryCount+1, MAX_RETRIES)
            delivery.Nack(false, false)
        } else {
            // 超过最大重试次数，彻底失败
            log.Printf("超过最大重试次数，消息进入死信队列")
            delivery.Nack(false, false)
            // 可以发送告警、记录日志等
        }
    } else {
        // 处理成功
        delivery.Ack(false)
        log.Println("消息处理成功")
    }
}

func processMessage(body []byte) error {
    // 你的业务逻辑
    return nil
}
EOF
    
    echo -e "${GREEN}✅ 示例代码已生成: /tmp/rabbitmq_consumer_example.go${NC}"
    echo ""
}

# 配置基础策略（简化版）
setup_basic_policy() {
    local vhost=${1:-$DEFAULT_VHOST}
    
    echo -e "${BLUE}配置基础重试策略 (VHost: $vhost)${NC}"
    echo "========================================="
    
    # 创建死信交换机
    docker exec $RABBITMQ_CONTAINER rabbitmqadmin \
        -V "$vhost" \
        declare exchange \
        name="dlx.exchange" \
        type="topic" \
        durable=true 2>/dev/null || true
    
    # 创建死信队列
    docker exec $RABBITMQ_CONTAINER rabbitmqadmin \
        -V "$vhost" \
        declare queue \
        name="dlx.queue" \
        durable=true 2>/dev/null || true
    
    # 绑定
    docker exec $RABBITMQ_CONTAINER rabbitmqadmin \
        -V "$vhost" \
        declare binding \
        source="dlx.exchange" \
        destination="dlx.queue" \
        routing_key="#" 2>/dev/null || true
    
    # 创建策略
    docker exec $RABBITMQ_CONTAINER rabbitmqctl set_policy \
        -p "$vhost" \
        "retry-policy" \
        ".*" \
        '{"dead-letter-exchange":"dlx.exchange"}' \
        --priority 1 \
        --apply-to queues
    
    echo ""
    echo -e "${GREEN}✅ 基础策略配置完成${NC}"
    echo ""
}

# 查看策略
list_policies() {
    local vhost=${1:-$DEFAULT_VHOST}
    
    echo -e "${BLUE}📋 策略列表 (VHost: $vhost)${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_policies \
        -p "$vhost" \
        --formatter pretty_table
    echo ""
    
    echo -e "${BLUE}📊 死信队列状态:${NC}"
    echo "========================================="
    docker exec $RABBITMQ_CONTAINER rabbitmqctl list_queues \
        -p "$vhost" \
        name messages consumers \
        --formatter pretty_table 2>/dev/null | grep -E "dlx|NAME" || echo "未找到死信队列"
    echo ""
}

# 删除策略
delete_policy() {
    local vhost=${1:-$DEFAULT_VHOST}
    
    echo -e "${YELLOW}⚠️  删除重试策略 (VHost: $vhost)${NC}"
    echo ""
    echo -n "确认删除？(yes/no): "
    read -r response
    
    if [[ "$response" == "yes" ]]; then
        docker exec $RABBITMQ_CONTAINER rabbitmqctl clear_policy \
            -p "$vhost" \
            "retry-policy"
        
        echo ""
        echo -e "${GREEN}✅ 策略已删除${NC}"
        echo ""
        echo -e "${YELLOW}注意: 死信交换机和队列未删除，如需删除请手动操作${NC}"
    else
        echo -e "${BLUE}已取消${NC}"
    fi
}

# 自定义策略
custom_policy() {
    local vhost=${1:-$DEFAULT_VHOST}
    
    echo -e "${BLUE}自定义策略配置${NC}"
    echo "========================================="
    echo ""
    
    echo -n "消息 TTL（毫秒，默认 3600000）: "
    read -r ttl
    ttl=${ttl:-3600000}
    
    echo -n "队列最大长度（默认 100000）: "
    read -r max_length
    max_length=${max_length:-100000}
    
    echo -n "死信交换机名称（默认 dlx.exchange）: "
    read -r dlx_name
    dlx_name=${dlx_name:-dlx.exchange}
    
    echo ""
    echo "配置参数:"
    echo "  消息 TTL: ${ttl}ms"
    echo "  队列最大长度: $max_length"
    echo "  死信交换机: $dlx_name"
    echo ""
    
    echo -n "确认创建？(yes/no): "
    read -r response
    
    if [[ "$response" == "yes" ]]; then
        docker exec $RABBITMQ_CONTAINER rabbitmqctl set_policy \
            -p "$vhost" \
            "retry-policy" \
            ".*" \
            "{\"dead-letter-exchange\":\"$dlx_name\",\"message-ttl\":$ttl,\"max-length\":$max_length}" \
            --priority 1 \
            --apply-to queues
        
        echo ""
        echo -e "${GREEN}✅ 自定义策略配置完成${NC}"
    else
        echo -e "${BLUE}已取消${NC}"
    fi
}

# 主逻辑
main() {
    check_rabbitmq
    
    local cmd=${1:-help}
    local vhost=${2:-$DEFAULT_VHOST}
    
    case $cmd in
        setup)
            setup_retry_policy "$vhost"
            ;;
        basic)
            setup_basic_policy "$vhost"
            ;;
        list)
            list_policies "$vhost"
            ;;
        delete)
            delete_policy "$vhost"
            ;;
        custom)
            custom_policy "$vhost"
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

