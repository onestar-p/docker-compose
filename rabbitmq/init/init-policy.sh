#!/bin/bash
# RabbitMQ 自动初始化策略脚本
# 在 RabbitMQ 启动后自动配置重试策略

set -e

# 等待 RabbitMQ 完全启动
echo "等待 RabbitMQ 启动..."
sleep 15

# 从环境变量读取配置（带默认值）
VHOST=${RABBITMQ_DEFAULT_VHOST:-cw_platform_test}
MAX_RETRIES=${RABBITMQ_MAX_RETRIES:-3}
MESSAGE_TTL=${RABBITMQ_MESSAGE_TTL:-3600000}
MAX_LENGTH=${RABBITMQ_MAX_LENGTH:-100000}
DLX_EXCHANGE=${RABBITMQ_DLX_EXCHANGE:-dlx.exchange}
DLX_QUEUE=${RABBITMQ_DLX_QUEUE:-dlx.queue}

echo "========================================="
echo "RabbitMQ 策略初始化"
echo "========================================="
echo "VHost: $VHOST"
echo "最大重试次数: $MAX_RETRIES"
echo "消息 TTL: ${MESSAGE_TTL}ms"
echo "队列最大长度: $MAX_LENGTH"
echo "死信交换机: $DLX_EXCHANGE"
echo "死信队列: $DLX_QUEUE"
echo "========================================="

# 检查 VHost 是否存在
if ! rabbitmqctl list_vhosts | grep -q "^${VHOST}$"; then
    echo "创建 VHost: $VHOST"
    rabbitmqctl add_vhost "$VHOST"
fi

# 创建死信交换机
echo "创建死信交换机: $DLX_EXCHANGE"
rabbitmqadmin -V "$VHOST" declare exchange \
    name="$DLX_EXCHANGE" \
    type="topic" \
    durable=true || echo "死信交换机已存在"

# 创建死信队列
echo "创建死信队列: $DLX_QUEUE"
rabbitmqadmin -V "$VHOST" declare queue \
    name="$DLX_QUEUE" \
    durable=true || echo "死信队列已存在"

# 绑定死信队列到死信交换机
echo "绑定死信队列到死信交换机"
rabbitmqadmin -V "$VHOST" declare binding \
    source="$DLX_EXCHANGE" \
    destination="$DLX_QUEUE" \
    routing_key="#" || echo "绑定已存在"

# 创建全局策略（应用到所有队列）
# 可通过环境变量 RABBITMQ_AUTO_POLICY 控制是否启用（默认启用）
AUTO_POLICY=${RABBITMQ_AUTO_POLICY:-true}

if [ "$AUTO_POLICY" = "true" ]; then
    echo "创建全局重试策略..."
    rabbitmqctl set_policy \
        -p "$VHOST" \
        "auto-retry-policy" \
        ".*" \
        "{\"dead-letter-exchange\":\"$DLX_EXCHANGE\",\"message-ttl\":$MESSAGE_TTL,\"max-length\":$MAX_LENGTH}" \
        --priority 1 \
        --apply-to queues
    
    echo ""
    echo "========================================="
    echo "策略配置完成！"
    echo "========================================="
    echo ""
    echo "所有队列会自动应用以下配置："
    echo "  - 死信交换机: $DLX_EXCHANGE"
    echo "  - 消息 TTL: ${MESSAGE_TTL}ms"
    echo "  - 队列最大长度: $MAX_LENGTH"
else
    echo ""
    echo "========================================="
    echo "⚠️  策略未启用"
    echo "========================================="
    echo ""
    echo "仅创建了死信交换机和死信队列"
    echo "策略未应用到队列"
    echo ""
    echo "如需启用，设置环境变量："
    echo "  RABBITMQ_AUTO_POLICY=true"
fi
echo ""
echo "⚠️  注意："
echo "  - 重试次数需要在消费者代码中实现"
echo "  - 通过检查 x-death header 判断重试次数"
echo "  - 推荐最大重试次数: $MAX_RETRIES"
echo ""
echo "查看策略："
echo "  rabbitmqctl list_policies -p $VHOST"
echo ""

# 显示当前策略
rabbitmqctl list_policies -p "$VHOST" --formatter pretty_table

echo ""
echo "✅ 初始化完成"

