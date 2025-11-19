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

USER rabbitmq