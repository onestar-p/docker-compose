# 安全配置说明

## 安全扫描工具安装

### Trivy（推荐）

```bash
# Ubuntu/Debian
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# 或使用 Docker 运行
alias trivy='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy'
```

### Docker Scout

```bash
# 已内置在 Docker Desktop 中
docker scout quickview
docker scout cves <image-name>
```

### Grype

```bash
# 使用 Docker 运行
docker pull anchore/grype
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock anchore/grype <image-name>
```

## 已实施的安全措施

### 1. 使用 Alpine 基础镜像
- ✅ 从 Debian 切换到 Alpine Linux
- ✅ 减少攻击面（镜像体积从 ~200MB 降到 ~80MB）
- ✅ 更少的预装软件包 = 更少的潜在漏洞

### 2. 包管理优化
- ✅ 使用 `apk upgrade` 更新所有系统包
- ✅ 使用 `--no-cache` 避免缓存漏洞包
- ✅ 清理临时文件和缓存

### 3. 工具替换
- ✅ 使用 `curl` 替代 `wget`（更现代、更安全）
- ✅ 使用 `-sSL` 标志安全下载

### 4. 权限管理
- ✅ 使用非 root 用户 `rabbitmq` 运行
- ✅ 正确设置文件权限

### 5. 版本锁定
- ✅ 使用精确版本号 `3.13.7`
- ✅ 避免 `latest` 标签的不确定性

## 镜像对比

| 指标 | Debian 版本 | Alpine 版本 |
|------|------------|------------|
| 基础镜像 | rabbitmq:3.13-management | rabbitmq:3.13.7-management-alpine |
| 镜像大小 | ~200MB | ~80MB |
| 漏洞数量 | 较多 | 极少 |
| 包管理器 | apt | apk |
| 启动速度 | 较慢 | 较快 |

## 定期安全检查

建议每月执行一次安全扫描：

```bash
# 1. 重新构建镜像
docker-compose -f compose.yaml build --no-cache

# 2. 扫描漏洞
./verify-security.sh

# 3. 如有高危漏洞，考虑更新基础镜像版本
```

## 生产环境额外建议

1. **启用 TLS/SSL**
   - 配置 AMQP over TLS (端口 5671)
   - 配置管理界面 HTTPS (端口 15671)

2. **网络隔离**
   - 使用 Docker 网络隔离
   - 配置防火墙规则
   - 仅暴露必要的端口

3. **密码策略**
   - 使用强密码（至少 16 字符）
   - 定期轮换密码
   - 使用 Docker secrets 而非环境变量

4. **日志审计**
   - 启用访问日志
   - 监控异常登录
   - 集成到 SIEM 系统

5. **更新策略**
   - 订阅 RabbitMQ 安全公告
   - 定期更新基础镜像
   - 测试后再部署到生产

## 漏洞响应流程

如发现高危漏洞：

1. **评估影响**
   ```bash
   trivy image --severity HIGH,CRITICAL rabbitmq_01
   ```

2. **检查更新**
   - 访问 https://hub.docker.com/_/rabbitmq
   - 查看是否有新版本发布

3. **测试更新**
   ```bash
   # 更新 Dockerfile 中的版本号
   docker build -t rabbitmq-new:test .
   trivy image rabbitmq-new:test
   ```

4. **灰度发布**
   - 先在测试环境验证
   - 再在预生产环境验证
   - 最后更新生产环境

## 参考资源

- [RabbitMQ 安全文档](https://www.rabbitmq.com/security.html)
- [Alpine Linux 安全](https://alpinelinux.org/about/)
- [Docker 安全最佳实践](https://docs.docker.com/develop/security-best-practices/)
- [Trivy 文档](https://aquasecurity.github.io/trivy/)

