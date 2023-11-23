FROM rabbitmq:3.9-management

# && rabbitmq-plugins enable rabbitmq_management
RUN apt-get update \
    && apt-get install -y tzdata wget

RUN wget -P /opt/rabbitmq/plugins https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/3.9.0/rabbitmq_delayed_message_exchange-3.9.0.ez \
    && rabbitmq-plugins enable rabbitmq_delayed_message_exchange