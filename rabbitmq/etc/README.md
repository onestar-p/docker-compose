# RabbitMQ 配置文件目录

## 文件说明

### rabbitmq.conf
主配置文件，使用新格式（RabbitMQ 3.7+）。包含：
- 内存管理
- 磁盘管理  
- 网络和连接
- 日志配置
- 性能优化

### enabled_plugins
启用的插件列表，格式为 Erlang 列表语法。

已启用插件：
- `rabbitmq_management` - 管理界面
- `rabbitmq_delayed_message_exchange` - 延迟消息插件

## 配置修改方法

### 1. 修改配置文件

编辑 `rabbitmq.conf`:

```bash
# 例如：修改内存高水位
vm_memory_high_watermark.relative = 0.4  # 改为 40%

# 修改磁盘最小空闲空间
disk_free_limit.absolute = 5GB  # 改为 5GB

# 修改日志级别
log.console.level = debug  # 改为 debug 级别
```

### 2. 重启服务使配置生效

```bash
docker-compose -f ../compose.yaml restart
```

### 3. 验证配置

```bash
# 查看日志确认配置加载
docker logs rabbitmq_01

# 进入容器查看当前配置
docker exec -it rabbitmq_01 rabbitmq-diagnostics status
```

## 常用配置示例

### 开发环境（资源受限）

```ini
# 内存使用更保守
vm_memory_high_watermark.relative = 0.4
disk_free_limit.absolute = 1GB
```

### 生产环境（高性能）

```ini
# 内存可以使用更多
vm_memory_high_watermark.relative = 0.7
disk_free_limit.absolute = 5GB

# 增加连接数
channel_max = 4096
```

### 启用更多插件

编辑 `enabled_plugins`：

```erlang
[
  rabbitmq_management,
  rabbitmq_delayed_message_exchange,
  rabbitmq_prometheus,
  rabbitmq_shovel,
  rabbitmq_federation
].
```

注意：最后的点号(`.`)不能省略！

## 配置文件格式说明

### 旧格式 (advanced.config)

使用 Erlang 语法：

```erlang
[
  {rabbit, [
    {vm_memory_high_watermark, 0.6}
  ]}
].
```

### 新格式 (rabbitmq.conf) - 推荐

使用简单的键值对：

```ini
vm_memory_high_watermark.relative = 0.6
```

## 配置优先级

1. **环境变量** (最高优先级，但很多已弃用)
2. **rabbitmq.conf** (推荐使用)
3. **advanced.config** (复杂配置使用)
4. **默认值** (最低优先级)

## 配置文件位置

容器内路径：
- `/etc/rabbitmq/rabbitmq.conf`
- `/etc/rabbitmq/enabled_plugins`
- `/etc/rabbitmq/advanced.config` (可选)

宿主机路径（已挂载）：
- `./etc/rabbitmq.conf`
- `./etc/enabled_plugins`

## 参考文档

- [RabbitMQ 配置文档](https://www.rabbitmq.com/configure.html)
- [配置文件示例](https://github.com/rabbitmq/rabbitmq-server/blob/main/deps/rabbit/docs/rabbitmq.conf.example)
- [环境变量对照表](https://www.rabbitmq.com/configure.html#customise-environment)

