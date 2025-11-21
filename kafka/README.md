# Kafka Docker Compose 配置

## 快速开始

### 1. 创建环境变量文件（可选）

```bash
cp .env.example .env
# 编辑 .env 修改密码
```

### 2. 启动服务

```bash
docker-compose -f compose.yaml up -d
```

### 3. 查看服务状态

```bash
# 查看所有服务状态
docker-compose -f compose.yaml ps

# 查看日志
docker-compose -f compose.yaml logs -f

# 查看特定服务日志
docker logs -f kafka
docker logs -f zookeeper
docker logs -f kafka-ui
```

### 4. 访问 Kafka UI

打开浏览器访问：`http://localhost:8080`

- 默认用户名：`admin`
- 默认密码：`admin123456`（建议在 `.env` 中修改）

## 配置说明

### 版本信息

- ZooKeeper: 7.3.2
- Kafka: 7.3.2
- Kafka UI: latest

### 端口映射

| 服务 | 容器端口 | 主机端口 | 说明 |
|------|---------|---------|------|
| ZooKeeper | 2181 | 2181 | ZooKeeper 客户端端口 |
| Kafka | 9092 | 9092 | Kafka 内部通信端口 |
| Kafka | 9093 | 9093 | Kafka 外部访问端口 |
| Kafka UI | 8080 | 8080 | Web 管理界面 |

### 数据持久化

- **ZooKeeper 数据**: `../datas/zookeeper/data`
- **ZooKeeper 日志**: `../datas/zookeeper/log`
- **Kafka 数据**: `../datas/kafka/data`
- **日志文件**: `../logs/zookeeper`、`../logs/kafka`

### 性能配置

**ZooKeeper**:
- 堆内存: 512MB

**Kafka**:
- 堆内存: 1GB
- 日志保留时间: 168 小时（7 天）
- 日志段大小: 1GB
- 副本因子: 1（单节点）

### 资源限制

**开发环境配置**:

| 服务 | CPU 限制 | 内存限制 | CPU 预留 | 内存预留 |
|------|---------|---------|---------|---------|
| ZooKeeper | 1.0 | 1GB | 0.25 | 512MB |
| Kafka | 2.0 | 2GB | 0.5 | 1GB |
| Kafka UI | 1.0 | 1GB | 0.25 | 256MB |

## 常用命令

### Kafka 主题管理

```bash
# 创建主题
docker exec kafka kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --partitions 3 \
  --replication-factor 1

# 列出所有主题
docker exec kafka kafka-topics --list \
  --bootstrap-server localhost:9092

# 查看主题详情
docker exec kafka kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --topic test-topic

# 删除主题
docker exec kafka kafka-topics --delete \
  --bootstrap-server localhost:9092 \
  --topic test-topic
```

### 生产和消费消息

```bash
# 生产消息（交互式）
docker exec -it kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic test-topic

# 消费消息（从最新开始）
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --from-beginning

# 消费消息（指定消费组）
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --group test-group \
  --from-beginning
```

### 消费组管理

```bash
# 列出所有消费组
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --list

# 查看消费组详情
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group test-group \
  --describe

# 重置消费组偏移量
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group test-group \
  --topic test-topic \
  --reset-offsets \
  --to-earliest \
  --execute
```

### 性能测试

```bash
# 生产者性能测试
docker exec kafka kafka-producer-perf-test \
  --topic test-topic \
  --num-records 1000000 \
  --record-size 1024 \
  --throughput -1 \
  --producer-props bootstrap.servers=localhost:9092

# 消费者性能测试
docker exec kafka kafka-consumer-perf-test \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --messages 1000000 \
  --threads 1
```

### 服务管理

```bash
# 重启服务
docker-compose -f compose.yaml restart

# 停止服务
docker-compose -f compose.yaml stop

# 停止并删除服务
docker-compose -f compose.yaml down

# 停止并删除服务及数据卷
docker-compose -f compose.yaml down -v
```

## 连接配置

### 应用程序连接

**内部连接（Docker 网络内）**:
```properties
bootstrap.servers=kafka:9092
```

**外部连接（宿主机或其他机器）**:
```properties
bootstrap.servers=localhost:9093
```

### 各语言示例

**Java (Spring Boot)**:
```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9093
    consumer:
      group-id: my-group
```

**Go**:
```go
config := sarama.NewConfig()
brokers := []string{"localhost:9093"}
producer, err := sarama.NewSyncProducer(brokers, config)
```

**Python**:
```python
from kafka import KafkaProducer

producer = KafkaProducer(bootstrap_servers=['localhost:9093'])
```

## 故障排查

### 1. Kafka 无法启动

检查 ZooKeeper 是否健康：
```bash
docker logs zookeeper
docker exec zookeeper nc -z localhost 2181
```

### 2. 无法连接到 Kafka

检查监听地址配置：
```bash
# 查看 Kafka 配置
docker exec kafka cat /etc/kafka/server.properties | grep listeners

# 测试连接
telnet localhost 9092
telnet localhost 9093
```

### 3. 权限问题

如果遇到权限错误，修复数据目录权限：
```bash
sudo chown -R 1000:1000 ../datas/kafka
sudo chown -R 1000:1000 ../datas/zookeeper
sudo chown -R 1000:1000 ../logs/kafka
sudo chown -R 1000:1000 ../logs/zookeeper
```

### 4. Kafka UI 无法访问

检查 Kafka UI 状态：
```bash
docker logs kafka-ui
curl http://localhost:8080/actuator/health
```

## 生产环境建议

### 1. 集群部署

对于生产环境，建议部署 Kafka 集群（至少 3 个节点）：

```yaml
# 修改副本因子
KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
```

### 2. 监控

集成 Prometheus 和 Grafana：
- 启用 JMX Exporter
- 收集 Kafka 指标
- 设置告警规则

### 3. 安全加固

- 启用 SASL/SSL 认证
- 配置 ACL 访问控制
- 使用强密码
- 限制网络访问

### 4. 备份策略

- 定期备份 ZooKeeper 数据
- 配置 Kafka 镜像（MirrorMaker）
- 实施灾难恢复计划

## 迁移到 KRaft 模式

Kafka 3.0+ 支持 KRaft 模式（无需 ZooKeeper），如需迁移：

1. 停止当前服务
2. 修改配置文件使用 KRaft 模式
3. 初始化 KRaft 元数据
4. 重新启动服务

详细步骤参考官方文档：https://kafka.apache.org/documentation/#kraft

## 参考资源

- [Kafka 官方文档](https://kafka.apache.org/documentation/)
- [Confluent 文档](https://docs.confluent.io/)
- [Kafka UI 文档](https://docs.kafka-ui.provectus.io/)
