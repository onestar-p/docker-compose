# Kafka + Zookeeper + Kafka UI

## 快速启动

```bash
cd kafka
docker compose up -d
```

## 停止服务

```bash
docker compose down
```

## 服务说明

### 端口配置

| 服务 | 端口 | 说明 |
|------|------|------|
| Zookeeper | 2181 | Zookeeper 客户端端口 |
| Kafka | 9092 | Kafka Broker 端口 |
| Kafka UI | 8080 | Kafka 管理界面 |

### 默认账户（Kafka UI）

- **用户名**: `admin`
- **密码**: `admin123456`

⚠️ **生产环境请务必修改默认密码！**

## 访问 Kafka UI

1. 浏览器访问: `http://localhost:8080`
2. 使用上述账户登录
3. 可以查看 Topics、消费者组、消息等

## 连接 Kafka

### 应用程序连接

```properties
# Bootstrap Servers
bootstrap.servers=localhost:9092

# 当前配置无需认证
# 如果后续添加了 SASL 认证，需要配置相应的认证信息
```

### 使用 Kafka 命令行工具

```bash
# 进入 Kafka 容器
docker exec -it kafka bash

# 创建 Topic
kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --partitions 3 \
  --replication-factor 1

# 列出所有 Topic
kafka-topics --list \
  --bootstrap-server localhost:9092

# 发送消息
kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic test-topic

# 消费消息
kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic test-topic \
  --from-beginning
```

## 数据持久化

- Kafka 数据: `../datas/kafka/`
- Zookeeper 数据: `../datas/zookeeper/`

## 配置说明

### Kafka 配置

- **Broker ID**: 1
- **自动创建 Topic**: 启用
- **副本因子**: 1（单节点）
- **内存配置**: 1GB

### Zookeeper 配置

- **客户端端口**: 2181
- **Tick Time**: 2000ms
- **内存配置**: 512MB

## 安全配置

### 当前安全状态

- ✅ **Kafka UI**: 已启用登录认证
- ⚠️ **Kafka Broker**: 无认证（PLAINTEXT 协议）
- ⚠️ **Zookeeper**: 无认证

### 修改 Kafka UI 密码

编辑 `compose.yaml`：

```yaml
environment:
  SPRING_SECURITY_USER_NAME: your_username
  SPRING_SECURITY_USER_PASSWORD: your_strong_password
```

重启服务：

```bash
docker compose down
docker compose up -d
```

### 禁用 Kafka UI 认证（仅限开发环境）

如果在完全隔离的本地开发环境，可以禁用认证：

编辑 `compose.yaml`，删除或注释以下行：

```yaml
# AUTH_TYPE: "LOGIN_FORM"
# SPRING_SECURITY_USER_NAME: admin
# SPRING_SECURITY_USER_PASSWORD: admin123456
```

## 监控和管理

### 查看 Kafka 日志

```bash
# 查看 Kafka 日志
docker logs -f kafka

# 查看 Zookeeper 日志
docker logs -f zookeeper

# 查看 Kafka UI 日志
docker logs -f kafka-ui
```

### 检查服务健康状态

```bash
# 检查 Kafka 是否正常
docker exec -it kafka kafka-broker-api-versions --bootstrap-server localhost:9092

# 检查 Zookeeper 是否正常
echo stat | nc localhost 2181
```

## 常见问题

### 1. 无法连接到 Kafka

**检查项：**
- 确保 Kafka 和 Zookeeper 都已启动
- 检查端口 9092 是否被占用
- 查看容器日志排查错误

```bash
docker compose ps
docker logs kafka
```

### 2. Kafka UI 无法访问

**检查项：**
- 确保 Kafka 启动成功（Kafka UI 依赖 Kafka）
- 检查端口 8080 是否被占用
- 检查用户名密码是否正确

### 3. Topic 创建失败

**可能原因：**
- Kafka 未完全启动（等待 30 秒后重试）
- 磁盘空间不足
- 配置参数错误

### 4. 忘记 Kafka UI 密码

重新编辑 `compose.yaml` 修改密码后重启：

```bash
docker compose down
docker compose up -d
```

## 性能优化

### 调整内存配置

编辑 `compose.yaml`：

```yaml
kafka:
  environment:
    # 根据服务器配置调整堆内存
    KAFKA_HEAP_OPTS: "-Xmx2G -Xms2G"  # 改为 2GB

zookeeper:
  environment:
    ZOOKEEPER_HEAP_OPTS: "-Xmx1G -Xms1G"  # 改为 1GB
```

### 调整分区和副本

```bash
# 创建 Topic 时指定更多分区
kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic high-throughput-topic \
  --partitions 10 \
  --replication-factor 1
```

## 生产环境建议

⚠️ **当前配置仅适合开发和测试环境！**

**生产环境需要：**

1. ✅ **启用 Kafka SASL 认证**
2. ✅ **启用 TLS/SSL 加密**
3. ✅ **配置多个 Broker（高可用）**
4. ✅ **配置多个 Zookeeper 节点（集群）**
5. ✅ **修改默认密码**
6. ✅ **限制网络访问（防火墙）**
7. ✅ **配置监控和告警**
8. ✅ **定期备份数据**

## 参考资源

- [Kafka 官方文档](https://kafka.apache.org/documentation/)
- [Kafka UI 文档](https://docs.kafka-ui.provectus.io/)
- [Confluent Platform 文档](https://docs.confluent.io/)

## 故障排查

### 查看容器状态

```bash
docker compose ps
```

### 查看资源使用

```bash
docker stats kafka zookeeper kafka-ui
```

### 重置 Kafka 数据（清空所有消息）

⚠️ **注意：此操作会删除所有数据！**

```bash
docker compose down -v
rm -rf ../datas/kafka/* ../datas/zookeeper/*
docker compose up -d
```

