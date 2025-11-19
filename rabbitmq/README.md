# RabbitMQ Docker Compose 配置

## 🔒 安全验证

### 自动验证（推荐）

```bash
./verify-security.sh
```

### 手动验证

```bash
# 构建镜像
docker build --no-cache -t rabbitmq-secure:test .

# 使用 Trivy 扫描（推荐）
trivy image --severity HIGH,CRITICAL rabbitmq-secure:test

# 或使用 Docker Scout
docker scout cves rabbitmq-secure:test

# 或使用 Grype
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype rabbitmq-secure:test
```

## 快速开始

### 1. 创建环境变量文件

创建 `.env` 文件并配置以下变量：

```bash
# RabbitMQ 虚拟主机
RABBITMQ_VHOST=etranslate

# RabbitMQ 管理员账号
RABBITMQ_USER=admin

# RabbitMQ 管理员密码（生产环境请使用强密码）
RABBITMQ_PASS=your_strong_password_here
```

### 2. 启动服务

```bash
docker-compose -f compose.yaml up -d
```

### 3. 查看服务状态

```bash
# 查看容器状态
docker-compose -f compose.yaml ps

# 查看容器日志
docker-compose -f compose.yaml logs -f rabbitmq

# 检查健康状态
docker inspect --format='{{.State.Health.Status}}' rabbitmq_01
```

### 4. 访问管理界面

打开浏览器访问：`http://localhost:15672`

- 默认用户名：在 `.env` 文件中配置的 `RABBITMQ_USER`
- 默认密码：在 `.env` 文件中配置的 `RABBITMQ_PASS`

## 配置说明

### 版本信息

- RabbitMQ: 3.13.7-management-alpine
- Docker Compose: 3.8
- 基础镜像: Alpine Linux (安全、轻量)
- 已启用插件：
  - rabbitmq_management（管理界面）
  - rabbitmq_delayed_message_exchange（延迟消息）

### 端口映射

| 容器端口 | 主机端口 | 说明 |
|---------|---------|------|
| 4369 | 4369 | Erlang 端口映射守护进程 |
| 5671 | 5671 | AMQP over TLS |
| 5672 | 5672 | AMQP 标准端口 |
| 15671 | 15671 | 管理界面 HTTPS |
| 15672 | 15672 | 管理界面 HTTP |
| 25672 | 25672 | Erlang 节点间通信 |

### 数据持久化

- **数据文件**: `../datas/rabbitmq/lib` -> `/var/lib/rabbitmq`
- **配置文件**: `./etc` -> `/etc/rabbitmq`
- **日志文件**: `../logs/rabbitmq` -> `/var/log/rabbitmq`

### 性能配置

- **内存高水位标记**: 60% (RABBITMQ_VM_MEMORY_HIGH_WATERMARK=0.6)
- **磁盘最小空闲空间**: 2GB (RABBITMQ_DISK_FREE_LIMIT=2GB)

### 资源限制

- **CPU 限制**: 2 核
- **内存限制**: 2GB
- **CPU 预留**: 0.5 核
- **内存预留**: 512MB

> 注意：可根据实际服务器资源调整这些值

### 健康检查

- **检查间隔**: 30秒
- **超时时间**: 10秒
- **重试次数**: 3次
- **启动等待**: 40秒

## 常用命令

### 重启服务

```bash
docker-compose -f compose.yaml restart
```

### 停止服务

```bash
docker-compose -f compose.yaml stop
```

### 删除服务（保留数据）

```bash
docker-compose -f compose.yaml down
```

### 删除服务（包括数据卷）

```bash
docker-compose -f compose.yaml down -v
```

### 重新构建镜像

```bash
docker-compose -f compose.yaml build --no-cache
docker-compose -f compose.yaml up -d
```

### 查看 RabbitMQ 状态

```bash
# 进入容器
docker exec -it rabbitmq_01 bash

# 查看集群状态
rabbitmq-diagnostics cluster_status

# 查看节点状态
rabbitmqctl status

# 查看队列列表
rabbitmqctl list_queues

# 查看交换机列表
rabbitmqctl list_exchanges

# 查看绑定关系
rabbitmqctl list_bindings
```

## 故障排查

### 1. 容器无法启动

检查数据目录权限：

```bash
# 确保目录存在
mkdir -p ../datas/rabbitmq/lib ../logs/rabbitmq

# 如果有权限问题，可以尝试
sudo chown -R 999:999 ../datas/rabbitmq/lib ../logs/rabbitmq
```

### 2. 无法访问管理界面

- 检查容器是否正常运行：`docker ps`
- 检查端口是否被占用：`netstat -tuln | grep 15672`
- 查看容器日志：`docker logs rabbitmq_01`

### 3. 内存不足警告

调整 `compose.yaml` 中的内存限制或调整内存高水位标记：

```yaml
environment:
  - RABBITMQ_VM_MEMORY_HIGH_WATERMARK=0.4  # 降低到40%
```

## 安全建议

1. **修改默认密码**：请务必在 `.env` 文件中设置强密码
2. **限制访问**：生产环境建议配置防火墙规则，仅允许必要的 IP 访问
3. **使用 TLS**：生产环境建议启用 TLS 加密通信
4. **定期备份**：定期备份 `datas/rabbitmq/lib` 目录

## 生产环境增强

### 启用 Prometheus 监控

取消 `compose.yaml` 中的注释：

```yaml
ports:
  - "15692:15692" # Prometheus metrics
```

### 配置集群

如需配置集群，请参考 RabbitMQ 官方文档：
https://www.rabbitmq.com/clustering.html

## 相关链接

- [RabbitMQ 官方文档](https://www.rabbitmq.com/documentation.html)
- [RabbitMQ 管理插件](https://www.rabbitmq.com/management.html)
- [延迟消息插件](https://github.com/rabbitmq/rabbitmq-delayed-message-exchange)
