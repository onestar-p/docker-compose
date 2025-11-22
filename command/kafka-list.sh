#!/bin/bash
# Kafka Topic 和 Consumer Group 查看脚本

echo "========================================="
echo "Kafka Topic 和 Consumer Group 列表"
echo "========================================="
echo ""

# 参数说明
TOPIC=${1:-}
GROUP=${2:-}

# Kafka 容器名称
KAFKA_CONTAINER="kafka"
BOOTSTRAP_SERVER="localhost:9092"

# 检查容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "^${KAFKA_CONTAINER}$"; then
    echo "❌ 错误: Kafka 容器 '${KAFKA_CONTAINER}' 未运行"
    exit 1
fi

# 1. 列出所有 Topics
echo "📋 Topics 列表:"
echo "----------------------------------------"
docker exec $KAFKA_CONTAINER kafka-topics \
    --list \
    --bootstrap-server $BOOTSTRAP_SERVER
echo ""

# 2. 如果指定了 topic，显示详细信息
if [ -n "$TOPIC" ]; then
    echo "📊 Topic 详情: $TOPIC"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic "$TOPIC"
    echo ""
fi

# 3. 列出所有 Consumer Groups（包含消费者数量）
echo "👥 Consumer Groups 列表（含消费者数量）:"
echo "----------------------------------------"
GROUPS=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
    --list \
    --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null)

if [ -n "$GROUPS" ]; then
    printf "%-40s %-10s %-15s\n" "GROUP NAME" "MEMBERS" "STATE"
    echo "--------------------------------------------------------------------------------"
    
    for group in $GROUPS; do
        # 获取 group 状态信息（包含消费者数量）
        STATE_INFO=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --describe \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --group "$group" \
            --state 2>/dev/null | tail -n 1)
        
        MEMBERS=$(echo "$STATE_INFO" | awk '{print $NF}')
        STATE=$(echo "$STATE_INFO" | awk '{print $(NF-1)}')
        
        # 根据消费者数量显示不同颜色
        if [ "$MEMBERS" = "0" ]; then
            printf "%-40s \033[1;33m%-10s\033[0m %-15s\n" "$group" "$MEMBERS" "$STATE"
        else
            printf "%-40s \033[0;32m%-10s\033[0m %-15s\n" "$group" "$MEMBERS" "$STATE"
        fi
    done
else
    echo "暂无 Consumer Group"
fi
echo ""

# 4. 如果指定了 group，显示详细信息
if [ -n "$GROUP" ]; then
    echo "📊 Consumer Group 详情: $GROUP"
    echo "----------------------------------------"
    
    # 显示状态信息（包含消费者数量）
    echo "状态信息:"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$GROUP" \
        --state
    echo ""
    
    # 显示消费进度
    echo "消费进度:"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$GROUP"
    echo ""
    
    # 显示成员信息
    echo "成员列表:"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$GROUP" \
        --members
    echo ""
fi

# 5. 显示统计信息
echo "📈 统计信息:"
echo "----------------------------------------"
TOPIC_COUNT=$(docker exec $KAFKA_CONTAINER kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | wc -l)
GROUP_COUNT=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups --list --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | wc -l)

# 统计总消费者数量
TOTAL_CONSUMERS=0
if [ -n "$GROUPS" ]; then
    for group in $GROUPS; do
        MEMBERS=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --describe \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --group "$group" \
            --state 2>/dev/null | tail -n 1 | awk '{print $NF}')
        TOTAL_CONSUMERS=$((TOTAL_CONSUMERS + MEMBERS))
    done
fi

echo "Topics 总数: $TOPIC_COUNT"
echo "Consumer Groups 总数: $GROUP_COUNT"
echo "活跃消费者总数: $TOTAL_CONSUMERS"
echo ""

echo "========================================="
echo "使用方法:"
echo "  $0                    # 列出所有 topics 和 groups（含消费者数量）"
echo "  $0 <topic>            # 查看指定 topic 详情"
echo "  $0 <topic> <group>    # 查看指定 topic 和 group 详情"
echo ""
echo "示例:"
echo "  $0                              # 显示所有信息"
echo "  $0 test-topic                   # 显示 topic 详情"
echo "  $0 test-topic my-consumer-group # 显示 topic 和 group 详情"
echo ""
echo "说明:"
echo "  - MEMBERS 绿色表示有活跃消费者"
echo "  - MEMBERS 黄色表示无消费者（空闲）"
echo "========================================="

