# RabbitMQ Docker 配置

## 功能特性

✅ 自动配置全局重试策略  
✅ 所有队列自动继承重试配置  
✅ 自动创建死信交换机和死信队列  
✅ 支持延迟消息插件  
✅ 健康检查和资源限制  

## 快速开始

### 1. 配置环境变量（可选）

创建 `.env` 文件（或使用默认值）：

```bash
# 基础配置
RABBITMQ_VHOST=cw_platform_test
RABBITMQ_USER=admin
RABBITMQ_PASS=rabbitmq123456

# 重试策略配置
RABBITMQ_MAX_RETRIES=3              # 最大重试次数
RABBITMQ_MESSAGE_TTL=3600000        # 消息 TTL: 1小时
RABBITMQ_MAX_LENGTH=100000          # 队列最大长度
RABBITMQ_DLX_EXCHANGE=dlx.exchange  # 死信交换机
RABBITMQ_DLX_QUEUE=dlx.queue        # 死信队列
```

### 2. 启动服务

```bash
# 构建并启动
docker-compose -f rabbitmq/compose.yaml up -d --build

# 查看日志（确认初始化成功）
docker logs rabbitmq_01 | grep "初始化"
```

### 3. 验证配置

```bash
# 查看策略
docker exec rabbitmq_01 rabbitmqctl list_policies -p cw_platform_test

# 查看死信队列
docker exec rabbitmq_01 rabbitmqctl list_queues -p cw_platform_test | grep dlx

# 或使用脚本
./command/mq-list.sh detail
```

## 自动配置说明

容器启动后，会自动执行以下操作：

1. ✅ 创建 VHost（如果不存在）
2. ✅ 创建死信交换机 (`dlx.exchange`)
3. ✅ 创建死信队列 (`dlx.queue`)
4. ✅ 绑定死信队列到死信交换机
5. ✅ 创建全局策略，应用到**所有队列**

### 策略内容

所有队列（新建和现有）会自动应用：

```json
{
  "dead-letter-exchange": "dlx.exchange",
  "message-ttl": 3600000,
  "max-length": 100000
}
```

## 使用方法

### 消费者代码实现重试

```go
package main

import (
    "github.com/streadway/amqp"
    "log"
)

const MAX_RETRIES = 3  // 与环境变量 RABBITMQ_MAX_RETRIES 保持一致

func handleMessage(delivery amqp.Delivery) {
    // 获取重试次数
    retryCount := 0
    if xDeath, ok := delivery.Headers["x-death"].([]interface{}); ok {
        retryCount = len(xDeath)
    }
    
    // 处理消息
    if err := processMessage(delivery.Body); err != nil {
        if retryCount < MAX_RETRIES {
            log.Printf("处理失败，将重试 (%d/%d)", retryCount+1, MAX_RETRIES)
            delivery.Nack(false, false)  // 触发 DLX
        } else {
            log.Printf("超过最大重试次数，进入死信队列")
            delivery.Nack(false, false)
        }
    } else {
        delivery.Ack(false)
    }
}
```

## 配置参数说明

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| RABBITMQ_VHOST | cw_platform_test | VHost 名称 |
| RABBITMQ_USER | admin | 管理员用户名 |
| RABBITMQ_PASS | rabbitmq123456 | 管理员密码 |
| RABBITMQ_MAX_RETRIES | 3 | 最大重试次数（代码中使用） |
| RABBITMQ_MESSAGE_TTL | 3600000 | 消息过期时间（毫秒） |
| RABBITMQ_MAX_LENGTH | 100000 | 队列最大长度 |
| RABBITMQ_DLX_EXCHANGE | dlx.exchange | 死信交换机名称 |
| RABBITMQ_DLX_QUEUE | dlx.queue | 死信队列名称 |

## 修改配置

### 方式 1：通过环境变量（推荐）

```bash
# 创建 .env 文件
cat > rabbitmq/.env <<EOF
RABBITMQ_MAX_RETRIES=5
RABBITMQ_MESSAGE_TTL=7200000
RABBITMQ_MAX_LENGTH=200000
EOF

# 重新构建并启动
docker-compose -f rabbitmq/compose.yaml up -d --build
```

### 方式 2：直接修改 compose.yaml

修改 `compose.yaml` 中的默认值：

```yaml
environment:
  - RABBITMQ_MAX_RETRIES=${RABBITMQ_MAX_RETRIES:-5}      # 改为 5
  - RABBITMQ_MESSAGE_TTL=${RABBITMQ_MESSAGE_TTL:-7200000} # 改为 2小时
```

### 方式 3：运行时配置

容器启动后，手动修改策略：

```bash
docker exec rabbitmq_01 rabbitmqctl set_policy \
  -p cw_platform_test \
  "auto-retry-policy" \
  ".*" \
  '{"dead-letter-exchange":"dlx.exchange","message-ttl":7200000}' \
  --priority 1 \
  --apply-to queues
```

## 管理工具

### Web 管理界面

访问：http://localhost:15672  
用户名：admin  
密码：rabbitmq123456

### 命令行工具

```bash
# 查看队列详情（含重试配置）
./command/mq-list.sh detail

# 查看策略
./command/mq-policy.sh list

# 查看死信队列
./command/mq-list.sh | grep dlx

# 查看统计信息
./command/mq-list.sh stats
```

## 重试机制工作原理

```
消息 ──> 业务队列 ──处理失败──> Nack(requeue=false)
                                   │
                                   ↓
                              死信交换机(DLX)
                                   │
                                   ↓
              ┌────────────────────┴─────────────────┐
              │                                      │
         重试次数 < 3                            重试次数 >= 3
              │                                      │
              ↓                                      ↓
        重新进入业务队列                         留在死信队列
        (x-death 计数+1)                         (人工处理)
```

## 常见问题

### Q: 如何查看当前策略是否生效？

```bash
./command/mq-list.sh detail
```

### Q: 如何处理死信队列中的消息？

1. 查看死信队列
2. 分析失败原因
3. 修复问题后，手动重新发送或删除

### Q: 能否针对特定队列设置不同的重试次数？

可以，创建更高优先级的策略：

```bash
docker exec rabbitmq_01 rabbitmqctl set_policy \
  -p cw_platform_test \
  "special-queue-policy" \
  "^special\\..*" \
  '{"dead-letter-exchange":"dlx.exchange","message-ttl":1800000}' \
  --priority 10 \
  --apply-to queues
```

### Q: 修改配置后是否影响现有队列？

是的，策略会立即应用到所有匹配的队列（包括现有队列）。

## 文件结构

```
rabbitmq/
├── compose.yaml              # Docker Compose 配置
├── Dockerfile                # Docker 镜像构建
├── README.md                 # 本文件
├── .env.example              # 环境变量示例
├── init/
│   └── init-policy.sh        # 自动初始化脚本
└── etc/
    └── rabbitmq.conf         # RabbitMQ 配置文件
```

## 参考资料

- [RabbitMQ 死信交换机](https://www.rabbitmq.com/dlx.html)
- [RabbitMQ Policies](https://www.rabbitmq.com/parameters.html#policies)
- [消息 TTL](https://www.rabbitmq.com/ttl.html)
