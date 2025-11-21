#!/bin/bash
# Kafka 详细信息查看脚本

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

KAFKA_CONTAINER="kafka"
BOOTSTRAP_SERVER="localhost:9092"

# 检查容器是否运行
check_kafka() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${KAFKA_CONTAINER}$"; then
        echo -e "${RED}❌ 错误: Kafka 容器未运行${NC}"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo "========================================="
    echo "Kafka 信息查看工具"
    echo "========================================="
    echo ""
    echo "使用方法: $0 [命令] [参数]"
    echo ""
    echo "命令列表:"
    echo "  topics              列出所有 topics"
    echo "  topic <name>        查看指定 topic 详情"
    echo "  groups              列出所有 consumer groups"
    echo "  group <name>        查看指定 consumer group 详情"
    echo "  lag <group>         查看 consumer group 消费延迟"
    echo "  brokers             查看 broker 信息"
    echo "  all                 查看所有信息（默认）"
    echo ""
    echo "示例:"
    echo "  $0                  # 查看所有信息"
    echo "  $0 topics           # 只列出 topics"
    echo "  $0 topic test       # 查看 test topic 详情"
    echo "  $0 groups           # 只列出 consumer groups"
    echo "  $0 group my-group   # 查看 my-group 详情"
    echo "  $0 lag my-group     # 查看 my-group 消费延迟"
    echo "========================================="
}

# 列出所有 Topics
list_topics() {
    echo -e "${BLUE}📋 Topics 列表:${NC}"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER
    echo ""
    
    # 统计信息
    TOPIC_COUNT=$(docker exec $KAFKA_CONTAINER kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | wc -l)
    echo -e "${GREEN}总计: $TOPIC_COUNT 个 topics${NC}"
    echo ""
}

# 查看指定 Topic 详情
describe_topic() {
    local topic=$1
    if [ -z "$topic" ]; then
        echo -e "${RED}错误: 请指定 topic 名称${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📊 Topic 详情: ${YELLOW}$topic${NC}"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic "$topic"
    echo ""
}

# 列出所有 Consumer Groups
list_groups() {
    echo -e "${BLUE}👥 Consumer Groups 列表:${NC}"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER
    echo ""
    
    # 统计信息
    GROUP_COUNT=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups --list --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | wc -l)
    echo -e "${GREEN}总计: $GROUP_COUNT 个 consumer groups${NC}"
    echo ""
}

# 查看指定 Consumer Group 详情
describe_group() {
    local group=$1
    if [ -z "$group" ]; then
        echo -e "${RED}错误: 请指定 consumer group 名称${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📊 Consumer Group 详情: ${YELLOW}$group${NC}"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$group"
    echo ""
}

# 查看 Consumer Group 消费延迟
show_lag() {
    local group=$1
    if [ -z "$group" ]; then
        echo -e "${RED}错误: 请指定 consumer group 名称${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📈 Consumer Group 消费延迟: ${YELLOW}$group${NC}"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$group" \
        --members \
        --verbose
    echo ""
}

# 查看 Broker 信息
show_brokers() {
    echo -e "${BLUE}🖥️  Broker 信息:${NC}"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-broker-api-versions \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | head -20
    echo ""
}

# 显示所有信息
show_all() {
    echo "========================================="
    echo -e "${GREEN}Kafka 集群信息概览${NC}"
    echo "========================================="
    echo ""
    
    list_topics
    list_groups
    show_brokers
    
    echo "========================================="
    echo -e "${GREEN}查看完成！${NC}"
    echo "========================================="
}

# 主逻辑
main() {
    check_kafka
    
    local cmd=${1:-all}
    
    case $cmd in
        topics)
            list_topics
            ;;
        topic)
            describe_topic "$2"
            ;;
        groups)
            list_groups
            ;;
        group)
            describe_group "$2"
            ;;
        lag)
            show_lag "$2"
            ;;
        brokers)
            show_brokers
            ;;
        all)
            show_all
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}错误: 未知命令 '$cmd'${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"

