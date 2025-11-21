# 管理脚本使用说明

这个目录包含了用于管理 Docker Compose 服务的常用脚本。

## 脚本列表

### 1. mq-list.sh - RabbitMQ 队列查看

查看 RabbitMQ 的队列信息。

**使用方法:**
```bash
# 查看默认 vhost 的队列
./mq-list.sh

# 查看指定 vhost 的队列
./mq-list.sh cw_platform_test

# 查看 / vhost 的队列
./mq-list.sh /
```

**显示信息:**
- 队列名称
- 消息总数
- 待消费消息数
- 未确认消息数
- 消费者数量

---

### 2. kafka-list.sh - Kafka 信息查看（简单版）

快速查看 Kafka 的 topics 和 consumer groups。

**使用方法:**
```bash
# 列出所有 topics 和 groups
./kafka-list.sh

# 查看指定 topic 详情
./kafka-list.sh test-topic

# 查看指定 topic 和 group 详情
./kafka-list.sh test-topic my-consumer-group
```

**显示信息:**
- 所有 Topics 列表
- 所有 Consumer Groups 列表
- 指定 Topic 的详细信息（如果提供）
- 指定 Consumer Group 的详细信息（如果提供）
- 统计信息（总数）

---

### 3. kafka-info.sh - Kafka 信息查看（增强版）

功能更强大的 Kafka 管理工具，带彩色输出。

**使用方法:**
```bash
# 查看所有信息
./kafka-info.sh
./kafka-info.sh all

# 只列出 topics
./kafka-info.sh topics

# 查看指定 topic 详情
./kafka-info.sh topic test-topic

# 只列出 consumer groups
./kafka-info.sh groups

# 查看指定 consumer group 详情
./kafka-info.sh group my-consumer-group

# 查看 consumer group 消费延迟
./kafka-info.sh lag my-consumer-group

# 查看 broker 信息
./kafka-info.sh brokers

# 显示帮助信息
./kafka-info.sh help
```

**命令说明:**

| 命令 | 说明 | 示例 |
|------|------|------|
| `topics` | 列出所有 topics | `./kafka-info.sh topics` |
| `topic <name>` | 查看指定 topic 详情 | `./kafka-info.sh topic test` |
| `groups` | 列出所有 consumer groups | `./kafka-info.sh groups` |
| `group <name>` | 查看指定 group 详情 | `./kafka-info.sh group my-group` |
| `lag <group>` | 查看 group 消费延迟 | `./kafka-info.sh lag my-group` |
| `brokers` | 查看 broker 信息 | `./kafka-info.sh brokers` |
| `all` | 查看所有信息（默认） | `./kafka-info.sh all` |
| `help` | 显示帮助信息 | `./kafka-info.sh help` |

---

## 快速对比

### RabbitMQ vs Kafka 脚本对比

| 功能 | RabbitMQ | Kafka (简单) | Kafka (增强) |
|------|----------|-------------|-------------|
| 列出队列/Topics | ✅ | ✅ | ✅ |
| 查看详情 | ✅ | ✅ | ✅ |
| 查看消费组 | ❌ | ✅ | ✅ |
| 消费延迟 | ❌ | ❌ | ✅ |
| Broker 信息 | ❌ | ❌ | ✅ |
| 彩色输出 | ❌ | ❌ | ✅ |
| 子命令模式 | ❌ | ❌ | ✅ |

### 推荐使用场景

**mq-list.sh**:
- 快速查看 RabbitMQ 队列状态
- 监控特定 vhost 的队列

**kafka-list.sh**:
- 快速查看 Kafka 概览
- 简单的信息查询
- 脚本集成

**kafka-info.sh**:
- 详细的 Kafka 集群管理
- 故障排查和监控
- 交互式查询

---

## 常见使用场景

### 场景 1: 检查 RabbitMQ 队列堆积

```bash
# 查看生产环境队列
./mq-list.sh production_vhost

# 查看是否有消息堆积
# 关注 messages_ready 列
```

### 场景 2: 检查 Kafka 消费延迟

```bash
# 方法 1: 使用增强版
./kafka-info.sh lag my-consumer-group

# 方法 2: 使用简单版
./kafka-list.sh my-topic my-consumer-group
```

### 场景 3: 查看 Kafka Topic 分区情况

```bash
./kafka-info.sh topic my-topic
# 会显示每个分区的 Leader、Replicas、ISR 等信息
```

### 场景 4: 监控脚本集成

```bash
#!/bin/bash
# 监控脚本示例

# 获取 Kafka topics 数量
TOPIC_COUNT=$(./kafka-list.sh | grep "Topics 总数" | awk '{print $3}')

# 获取 RabbitMQ 队列信息
QUEUE_INFO=$(./mq-list.sh my-vhost)

# 发送告警...
```

---

## 故障排查

### 脚本执行失败

**问题**: Permission denied

**解决方案**:
```bash
chmod +x *.sh
```

---

**问题**: Kafka 容器未运行

**解决方案**:
```bash
# 检查容器状态
docker ps | grep kafka

# 启动 Kafka
cd ../kafka
docker-compose up -d
```

---

**问题**: RabbitMQ 容器未运行

**解决方案**:
```bash
# 检查容器状态
docker ps | grep rabbitmq

# 启动 RabbitMQ
cd ../rabbitmq
docker-compose up -d
```

---

## 扩展和自定义

### 修改容器名称

如果你的容器名称不是默认的，需要修改脚本中的变量：

**kafka-list.sh / kafka-info.sh**:
```bash
KAFKA_CONTAINER="your-kafka-container-name"
```

**mq-list.sh**:
```bash
# 修改第 16 行
docker exec your-rabbitmq-container-name rabbitmqctl list_queues ...
```

### 修改默认值

**mq-list.sh**: 修改默认 vhost
```bash
VHOST=${1:-your-default-vhost}
```

---

## 相关资源

- [RabbitMQ 官方文档](https://www.rabbitmq.com/documentation.html)
- [Kafka 官方文档](https://kafka.apache.org/documentation/)
- [Docker Compose 文档](https://docs.docker.com/compose/)

---

## 贡献

欢迎添加更多实用的管理脚本到这个目录！

建议的脚本命名规范：
- `服务名-功能.sh`
- 例如：`redis-info.sh`, `mysql-backup.sh`

