# PHP 8.1 Docker 部署

## 部署步骤

### 1. 复制配置文件模板

```bash
cd /home/pengyixing/docker-compose/php8

# 复制 PHP 配置
cp php.ini.example php.ini

# 复制 PHP-FPM 配置
cp php-fpm.d/www.conf.example php-fpm.d/www.conf
```

### 2. 根据服务器配置调整参数

编辑 `php-fpm.d/www.conf`，根据服务器内存调整：

```ini
; 计算公式：max_children = 可用内存MB / 40
pm.max_children = 50        ; 2GB 内存建议 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
pm.max_requests = 500
```

### 3. 启动服务

```bash
docker-compose up -d --build
```

### 4. 验证

```bash
docker exec compose-php-8-1 php -v
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `php.ini.example` | PHP 配置模板 |
| `php-fpm.d/www.conf.example` | PHP-FPM 进程管理配置模板 |
| `Dockerfile` | 镜像构建文件 |
| `compose.yaml` | Docker Compose 配置 |
