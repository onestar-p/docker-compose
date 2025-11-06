# Docker Compose 中间件集合

这是一个预配置的 Docker Compose 中间件集合，包含常用的开发和生产环境所需的中间件服务。

## 📦 包含的服务

| 服务 | 版本 | 端口 | 说明 |
|------|------|------|------|
| **Kafka** | 7.3.2 | 9092, 2181, 8080 | 消息队列 + Zookeeper + Kafka UI |
| **MongoDB** | latest | 27017, 8081 | NoSQL 数据库 + Mongo Express |
| **MySQL** | 8.0 | 3306 | 关系型数据库 |
| **Nacos** | latest | - | 服务发现与配置中心 |
| **RabbitMQ** | 3.9 | 5672, 15672 | 消息队列 + 管理界面 |
| **Redis** | 7.2 | 6379 | 缓存数据库 |

## 🚀 快速开始

### 方式一：使用管理脚本（推荐）

```bash
# 查看帮助
./manage.sh help

# 启动所有服务
./manage.sh start all

# 启动指定服务
./manage.sh start mysql redis

# 查看服务状态
./manage.sh status

# 停止服务
./manage.sh stop mysql

# 重启服务
./manage.sh restart redis

# 查看日志
./manage.sh logs mysql
```

### 方式二：手动操作

```bash
# 进入服务目录
cd mysql

# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看日志
docker compose logs -f
```

## 📖 管理脚本使用说明

`manage.sh` 是一个便捷的管理工具，支持以下命令：

### 命令列表

| 命令 | 说明 | 示例 |
|------|------|------|
| `start` | 启动服务 | `./manage.sh start mysql redis` |
| `stop` | 停止服务 | `./manage.sh stop kafka` |
| `restart` | 重启服务 | `./manage.sh restart all` |
| `status` | 查看服务状态 | `./manage.sh status` |
| `logs` | 查看服务日志 | `./manage.sh logs mysql` |
| `list` | 列出所有可用服务 | `./manage.sh list` |
| `help` | 显示帮助信息 | `./manage.sh help` |

### 使用示例

```bash
# 启动开发环境常用服务
./manage.sh start mysql redis

# 启动微服务相关组件
./manage.sh start kafka nacos rabbitmq

# 查看所有服务状态
./manage.sh status all

# 停止所有服务
./manage.sh stop all

# 重启 MySQL
./manage.sh restart mysql

# 实时查看 Redis 日志
./manage.sh logs redis
```

## 📁 项目结构

```
docker-compose/
├── manage.sh                 # 管理脚本
├── README.md                 # 项目说明
├── datas/                    # 数据持久化目录
│   ├── kafka/
│   ├── mongodb/
│   ├── mysql/
│   ├── redis/
│   └── ...
├── logs/                     # 日志目录
│   ├── mysql/
│   ├── redis/
│   └── ...
├── kafka/
│   └── compose.yaml
├── mongodb/
│   └── compose.yaml
├── mysql/
│   ├── compose.yaml
│   ├── config/
│   │   └── my.cnf
│   └── README.md
├── nacos/
│   └── compose.yaml
├── rabbitmq/
│   └── compose.yaml
└── redis/
    ├── compose.yaml
    ├── config/
    │   └── redis.conf
    └── README.md
```

## 🔧 配置说明

每个服务都有详细的配置文件和说明文档，请查看对应目录下的 `README.md`：

- [MySQL 配置说明](mysql/README.md)
- [Redis 配置说明](redis/README.md)

### 默认密码

⚠️ **生产环境请务必修改默认密码！**

| 服务 | 用户名 | 密码 |
|------|--------|------|
| MySQL | root | root123456 |
| MySQL | admin | admin123456 |
| MongoDB | admin | admin |
| Redis | - | redis123456 |

## 📝 注意事项

1. **首次启动前**
   - 确保 Docker 和 Docker Compose 已安装
   - 确保相关端口未被占用
   - 检查磁盘空间是否充足

2. **数据持久化**
   - 所有数据存储在 `datas/` 目录
   - 日志存储在 `logs/` 目录
   - 删除这些目录会导致数据丢失

3. **端口冲突**
   - 如果端口被占用，请修改对应服务的 `compose.yaml` 文件
   - 格式：`主机端口:容器端口`

4. **内存要求**
   - Kafka: 建议至少 2GB
   - MySQL: 建议至少 512MB
   - 其他服务: 根据实际使用情况调整

## 🛠️ 故障排查

### Docker 未安装

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh

# 添加当前用户到 docker 组
sudo usermod -aG docker $USER
```

### 端口被占用

```bash
# 查看端口占用
netstat -tulpn | grep <端口号>
# 或
lsof -i :<端口号>
```

### 容器启动失败

```bash
# 查看服务日志
./manage.sh logs <服务名>

# 或直接查看 docker 日志
docker logs <容器名>
```

### 权限问题

```bash
# 给管理脚本添加执行权限
chmod +x manage.sh

# 确保数据目录有写权限
chmod -R 755 datas/ logs/
```

## 🔗 相关链接

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [MySQL 官方文档](https://dev.mysql.com/doc/)
- [Redis 官方文档](https://redis.io/documentation)
- [MongoDB 官方文档](https://docs.mongodb.com/)
- [Kafka 官方文档](https://kafka.apache.org/documentation/)

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
