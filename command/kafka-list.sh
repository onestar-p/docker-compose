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

# 3. 列出所有 Consumer Groups
echo "👥 Consumer Groups 列表:"
echo "----------------------------------------"
docker exec $KAFKA_CONTAINER kafka-consumer-groups \
    --list \
    --bootstrap-server $BOOTSTRAP_SERVER
echo ""

# 4. 如果指定了 group，显示详细信息
if [ -n "$GROUP" ]; then
    echo "📊 Consumer Group 详情: $GROUP"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$GROUP"
    echo ""
fi

# 5. 显示统计信息
echo "📈 统计信息:"
echo "----------------------------------------"
TOPIC_COUNT=$(docker exec $KAFKA_CONTAINER kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | wc -l)
GROUP_COUNT=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups --list --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | wc -l)

echo "Topics 总数: $TOPIC_COUNT"
echo "Consumer Groups 总数: $GROUP_COUNT"
echo ""

echo "========================================="
echo "使用方法:"
echo "  $0                    # 列出所有 topics 和 groups"
echo "  $0 <topic>            # 查看指定 topic 详情"
echo "  $0 <topic> <group>    # 查看指定 topic 和 group 详情"
echo ""
echo "示例:"
echo "  $0"
echo "  $0 test-topic"
echo "  $0 test-topic my-consumer-group"
echo "========================================="

