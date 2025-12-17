FROM php:7.4-fpm-alpine

# Alpine 版本更小、漏洞更少
# 注意：PHP 7.4 已于 2022年11月 EOL，建议尽快升级到 PHP 8.x

RUN set -x \
    && apk update \
    && apk add --no-cache unixodbc-dev zlib-dev libzip-dev wget \
    && docker-php-source extract \
    # 安装扩展
    && docker-php-ext-install bcmath pdo pdo_mysql zip pcntl \
    # 安装 Redis
    && wget http://pecl.php.net/get/redis-5.3.4.tgz -O /tmp/redis.tgz \
    && pecl install /tmp/redis.tgz \
    && rm -rf /tmp/redis.tgz \
    && docker-php-ext-enable redis \
    # 安装composer
    && php -r "copy('https://install.phpcomposer.com/installer', 'composer-setup.php');" \
    && php composer-setup.php && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ \
    # 清理
    && docker-php-source delete \
    && rm -rf /tmp/* /var/cache/apk/*
