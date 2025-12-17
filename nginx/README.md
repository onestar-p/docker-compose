# Nginx Docker 部署

## 部署步骤

### 1. 复制配置文件模板

```bash
cd /home/pengyixing/docker-compose/nginx

# 复制主配置文件
cp nginx.conf.example nginx.conf

# 复制上游服务器配置
cp conf.d/upstream.conf.example conf.d/upstream.conf

# 复制站点配置（重命名为你的域名）
cp conf.d/your-domain.conf.example conf.d/your-domain.conf
```

### 2. 根据环境修改配置

#### nginx.conf
```nginx
worker_processes  auto;          # 根据 CPU 核数调整，或设为 auto
worker_connections  1024;        # 根据并发需求调整
client_max_body_size 20M;        # 根据上传需求调整
```

#### conf.d/upstream.conf
```nginx
upstream backend74 {
   server <PHP容器IP>:9001;      # 修改为实际 PHP 服务地址
}

upstream your_upstream {
   server <服务IP>:10010;        # 修改为实际服务地址
}
```

#### conf.d/intranet.etranslate.io.conf
```nginx
server_name  your-domain.com;    # 修改为实际域名
root /wwwroot/your-project;      # 修改为实际项目路径
```

### 3. 启动服务

```bash
docker-compose up -d
```

### 4. 验证

```bash
docker exec nginx nginx -t
curl -I http://localhost
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `nginx.conf.example` | Nginx 主配置模板 |
| `conf.d/upstream.conf.example` | 上游服务器配置模板 |
| `conf.d/your-domain.conf.example` | 站点配置模板 |
| `fastcgi_params` | FastCGI 参数（通用，无需修改） |
| `location_php-*.conf` | PHP location 配置（通用，无需修改） |
