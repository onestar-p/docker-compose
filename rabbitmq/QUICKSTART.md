# RabbitMQ 快速开始指南

## 📋 功能说明

修改后的 RabbitMQ 配置支持：

✅ **自动配置全局重试策略** - 所有队列自动继承  
✅ **自定义重试次数** - 通过环境变量配置  
✅ **自动创建死信队列** - 存储失败消息  
✅ **零配置启动** - 使用默认值即可运行  

## 🚀 快速启动（使用默认配置）

```bash
# 直接启动（使用默认配置）
docker-compose -f rabbitmq/compose.yaml up -d --build

# 查看日志，确认初始化成功
docker logs rabbitmq_01 | grep "初始化完成"
```

**默认配置：**
- 最大重试次数：3
- 消息 TTL：1小时
- 队列最大长度：100000

## ⚙️ 自定义配置

### 步骤 1：创建环境变量文件

```bash
# 复制示例文件
cp rabbitmq/env.example rabbitmq/.env

# 编辑配置
vi rabbitmq/.env
```

### 步骤 2：修改配置参数

```bash
# rabbitmq/.env
RABBITMQ_MAX_RETRIES=5          # 改为 5 次重试
RABBITMQ_MESSAGE_TTL=7200000    # 改为 2 小时
RABBITMQ_MAX_LENGTH=200000      # 改为 20 万条
```

### 步骤 3：重新启动

```bash
docker-compose -f rabbitmq/compose.yaml up -d --build
```

## ✅ 验证配置

```bash
# 方式 1：使用脚本
./command/mq-list.sh detail

# 方式 2：直接查看策略
docker exec rabbitmq_01 rabbitmqctl list_policies -p cw_platform_test

# 方式 3：检查队列配置
docker exec rabbitmq_01 rabbitmqctl list_queues \
  -p cw_platform_test \
  name arguments \
  --formatter json | grep -A 5 "dead-letter"
```

**预期输出：**
```
消息 TTL (x-message-ttl): 3600000ms
死信交换机 (x-dead-letter-exchange): dlx.exchange
队列最大长度 (x-max-length): 100000
```

## 📝 消费者代码示例

```go
package main

import (
    "github.com/streadway/amqp"
    "log"
)

// 从环境变量读取（与 compose.yaml 保持一致）
const MAX_RETRIES = 3

func handleMessage(delivery amqp.Delivery) {
    // 获取重试次数
    retryCount := 0
    if xDeath, ok := delivery.Headers["x-death"].([]interface{}); ok {
        retryCount = len(xDeath)
    }
    
    log.Printf("处理消息，重试次数: %d/%d", retryCount, MAX_RETRIES)
    
    // 处理业务逻辑
    if err := processMessage(delivery.Body); err != nil {
        if retryCount < MAX_RETRIES {
            // 重试
            log.Printf("处理失败，将重试")
            delivery.Nack(false, false)
        } else {
            // 超过最大次数
            log.Printf("超过最大重试次数，进入死信队列")
            delivery.Nack(false, false)
        }
    } else {
        // 成功
        delivery.Ack(false)
    }
}
```

## 🔍 查看死信队列

```bash
# 查看死信队列消息数量
docker exec rabbitmq_01 rabbitmqctl list_queues \
  -p cw_platform_test \
  name messages | grep dlx

# 或使用管理界面
# 访问 http://localhost:15672
# 登录后查看 dlx.queue
```

## 🛠️ 常用命令

```bash
# 查看所有队列
./command/mq-list.sh

# 查看队列详情（含重试配置）
./command/mq-list.sh detail

# 查看统计信息
./command/mq-list.sh stats

# 查看策略
./command/mq-policy.sh list

# 查看日志
docker logs -f rabbitmq_01
```

## 📊 配置参数说明

| 参数 | 默认值 | 说明 | 推荐值 |
|------|--------|------|--------|
| MAX_RETRIES | 3 | 最大重试次数 | 3-5 |
| MESSAGE_TTL | 3600000 | 消息过期时间(ms) | 1小时-24小时 |
| MAX_LENGTH | 100000 | 队列最大长度 | 根据业务调整 |

**时间换算：**
- 30秒 = 30000
- 1分钟 = 60000
- 5分钟 = 300000
- 1小时 = 3600000
- 24小时 = 86400000

## ⚠️ 注意事项

1. **修改配置后需要重新构建镜像**
   ```bash
   docker-compose -f rabbitmq/compose.yaml up -d --build
   ```

2. **策略会应用到所有队列**（包括现有队列）

3. **重试次数在消费者代码中实现**（检查 x-death header）

4. **定期检查死信队列**，及时处理失败消息

## 🎯 工作流程

```
1. 创建队列
   ↓
2. 自动应用策略（dead-letter-exchange、message-ttl、max-length）
   ↓
3. 消费者处理消息
   ↓
4. 处理失败 → Nack(false, false)
   ↓
5. 消息发送到死信交换机
   ↓
6. 检查 x-death 计数
   ↓
   ├── < MAX_RETRIES → 重新进入队列
   └── >= MAX_RETRIES → 留在死信队列
```

## 📚 更多信息

详细文档请参考：`rabbitmq/README.md`

## 🆘 故障排查

### 策略未生效

```bash
# 检查策略是否创建
docker exec rabbitmq_01 rabbitmqctl list_policies -p cw_platform_test

# 检查初始化日志
docker logs rabbitmq_01 | grep "策略"
```

### 死信队列未创建

```bash
# 手动执行初始化脚本
docker exec rabbitmq_01 /usr/local/bin/init-policy.sh
```

### 消息没有重试

检查消费者代码是否：
1. 使用了 `Nack(false, false)` 而不是 `Nack(false, true)`
2. 正确读取了 x-death header
3. MAX_RETRIES 值与环境变量一致

## ✨ 完成

现在你的 RabbitMQ 已经配置好全局重试策略了！所有队列都会自动继承配置。

