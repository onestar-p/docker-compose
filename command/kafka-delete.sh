#!/bin/bash
# Kafka Topic 和 Consumer Group 删除脚本

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
    echo -e "${BLUE}Kafka 删除工具${NC}"
    echo "========================================="
    echo ""
    echo "使用方法: $0 <命令> <名称> [选项]"
    echo ""
    echo "命令列表:"
    echo ""
    echo -e "  ${GREEN}topic${NC} <name> [--force]        删除 Topic"
    echo "    选项:"
    echo "      --force                   跳过确认，直接删除"
    echo ""
    echo -e "  ${GREEN}group${NC} <name> [--force]        删除 Consumer Group"
    echo "    选项:"
    echo "      --force                   跳过确认，直接删除"
    echo ""
    echo -e "  ${GREEN}topics${NC} [--force]              删除所有 Topic（危险！）"
    echo ""
    echo -e "  ${GREEN}groups${NC} [--force]              删除所有 Consumer Group"
    echo ""
    echo -e "  ${GREEN}clean${NC} [--force]               清理空闲的 Consumer Group"
    echo ""
    echo ""
    echo "示例:"
    echo "  # 删除指定 topic"
    echo "  $0 topic my-topic"
    echo ""
    echo "  # 强制删除 topic（跳过确认）"
    echo "  $0 topic my-topic --force"
    echo ""
    echo "  # 删除指定 consumer group"
    echo "  $0 group my-consumer-group"
    echo ""
    echo "  # 清理所有空闲的 consumer group"
    echo "  $0 clean"
    echo ""
    echo "  # 删除所有 topic（危险操作！）"
    echo "  $0 topics --force"
    echo ""
    echo "========================================="
}

# 确认操作
confirm_action() {
    local message=$1
    echo -e "${YELLOW}$message${NC}"
    echo -n "确认？(yes/no): "
    read -r response
    [[ "$response" == "yes" ]]
}

# 删除单个 Topic
delete_topic() {
    local topic=$1
    local force=${2:-false}
    
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
    
    echo -e "${BLUE}📊 Topic 信息:${NC}"
    echo "----------------------------------------"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic "$topic"
    echo ""
    
    # 检查是否有消费者组在使用
    echo -e "${BLUE}📋 检查关联的 Consumer Groups...${NC}"
    local groups=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null)
    
    local related_groups=()
    for group in $groups; do
        if docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --describe \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --group "$group" 2>/dev/null | grep -q "$topic"; then
            related_groups+=("$group")
        fi
    done
    
    if [ ${#related_groups[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  以下 Consumer Groups 正在使用此 Topic:${NC}"
        for g in "${related_groups[@]}"; do
            echo "  - $g"
        done
        echo ""
    fi
    
    # 确认删除
    if [ "$force" != "--force" ]; then
        if ! confirm_action "⚠️  确认删除 Topic '$topic'？"; then
            echo -e "${BLUE}ℹ️  已取消删除${NC}"
            return 0
        fi
    fi
    
    # 执行删除
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
}

# 删除单个 Consumer Group
delete_group() {
    local group=$1
    local force=${2:-false}
    
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
    
    echo -e "${BLUE}📊 Consumer Group 信息:${NC}"
    echo "----------------------------------------"
    
    # 显示状态
    echo "状态:"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$group" \
        --state
    echo ""
    
    # 显示消费详情
    echo "消费详情:"
    docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$group"
    echo ""
    
    # 检查是否有活跃消费者
    local members=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --describe \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group "$group" \
        --state 2>/dev/null | tail -n 1 | awk '{print $NF}')
    
    if [[ "$members" =~ ^[0-9]+$ ]] && [ "$members" -gt 0 ]; then
        echo -e "${RED}⚠️  警告: 该 Consumer Group 有 $members 个活跃消费者${NC}"
        echo -e "${YELLOW}建议先停止消费者再删除${NC}"
        echo ""
    fi
    
    # 确认删除
    if [ "$force" != "--force" ]; then
        if ! confirm_action "⚠️  确认删除 Consumer Group '$group'？"; then
            echo -e "${BLUE}ℹ️  已取消删除${NC}"
            return 0
        fi
    fi
    
    # 执行删除
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
}

# 删除所有 Topics
delete_all_topics() {
    local force=${1:-false}
    
    echo -e "${BLUE}📋 获取所有 Topics...${NC}"
    local topics=$(docker exec $KAFKA_CONTAINER kafka-topics \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null)
    
    if [ -z "$topics" ]; then
        echo -e "${YELLOW}⚠️  没有找到任何 Topic${NC}"
        return 0
    fi
    
    local topic_count=$(echo "$topics" | wc -l)
    echo -e "${YELLOW}找到 $topic_count 个 Topic:${NC}"
    echo "$topics"
    echo ""
    
    # 确认删除
    if [ "$force" != "--force" ]; then
        echo -e "${RED}=========================================${NC}"
        echo -e "${RED}  ⚠️  危险操作警告 ⚠️${NC}"
        echo -e "${RED}=========================================${NC}"
        echo ""
        if ! confirm_action "确认删除所有 $topic_count 个 Topic？"; then
            echo -e "${BLUE}ℹ️  已取消删除${NC}"
            return 0
        fi
    fi
    
    # 逐个删除
    echo ""
    echo -e "${BLUE}开始删除...${NC}"
    local success=0
    local failed=0
    
    for topic in $topics; do
        echo -n "删除 $topic... "
        if docker exec $KAFKA_CONTAINER kafka-topics \
            --delete \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --topic "$topic" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            ((success++))
        else
            echo -e "${RED}✗${NC}"
            ((failed++))
        fi
    done
    
    echo ""
    echo -e "${BLUE}删除完成:${NC}"
    echo "  成功: $success"
    echo "  失败: $failed"
}

# 删除所有 Consumer Groups
delete_all_groups() {
    local force=${1:-false}
    
    echo -e "${BLUE}📋 获取所有 Consumer Groups...${NC}"
    local groups=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null)
    
    if [ -z "$groups" ]; then
        echo -e "${YELLOW}⚠️  没有找到任何 Consumer Group${NC}"
        return 0
    fi
    
    local group_count=$(echo "$groups" | wc -l)
    echo -e "${YELLOW}找到 $group_count 个 Consumer Group:${NC}"
    echo "$groups"
    echo ""
    
    # 确认删除
    if [ "$force" != "--force" ]; then
        echo -e "${RED}=========================================${NC}"
        echo -e "${RED}  ⚠️  危险操作警告 ⚠️${NC}"
        echo -e "${RED}=========================================${NC}"
        echo ""
        if ! confirm_action "确认删除所有 $group_count 个 Consumer Group？"; then
            echo -e "${BLUE}ℹ️  已取消删除${NC}"
            return 0
        fi
    fi
    
    # 逐个删除
    echo ""
    echo -e "${BLUE}开始删除...${NC}"
    local success=0
    local failed=0
    
    for group in $groups; do
        echo -n "删除 $group... "
        if docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --delete \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --group "$group" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            ((success++))
        else
            echo -e "${RED}✗${NC}"
            ((failed++))
        fi
    done
    
    echo ""
    echo -e "${BLUE}删除完成:${NC}"
    echo "  成功: $success"
    echo "  失败: $failed"
}

# 清理空闲的 Consumer Groups
clean_empty_groups() {
    local force=${1:-false}
    
    echo -e "${BLUE}📋 查找空闲的 Consumer Groups...${NC}"
    local groups=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --list \
        --bootstrap-server $BOOTSTRAP_SERVER 2>/dev/null)
    
    if [ -z "$groups" ]; then
        echo -e "${YELLOW}⚠️  没有找到任何 Consumer Group${NC}"
        return 0
    fi
    
    local empty_groups=()
    
    for group in $groups; do
        local members=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --describe \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --group "$group" \
            --state 2>/dev/null | tail -n 1 | awk '{print $NF}')
        
        # 检查是否为 0 个消费者
        if [[ "$members" =~ ^[0-9]+$ ]] && [ "$members" -eq 0 ]; then
            empty_groups+=("$group")
        fi
    done
    
    if [ ${#empty_groups[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ 没有找到空闲的 Consumer Group${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}找到 ${#empty_groups[@]} 个空闲的 Consumer Group:${NC}"
    for g in "${empty_groups[@]}"; do
        echo "  - $g"
    done
    echo ""
    
    # 确认删除
    if [ "$force" != "--force" ]; then
        if ! confirm_action "确认删除这些空闲的 Consumer Group？"; then
            echo -e "${BLUE}ℹ️  已取消删除${NC}"
            return 0
        fi
    fi
    
    # 逐个删除
    echo ""
    echo -e "${BLUE}开始清理...${NC}"
    local success=0
    local failed=0
    
    for group in "${empty_groups[@]}"; do
        echo -n "删除 $group... "
        if docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --delete \
            --bootstrap-server $BOOTSTRAP_SERVER \
            --group "$group" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            ((success++))
        else
            echo -e "${RED}✗${NC}"
            ((failed++))
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ 清理完成:${NC}"
    echo "  成功: $success"
    echo "  失败: $failed"
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
            delete_topic "$@"
            ;;
        group)
            delete_group "$@"
            ;;
        topics)
            delete_all_topics "$@"
            ;;
        groups)
            delete_all_groups "$@"
            ;;
        clean)
            clean_empty_groups "$@"
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

