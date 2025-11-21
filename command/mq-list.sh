#!/bin/bash
# RabbitMQ 队列查看脚本

echo "========================================="
echo "RabbitMQ 队列列表"
echo "========================================="
echo ""

# 获取 vhost
VHOST=${1:-cw_platform_test}

echo "VHost: $VHOST"
echo ""

# 列出队列
docker exec rabbitmq_01 rabbitmqctl list_queues \
  -p "$VHOST" \
  name messages messages_ready messages_unacknowledged consumers \
  --formatter pretty_table

echo ""
echo "========================================="
echo "使用方法: $0 [vhost]"
echo "示例: $0 cw_platform_test"
echo "========================================="