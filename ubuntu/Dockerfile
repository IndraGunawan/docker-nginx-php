FROM ubuntu:xenial

MAINTAINER Indra Gunawan <guind.online@gmail.com>

ENV DEBIAN_FRONTEND=noninteractive

RUN \
    apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git-core \
        openssh-client \
        openssl \
        unzip \
        vim \
        wget

# Nginx 1.13.2
RUN \
    wget --quiet -O - https://nginx.org/keys/nginx_signing.key | apt-key add - \
    && echo "deb http://nginx.org/packages/mainline/ubuntu/ xenial nginx" >> /etc/apt/sources.list.d/nginx.list \
    && echo "deb-src http://nginx.org/packages/mainline/ubuntu/ xenial nginx" >> /etc/apt/sources.list.d/nginx.list \
    && apt-get update && apt-get install -y --no-install-recommends nginx=1.13.2-1~xenial

EXPOSE 80

# PHP 7.1

RUN \
    apt-get install -y --no-install-recommends software-properties-common \
    && LANG=C.UTF-8 add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php7.1-bcmath \
        php7.1-cli \
        php7.1-common \
        php7.1-curl \
        php7.1-dev \
        php7.1-fpm \
        php7.1-gd \
        php7.1-intl \
        php7.1-json \
        php7.1-mbstring \
        php7.1-mysql \
        php7.1-opcache \
        php7.1-pgsql \
        php7.1-sqlite3 \
        php7.1-xml \
        php7.1-zip \
        php-apcu \
        php-imagick \
        php-mongodb \
        php-redis \
        php-xdebug

# Config PHP and NGINX
RUN \
    mkdir -p /run/php \
    && chown root:root /run/php \
    && sed -i "s/;date.timezone =.*/date.timezone = Asia\/Jakarta/g" /etc/php/7.1/fpm/php.ini \
    && sed -i "s/;date.timezone =.*/date.timezone = Asia\/Jakarta/g" /etc/php/7.1/cli/php.ini \
    && sed -i "s/upload_max_filesize =.*/upload_max_filesize = 250M/g" /etc/php/7.1/fpm/php.ini \
    && sed -i "s/memory_limit = 128M/memory_limit = 512M/g" /etc/php/7.1/fpm/php.ini \
    && sed -i "s/post_max_size =.*/post_max_size = 250M/g" /etc/php/7.1/fpm/php.ini \
    && sed -i "s/user = www-data/user = root/g" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "s/group = www-data/group = root/g" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "s/listen.owner = www-data/listen.owner = root/g" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "s/listen.group = www-data/listen.group = root/g" /etc/php/7.1/fpm/pool.d/www.conf \
    && sed -i "s/worker_processes 2;/worker_processes auto;/g" /etc/nginx/nginx.conf \
    && sed -i "s/listen       80;/listen       80    default_server;/g" /etc/nginx/conf.d/default.conf \

    # clear cache
    && apt-get clean \
    && apt-get autoremove --purge \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Project
RUN mkdir -p /home/projects
VOLUME /home/projects
WORKDIR /home/projects

# Docker Container
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
