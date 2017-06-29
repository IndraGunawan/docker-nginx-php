FROM nginx:1.13

MAINTAINER Indra Gunawan <guind.online@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN \
    apt update \
    && apt install -y --no-install-recommends \
        curl \
        git-core \
        openssh-client \
        unzip \
        vim \
        wget

# PHP 7.0
RUN \
    apt install -y --no-install-recommends \
        php7.0-bcmath \
        php7.0-cli \
        php7.0-common \
        php7.0-curl \
        php7.0-dev \
        php7.0-fpm \
        php7.0-gd \
        php7.0-intl \
        php7.0-json \
        php7.0-mbstring \
        php7.0-mysql \
        php7.0-opcache \
        php7.0-pgsql \
        php7.0-sqlite3 \
        php7.0-xml \
        php7.0-zip \
        php-apcu \
        php-imagick \
        php-mongodb \
        php-redis \
        php-xdebug

# Config PHP and NGINX
RUN \
    mkdir -p /run/php \
    && chown root:root /run/php \
    && echo "Asia/Jakarta" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata \
    && sed -i "s/;date.timezone =.*/date.timezone = Asia\/Jakarta/g" /etc/php/7.0/fpm/php.ini \
    && sed -i "s/;date.timezone =.*/date.timezone = Asia\/Jakarta/g" /etc/php/7.0/cli/php.ini \
    && sed -i "s/upload_max_filesize =.*/upload_max_filesize = 250M/g" /etc/php/7.0/fpm/php.ini \
    && sed -i "s/memory_limit = 128M/memory_limit = 512M/g" /etc/php/7.0/fpm/php.ini \
    && sed -i "s/post_max_size =.*/post_max_size = 250M/g" /etc/php/7.0/fpm/php.ini \
    && sed -i "s/user = www-data/user = root/g" /etc/php/7.0/fpm/pool.d/www.conf \
    && sed -i "s/group = www-data/group = root/g" /etc/php/7.0/fpm/pool.d/www.conf \
    && sed -i "s/listen.owner = www-data/listen.owner = root/g" /etc/php/7.0/fpm/pool.d/www.conf \
    && sed -i "s/listen.group = www-data/listen.group = root/g" /etc/php/7.0/fpm/pool.d/www.conf \
    && sed -i "s/listen       80;/listen       80    default_server;/g" /etc/nginx/conf.d/default.conf

# Clear cache
RUN \
    apt clean \
    && apt autoremove --purge \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Project
RUN mkdir -p /home/projects
VOLUME /home/projects
WORKDIR /home/projects

# Docker Container
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
