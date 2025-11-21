# Kafka 创建脚本使用示例

## 📝 快速入门

### 1. 创建第一个 Topic

```bash
# 使用默认配置创建 topic（3 分区，1 副本）
./kafka-create.sh topic my-first-topic
```

### 2. 测试生产和消费消息

```bash
# 生产消息（在第一个终端）
docker exec -it kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic my-first-topic

# 输入一些消息：
> Hello Kafka!
> This is a test message
> 按 Ctrl+C 退出

# 消费消息（在第二个终端）
./kafka-create.sh group my-first-topic test-group
```

---

## 💼 实际业务场景示例

### 场景 1: 订单处理系统

```bash
# 订单创建事件（高并发，5 个分区）
./kafka-create.sh topic order-created -p 5 -r 1

# 订单支付事件
./kafka-create.sh topic order-paid -p 5 -r 1

# 订单发货事件
./kafka-create.sh topic order-shipped -p 3 -r 1

# 创建订单处理服务的 consumer group
./kafka-create.sh group order-created order-processing-service
```

### 场景 2: 日志收集系统

```bash
# 应用日志（大数据量，10 个分区，保留 3 天）
./kafka-create.sh topic app-logs \
  -p 10 \
  -r 1 \
  -c retention.ms=259200000 \
  -c compression.type=lz4

# 错误日志（保留 7 天）
./kafka-create.sh topic error-logs \
  -p 3 \
  -r 1 \
  -c retention.ms=604800000

# 审计日志（保留 30 天）
./kafka-create.sh topic audit-logs \
  -p 5 \
  -r 1 \
  -c retention.ms=2592000000
```

### 场景 3: 微服务事件总线

```bash
# 用户服务事件
./kafka-create.sh topic user-events -p 3 -r 1

# 商品服务事件
./kafka-create.sh topic product-events -p 5 -r 1

# 库存服务事件
./kafka-create.sh topic inventory-events -p 3 -r 1

# 通知服务订阅所有事件
./kafka-create.sh group user-events notification-service
./kafka-create.sh group product-events notification-service
./kafka-create.sh group inventory-events notification-service
```

### 场景 4: 实时数据分析

```bash
# 用户行为数据（大数据量，启用压缩）
./kafka-create.sh topic user-behavior \
  -p 20 \
  -r 1 \
  -c compression.type=snappy \
  -c retention.ms=86400000

# 点击流数据
./kafka-create.sh topic clickstream \
  -p 15 \
  -r 1 \
  -c compression.type=lz4

# 实时指标数据（短期保留）
./kafka-create.sh topic realtime-metrics \
  -p 10 \
  -r 1 \
  -c retention.ms=3600000
```

### 场景 5: 消息队列

```bash
# 邮件发送队列
./kafka-create.sh topic email-queue \
  -p 3 \
  -r 1 \
  -c max.message.bytes=10485760

# 短信发送队列
./kafka-create.sh topic sms-queue -p 3 -r 1

# 推送通知队列
./kafka-create.sh topic push-notification-queue -p 5 -r 1
```

---

## 🔧 高级配置示例

### 1. 大消息 Topic

```bash
# 允许 10MB 大小的消息
./kafka-create.sh topic large-files \
  -p 3 \
  -r 1 \
  -c max.message.bytes=10485760 \
  -c segment.bytes=1073741824
```

### 2. 高吞吐量 Topic

```bash
# 优化吞吐量配置
./kafka-create.sh topic high-throughput \
  -p 20 \
  -r 1 \
  -c compression.type=lz4 \
  -c batch.size=32768 \
  -c linger.ms=10
```

### 3. 低延迟 Topic

```bash
# 优化延迟配置
./kafka-create.sh topic low-latency \
  -p 5 \
  -r 1 \
  -c min.insync.replicas=1 \
  -c unclean.leader.election.enable=false
```

### 4. 日志压缩 Topic（保留最新状态）

```bash
# 用户状态（只保留每个用户的最新状态）
./kafka-create.sh topic user-state \
  -p 10 \
  -r 1 \
  -c cleanup.policy=compact \
  -c delete.retention.ms=86400000
```

### 5. 多配置组合

```bash
# 订单快照：压缩 + 长期保留 + 大消息
./kafka-create.sh topic order-snapshot \
  -p 5 \
  -r 1 \
  -c cleanup.policy=compact \
  -c retention.ms=31536000000 \
  -c max.message.bytes=5242880 \
  -c compression.type=gzip
```

---

## 📊 测试和验证

### 完整的测试流程

```bash
# 1. 创建 topic
./kafka-create.sh topic test-flow -p 3 -r 1

# 2. 查看 topic 详情
./kafka-info.sh topic test-flow

# 3. 生产测试消息
docker exec -it kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic test-flow \
  --property "parse.key=true" \
  --property "key.separator=:"

# 输入带 key 的消息
key1:message1
key2:message2
key3:message3

# 4. 启动多个 consumer group 测试
# 终端 1
./kafka-create.sh group test-flow consumer-group-1

# 终端 2
./kafka-create.sh group test-flow consumer-group-2

# 5. 查看 consumer group 状态
./kafka-info.sh group consumer-group-1
./kafka-info.sh group consumer-group-2

# 6. 查看消费延迟
./kafka-info.sh lag consumer-group-1
```

---

## 🧹 清理资源

### 删除测试资源

```bash
# 删除 topic
./kafka-create.sh delete-topic test-flow

# 删除 consumer groups
./kafka-create.sh delete-group consumer-group-1
./kafka-create.sh delete-group consumer-group-2
```

### 批量删除

```bash
#!/bin/bash
# 批量删除测试 topics

for topic in test-topic-1 test-topic-2 test-topic-3; do
    ./kafka-create.sh delete-topic $topic
done
```

---

## 💡 最佳实践

### Topic 命名规范

```bash
# 好的命名
./kafka-create.sh topic order.created      # 使用点号分隔
./kafka-create.sh topic user-registered    # 使用连字符
./kafka-create.sh topic product_updated    # 使用下划线

# 不推荐
./kafka-create.sh topic OrderCreated       # 大写字母
./kafka-create.sh topic order created      # 空格
```

### 分区数量选择

```bash
# 低流量（< 1MB/s）
./kafka-create.sh topic low-traffic -p 1 -r 1

# 中等流量（1-10 MB/s）
./kafka-create.sh topic medium-traffic -p 3 -r 1

# 高流量（10-100 MB/s）
./kafka-create.sh topic high-traffic -p 10 -r 1

# 超高流量（> 100 MB/s）
./kafka-create.sh topic very-high-traffic -p 30 -r 1
```

### 数据保留时间

```bash
# 实时数据（1 小时）
-c retention.ms=3600000

# 短期数据（1 天）
-c retention.ms=86400000

# 中期数据（7 天）
-c retention.ms=604800000

# 长期数据（30 天）
-c retention.ms=2592000000

# 永久保留（使用压缩）
-c cleanup.policy=compact
```

---

## 🐛 故障排查

### Topic 创建失败

```bash
# 查看 Kafka 日志
docker logs kafka

# 检查 Kafka 连接
docker exec kafka kafka-broker-api-versions \
  --bootstrap-server localhost:9092

# 检查现有 topics
./kafka-list.sh
```

### Consumer Group 问题

```bash
# 查看 consumer group 状态
./kafka-info.sh group my-group

# 重置 consumer group offset
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group my-group \
  --reset-offsets \
  --to-earliest \
  --topic my-topic \
  --execute
```

---

## 🔗 相关命令

```bash
# 查看所有 topics
./kafka-list.sh

# 查看详细信息
./kafka-info.sh

# 创建和管理
./kafka-create.sh

# 查看 RabbitMQ
./mq-list.sh
```

---

## 📚 参考资源

- [Kafka 官方文档](https://kafka.apache.org/documentation/)
- [Topic 配置参考](https://kafka.apache.org/documentation/#topicconfigs)
- [Consumer Group 文档](https://kafka.apache.org/documentation/#consumerapi)

