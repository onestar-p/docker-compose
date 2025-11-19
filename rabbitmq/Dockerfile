FROM rabbitmq:3.13.7-management

# 设置时区
ENV TZ=Asia/Shanghai

# 更新系统包修复安全漏洞并安装依赖
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        tzdata \
        wget \
        ca-certificates \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 下载并启用延迟消息插件
RUN wget -P /opt/rabbitmq/plugins \
    https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v3.13.0/rabbitmq_delayed_message_exchange-3.13.0.ez \
    && rabbitmq-plugins enable rabbitmq_delayed_message_exchange

# 设置正确的权限
RUN chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

USER rabbitmq