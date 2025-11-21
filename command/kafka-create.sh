#!/bin/bash
# Kafka Topic 和 Consumer Group 创建脚本

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
    echo -e "${BLUE}Kafka Topic 和 Consumer Group 创建工具${NC}"
    echo "========================================="
    echo ""
    echo "使用方法: $0 <命令> [参数]"
    echo ""
    echo "命令列表:"
    echo ""
    echo -e "  ${GREEN}topic${NC} <name> [options]    创建 Topic"
    echo "    参数:"
    echo "      -p, --partitions <num>        分区数（默认: 3）"
    echo "      -r, --replication <num>       副本因子（默认: 1）"
    echo "      -c, --config <key=value>      额外配置"
    echo ""
    echo -e "  ${GREEN}group${NC} <topic> <group-name>  测试 Consumer Group（启动消费者）"
    echo ""
    echo -e "  ${GREEN}delete-topic${NC} <name>         删除 Topic"
    echo ""
    echo -e "  ${GREEN}delete-group${NC} <name>         删除 Consumer Group"
    echo ""
    echo ""
    echo "示例:"
    echo "  # 创建默认配置的 topic"
    echo "  $0 topic my-topic"
    echo ""
    echo "  # 创建自定义配置的 topic"
    echo "  $0 topic order-topic -p 5 -r 1"
    echo ""
    echo "  # 创建带额外配置的 topic"
    echo "  $0 topic log-topic -p 3 -c retention.ms=86400000"
    echo ""
    echo "  # 创建 consumer group（启动消费者测试）"
    echo "  $0 group my-topic my-consumer-group"
    echo ""
    echo "  # 删除 topic"
    echo "  $0 delete-topic old-topic"
    echo ""
    echo "  # 删除 consumer group"
    echo "  $0 delete-group old-group"
    echo ""
    echo "========================================="
}

# 创建 Topic
create_topic() {
    local topic_name=$1
    shift
    
    if [ -z "$topic_name" ]; then
        echo -e "${RED}❌ 错误: 请指定 topic 名称${NC}"
        return 1
    fi
    
    # 默认参数
    local partitions=3
    local replication=1
    local configs=()
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--partitions)
                partitions="$2"
                shift 2
                ;;
            -r|--replication)
                replication="$2"
                shift 2
                ;;
            -c|--config)
                configs+=("--config" "$2")
                shift 2
                ;;
            *)
                echo -e "${YELLOW}⚠️  未知参数: $1${NC}"
                shift
                ;;
        esac
    done
    
    echo -e "${BLUE}📝 创建 Topic...${NC}"
    echo "----------------------------------------"
    echo "Topic 名称: $topic_name"
    echo "分区数: $partitions"
    echo "副本因子: $replication"
    if [ ${#configs[@]} -gt 0 ]; then
        echo "额外配置: ${configs[*]}"
    fi
    echo "----------------------------------------"
    echo ""
    
    # 检查 topic 是否已存在
    if docker exec $KAFKA_CONTAINER kafka-topics \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | grep -q "^${topic_name}$"; then
        echo -e "${YELLOW}⚠️  Topic '$topic_name' 已存在${NC}"
        echo ""
        echo "是否查看详情？(y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            docker exec $KAFKA_CONTAINER kafka-topics \
                --describe \
                --bootstrap-server $BOOTSTRAP_SERVER \
                --topic "$topic_name"
        fi
        return 0
    fi
    
    # 创建 topic
    if docker exec $KAFKA_CONTAINER kafka-topics \
        --create \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic "$topic_name" \
        --partitions "$partitions" \
        --replication-factor "$replication" \
        "${configs[@]}" 2>&1; then
        echo ""
        echo -e "${GREEN}✅ Topic '$topic_name' 创建成功！${NC}"
        echo ""
        
        # 显示创建的 topic 详情
        echo -e "${BLUE}📊 Topic 详情:${NC}"
        echo "----------------------------------------"
        docker exec $KAFKA_CONTAINER kafka-topics \
            --describe \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --topic "$topic_name"
        echo ""
        
        # 提示后续操作
        echo -e "${YELLOW}💡 后续操作:${NC}"
        echo "  # 生产消息:"
        echo "  docker exec -it kafka kafka-console-producer --bootstrap-server localhost:9092 --topic $topic_name"
        echo ""
        echo "  # 消费消息:"
        echo "  docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic $topic_name --from-beginning"
        echo ""
        echo "  # 创建 consumer group:"
        echo "  $0 group $topic_name my-group"
        echo ""
    else
        echo ""
        echo -e "${RED}❌ Topic 创建失败${NC}"
        return 1
    fi
}

# 创建/测试 Consumer Group
create_consumer_group() {
    local topic=$1
    local group=$2
    
    if [ -z "$topic" ] || [ -z "$group" ]; then
        echo -e "${RED}❌ 错误: 请指定 topic 和 group 名称${NC}"
        echo "使用方法: $0 group <topic> <group-name>"
        return 1
    fi
    
    # 检查 topic 是否存在
    if ! docker exec $KAFKA_CONTAINER kafka-topics \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | grep -q "^${topic}$"; then
        echo -e "${RED}❌ 错误: Topic '$topic' 不存在${NC}"
        echo ""
        echo "可用的 Topics:"
        docker exec $KAFKA_CONTAINER kafka-topics \
            --list \
            --bootstrap-server $BOOTSTRAP_SERVER
        return 1
    fi
    
    echo -e "${BLUE}👥 启动 Consumer Group 测试...${NC}"
    echo "----------------------------------------"
    echo "Topic: $topic"
    echo "Group: $group"
    echo "----------------------------------------"
    echo ""
    echo -e "${YELLOW}提示: Consumer Group 会在第一次消费时自动创建${NC}"
    echo -e "${YELLOW}按 Ctrl+C 退出消费者${NC}"
    echo ""
    
    # 启动消费者（这会自动创建 consumer group）
    docker exec -it $KAFKA_CONTAINER kafka-console-consumer \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic "$topic" \
        --group "$group" \
        --from-beginning
    
    echo ""
    echo -e "${GREEN}✅ Consumer Group '$group' 已创建（如果之前不存在）${NC}"
    echo ""
    echo -e "${BLUE}查看 Consumer Group 信息:${NC}"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$group"
}

# 删除 Topic
delete_topic() {
    local topic=$1
    
    if [ -z "$topic" ]; then
        echo -e "${RED}❌ 错误: 请指定 topic 名称${NC}"
        return 1
    fi
    
    # 检查 topic 是否存在
    if ! docker exec $KAFKA_CONTAINER kafka-topics \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | grep -q "^${topic}$"; then
        echo -e "${YELLOW}⚠️  Topic '$topic' 不存在${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  警告: 即将删除 Topic '$topic'${NC}"
    echo ""
    # 显示 topic 详情
    docker exec $KAFKA_CONTAINER kafka-topics \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic "$topic"
    echo ""
    echo "确认删除？(yes/no)"
    read -r response
    
    if [[ "$response" == "yes" ]]; then
        if docker exec $KAFKA_CONTAINER kafka-topics \
            --delete \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --topic "$topic" 2>&1; then
            echo ""
            echo -e "${GREEN}✅ Topic '$topic' 已删除${NC}"
        else
            echo ""
            echo -e "${RED}❌ 删除失败${NC}"
            return 1
        fi
    else
        echo ""
        echo -e "${BLUE}ℹ️  已取消删除${NC}"
    fi
}

# 删除 Consumer Group
delete_consumer_group() {
    local group=$1
    
    if [ -z "$group" ]; then
        echo -e "${RED}❌ 错误: 请指定 consumer group 名称${NC}"
        return 1
    fi
    
    # 检查 group 是否存在
    if ! docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null | grep -q "^${group}$"; then
        echo -e "${YELLOW}⚠️  Consumer Group '$group' 不存在${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  警告: 即将删除 Consumer Group '$group'${NC}"
    echo ""
    # 显示 group 详情
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$group"
    echo ""
    echo -e "${RED}注意: 删除 Consumer Group 前，请确保没有活跃的消费者${NC}"
    echo ""
    echo "确认删除？(yes/no)"
    read -r response
    
    if [[ "$response" == "yes" ]]; then
        if docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --delete \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --group "$group" 2>&1; then
            echo ""
            echo -e "${GREEN}✅ Consumer Group '$group' 已删除${NC}"
        else
            echo ""
            echo -e "${RED}❌ 删除失败${NC}"
            echo -e "${YELLOW}提示: 如果有活跃的消费者，请先停止它们${NC}"
            return 1
        fi
    else
        echo ""
        echo -e "${BLUE}ℹ️  已取消删除${NC}"
    fi
}

# 主逻辑
main() {
    check_kafka
    
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local cmd=$1
    shift
    
    case $cmd in
        topic)
            create_topic "$@"
            ;;
        group)
            create_consumer_group "$@"
            ;;
        delete-topic)
            delete_topic "$@"
            ;;
        delete-group)
            delete_consumer_group "$@"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}❌ 错误: 未知命令 '$cmd'${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"

