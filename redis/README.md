# Redis 7.2 Docker Compose

## 快速启动

```bash
cd redis
docker compose up -d
```

## 停止服务

```bash
docker compose down
```

## 配置说明

### 端口
- `6379` - Redis 服务端口

### 默认密码
- 密码: `redis123456`

⚠️ **生产环境请务必修改默认密码！**

### 数据持久化
- 数据目录: `../datas/redis/data`
- 配置目录: `./config`
- 日志目录: `../logs/redis`

### 持久化策略
- **RDB**: 定期快照备份（默认启用）
- **AOF**: 追加式日志（默认启用，每秒同步）

### 自定义配置
可以在 `./config/redis.conf` 中修改 Redis 配置，修改后重启容器生效。

## 连接 Redis

### 命令行连接

```bash
# 使用 redis-cli 连接
docker exec -it redis7 redis-cli -a redis123456

# 或者从容器外连接
redis-cli -h localhost -p 6379 -a redis123456
```

### 外部工具连接
- 主机: `localhost` 或 `127.0.0.1`
- 端口: `6379`
- 密码: `redis123456`

### 测试连接

```bash
# 测试 PING
docker exec -it redis7 redis-cli -a redis123456 ping
# 返回: PONG

# 查看 Redis 信息
docker exec -it redis7 redis-cli -a redis123456 info

# 查看所有配置
docker exec -it redis7 redis-cli -a redis123456 config get "*"
```

## 常用命令

### 查看日志

```bash
# 查看容器日志
docker compose logs -f redis

# 查看慢查询日志
docker exec -it redis7 redis-cli -a redis123456 slowlog get 10
```

### 性能监控

```bash
# 实时监控
docker exec -it redis7 redis-cli -a redis123456 --stat

# 查看内存使用
docker exec -it redis7 redis-cli -a redis123456 info memory

# 查看连接数
docker exec -it redis7 redis-cli -a redis123456 info clients
```

### 数据备份

```bash
# 手动触发 RDB 保存
docker exec -it redis7 redis-cli -a redis123456 save

# 异步保存（不阻塞）
docker exec -it redis7 redis-cli -a redis123456 bgsave

# 导出备份文件
docker cp redis7:/data/dump.rdb ./backup-$(date +%Y%m%d).rdb
```

### 数据恢复

```bash
# 1. 停止 Redis 容器
docker compose down

# 2. 替换数据文件
cp your-backup.rdb ../datas/redis/data/dump.rdb

# 3. 重新启动
docker compose up -d
```

## 配置优化

### 修改密码

编辑 `compose.yaml`，修改 `--requirepass` 参数：

```yaml
command:
  - redis-server
  - /etc/redis/redis.conf
  - --requirepass
  - your_new_password  # 修改这里
```

重启容器生效：

```bash
docker compose down
docker compose up -d
```

### 调整内存限制

编辑 `config/redis.conf`，修改 `maxmemory` 配置：

```conf
# 设置最大内存（例如 1GB）
maxmemory 1gb
```

### 禁用持久化（仅缓存场景）

如果只用作缓存，可以禁用持久化提升性能：

编辑 `config/redis.conf`：

```conf
# 关闭 RDB
save ""

# 关闭 AOF
appendonly no
```

## 注意事项

1. **安全性**
   - ⚠️ 生产环境务必修改默认密码
   - ⚠️ 考虑使用防火墙限制访问
   - ⚠️ 可以重命名或禁用危险命令（如 FLUSHALL）

2. **性能优化**
   - 根据使用场景选择合适的持久化策略
   - 设置合理的内存淘汰策略
   - 监控慢查询日志

3. **数据安全**
   - 定期备份 RDB 文件
   - 监控磁盘空间使用
   - 关注 AOF 文件大小，及时重写

## 故障排查

### 容器无法启动

```bash
# 查看容器日志
docker compose logs redis

# 检查配置文件语法
docker run --rm -v $(pwd)/config/redis.conf:/redis.conf redis:7.2-alpine redis-server /redis.conf --test-config
```

### 连接被拒绝

1. 检查密码是否正确
2. 检查端口是否被占用：`netstat -tulpn | grep 6379`
3. 检查防火墙设置

### 内存占用过高

```bash
# 查看内存使用详情
docker exec -it redis7 redis-cli -a redis123456 info memory

# 查看 key 统计
docker exec -it redis7 redis-cli -a redis123456 --bigkeys

# 手动清理过期 key
docker exec -it redis7 redis-cli -a redis123456 info keyspace
```

## 参考资源

- [Redis 官方文档](https://redis.io/documentation)
- [Redis 命令参考](https://redis.io/commands)
- [Redis 配置文档](https://redis.io/topics/config)

