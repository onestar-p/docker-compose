FROM php:8.1.3-fpm


RUN set -x \
    && apt-get update \
    ## && apt-get install -y unixodbc-dev zlib1g-dev libzip-dev wget procps python supervisor\
    && apt-get install -y unixodbc-dev zlib1g-dev libzip-dev wget\
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
    && composer config -g repo.packagist composer https://packagist.phpcomposer.com \
    # 删除`/usr/src/php/ext`目录
    && docker-php-source delete \
    && rm -rf /tmp/* 