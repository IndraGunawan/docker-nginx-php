#!/bin/bash

# Environment
# - DOMAIN_(1,2,3,...)=domain_name|domain_path|type
# - TIMEZONE=Asia/Jakarta
# - PHP_FPM_SERVER=php-host:9000

# Nginx Configuration
NGINX_DIR=/etc/nginx
CONF_DIR="$NGINX_DIR/conf.d"

cat > "$NGINX_DIR/nginx.conf" <<END
user root;
worker_processes 2;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    include /etc/nginx/upstream.conf;
    include /etc/nginx/conf.d/*.conf;
}

END

if [ -z $PHP_FPM_SERVER ]; then
    FPM_SERVER="unix:/run/php/php7.0-fpm.sock;"
else
    FPM_SERVER="$PHP_FPM_SERVER;"
fi

cat > "$NGINX_DIR/upstream.conf" <<END
upstream upstream {
    server $FPM_SERVER
}

gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 1100;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

client_max_body_size 50M;
client_body_buffer_size 1m;
client_body_timeout 15;
client_header_timeout 15;
keepalive_timeout 15;
send_timeout 15;
sendfile on;
tcp_nopush on;
tcp_nodelay on;

open_file_cache max=2000 inactive=20s;
open_file_cache_valid 60s;
open_file_cache_min_uses 5;
open_file_cache_errors off;

fastcgi_buffers 256 16k;
fastcgi_buffer_size 128k;
fastcgi_connect_timeout 3s;
fastcgi_send_timeout 120s;
fastcgi_read_timeout 120s;
fastcgi_busy_buffers_size 256k;
fastcgi_temp_file_write_size 256k;
reset_timedout_connection on;
END

# Create virtualhost directory if not exists
[ -d $CONF_DIR ] || mkdir -p $CONF_DIR

# Creating virtualhost
count="0"

while [ true ]
do
    (( count++ ))
    DOMAIN="DOMAIN_$count"
    DOMAIN=${!DOMAIN}
    # Check total domain
    if [ -z ${DOMAIN} ]; then
        break
    fi

    # Check domain format
    DETAIL=(${DOMAIN//|/ })
    if [ ! ${#DETAIL[@]}  -eq 3 ]; then
        echo "Invalid format DOMAIN_$count, format: domain_name|path|type" >&2
    fi

    DOMAIN_NAME=${DETAIL[0]}
    DOMAIN_PATH=${DETAIL[1]}
    DOMAIN_TYPE=${DETAIL[2]}

    # Continue if vhost exists
    [ -f "$CONF_DIR/$DOMAIN_NAME.conf" ] && continue

    if [ $DOMAIN_TYPE = "php" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH;
    index index.php;

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php\$ {
        fastcgi_keep_conn on;
        fastcgi_pass upstream;
        fastcgi_index app.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;

        include fastcgi_params;
    }
}
END
    elif [ $DOMAIN_TYPE = "static" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH;
    index index.html;

    add_header Access-Control-Allow-Origin *;

    location ~ /\.ht {
        deny all;
    }
}
END
    elif [ $DOMAIN_TYPE = "symfony" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH/web;
    index app.php;

    location / {
        # try to serve file directly, fallback to app.php
        try_files \$uri /app.php\$is_args\$args;
    }

    # PROD
    location ~ ^/app\.php(/|\$) {
        fastcgi_max_temp_file_size 1M;
        fastcgi_pass_header Set-Cookie;
        fastcgi_pass_header Cookie;
        fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
        fastcgi_index app.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param  PATH_INFO          \$fastcgi_path_info;
        fastcgi_param  PATH_TRANSLATED    \$document_root\$fastcgi_path_info;

        fastcgi_pass upstream;
        fastcgi_split_path_info ^(.+\.php)(/.*)\\\$;
        include fastcgi_params;
        # When you are using symlinks to link the document root to the
        # current version of your application, you should pass the real
        # application path instead of the path to the symlink to PHP
        # FPM.
        # Otherwise, PHP's OPcache may not properly detect changes to
        # your PHP files (see https://github.com/zendtech/ZendOptimizerPlus/issues/126
        # for more information).
        fastcgi_param  SCRIPT_FILENAME  \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
        # Prevents URIs that include the front controller. This will 404:
        # http://domain.tld/app.php/some-path
        # Remove the internal directive to allow URIs like this
        internal;
    }

    # DEV
    # This rule should only be placed on your development environment
    # In production, don't include this and don't deploy app_dev.php or config.php
    location ~ ^/(app_dev|config)\.php(/|\$) {
        fastcgi_max_temp_file_size 1M;
        fastcgi_pass_header Set-Cookie;
        fastcgi_pass_header Cookie;
        fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param  PATH_INFO          \$fastcgi_path_info;
        fastcgi_param  PATH_TRANSLATED    \$document_root\$fastcgi_path_info;

        fastcgi_pass upstream;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
        # When you are using symlinks to link the document root to the
        # current version of your application, you should pass the real
        # application path instead of the path to the symlink to PHP
        # FPM.
        # Otherwise, PHP's OPcache may not properly detect changes to
        # your PHP files (see https://github.com/zendtech/ZendOptimizerPlus/issues/126
        # for more information).
        fastcgi_param  SCRIPT_FILENAME  \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php$ {
        fastcgi_keep_conn on;
        fastcgi_pass upstream;
        fastcgi_index app.php;
        fastcgi_param  SCRIPT_FILENAME  \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;

        include fastcgi_params;
    }
}
END
    elif [ $DOMAIN_TYPE = "rewrite_index" ]; then
        cat > "$CONF_DIR/$DOMAIN_NAME.conf" <<END
server {
    listen 80;
    server_name $DOMAIN_NAME;
    root $DOMAIN_PATH;
    index index.php;

    location / {
        # try to serve file directly, fallback to index.php
        try_files \$uri /index.php\$is_args\$args;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php\$ {
        fastcgi_keep_conn on;
        fastcgi_pass upstream;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;

        include fastcgi_params;
    }
}
END
    else
        echo "Invalid type DOMAIN_$count = $DOMAIN_TYPE, available type (php|static|symfony|rewrite_index)" >&2
    fi

done

# Change timezone if provide
if [ ! -z $TIMEZONE ] && [ -f /etc/php/7.0/fpm/php.ini ] && [ -f /etc/php/7.0/cli/php.ini ]; then
    sed -i "s/date.timezone =.*/date.timezone = $TIMEZONE/" /etc/php/7.0/fpm/php.ini
    sed -i "s/date.timezone =.*/date.timezone = $TIMEZONE/" /etc/php/7.0/cli/php.ini
    echo $TIMEZONE > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata
fi

# Start PHP and NGINX
php-fpm7.0 -R && nginx -g 'daemon off;' && eval $(ssh-agent)
