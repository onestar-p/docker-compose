# MySQL 8.0 Docker Compose

## 快速启动

```bash
cd mysql
docker-compose up -d
```

## 停止服务

```bash
docker-compose down
```

## 配置说明

### 端口
- `3306` - MySQL 服务端口

### 默认账户
- **Root 账户**
  - 用户名: `root`
  - 密码: `root123456`
  
- **普通账户**
  - 用户名: `admin`
  - 密码: `admin123456`
  - 默认数据库: `mydb`

### 数据持久化
- 数据目录: `../datas/mysql/data`
- 配置目录: `./config`
- 日志目录: `../logs/mysql`

### 自定义配置
可以在 `./config/my.cnf` 中修改 MySQL 配置，修改后重启容器生效。

## 连接 MySQL

### 命令行连接
```bash
# 使用 root 用户
docker exec -it mysql8 mysql -uroot -proot123456

# 使用 admin 用户
docker exec -it mysql8 mysql -uadmin -padmin123456 mydb
```

### 外部工具连接
- 主机: `localhost` 或 `127.0.0.1`
- 端口: `3306`
- 用户名: `root` 或 `admin`
- 密码: `root123456` 或 `admin123456`

## 注意事项

⚠️ **生产环境请务必修改默认密码！**

修改密码方式：
1. 编辑 `compose.yaml` 文件中的 `MYSQL_ROOT_PASSWORD` 和 `MYSQL_PASSWORD`
2. 重新创建容器：
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

## 查看日志

```bash
# 查看容器日志
docker-compose logs -f mysql

# 查看错误日志
tail -f ../logs/mysql/error.log

# 查看慢查询日志
tail -f ../logs/mysql/slow.log
```

## 备份与恢复

### 备份数据库
```bash
docker exec mysql8 mysqldump -uroot -proot123456 mydb > backup.sql
```

### 恢复数据库
```bash
docker exec -i mysql8 mysql -uroot -proot123456 mydb < backup.sql
```

