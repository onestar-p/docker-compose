FROM rabbitmq:3.13.7-management-alpine

# 设置时区
ENV TZ=Asia/Shanghai

# 更新系统包修复安全漏洞并安装依赖
RUN apk update \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        tzdata \
        curl \
        ca-certificates \
    && cp /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && apk del --purge \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# 下载并启用延迟消息插件
RUN curl -sSL -o /opt/rabbitmq/plugins/rabbitmq_delayed_message_exchange-3.13.0.ez \
    https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v3.13.0/rabbitmq_delayed_message_exchange-3.13.0.ez \
    && rabbitmq-plugins enable rabbitmq_delayed_message_exchange \
    && rm -rf /tmp/*

# 设置正确的权限
RUN chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

# 复制初始化脚本
COPY --chown=rabbitmq:rabbitmq init/init-policy.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-policy.sh

# 创建启动脚本（先启动 RabbitMQ，再执行初始化）
RUN echo '#!/bin/bash' > /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo 'set -e' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo '' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo '# 启动 RabbitMQ（后台）' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo 'docker-entrypoint.sh rabbitmq-server &' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo 'RABBITMQ_PID=$!' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo '' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo '# 执行初始化脚本' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo '/usr/local/bin/init-policy.sh || echo "初始化脚本执行失败，但继续运行"' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo '' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo '# 等待 RabbitMQ 进程' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && echo 'wait $RABBITMQ_PID' >> /usr/local/bin/docker-entrypoint-wrapper.sh \
    && chmod +x /usr/local/bin/docker-entrypoint-wrapper.sh

USER rabbitmq

# 使用包装脚本作为入口点
CMD ["/usr/local/bin/docker-entrypoint-wrapper.sh"]