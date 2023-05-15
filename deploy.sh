#!/bin/bash
sudo apt update
sudo apt install mysql-server
sudo apt-get install php-mysqli
sudo apt install php-fpm

# install certbot
apt install certbot

# obtain SSL Certificate

read -p "请输入您的域名: " domain_name
sudo certbot certonly --standalone -d $domain_name

sudo apt install nginx

php_version=$(php -v | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")

openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Create nginx.conf
cat << EOF > /etc/nginx/nginx.conf
user www-data;
pid /var/run/nginx.pid;
worker_processes auto;
worker_rlimit_nofile 51200;
events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}
http {

    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # SSL设置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/nginx/dhparam.pem;
    ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384';

    # 日志设置
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip设置
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # 虚拟主机配置
    server {
        listen 80;
        server_name $domain_name;
        return 301 https://\$server_name\$request_uri;
    }

    server {
        listen 443 ssl;
        server_name $domain_name;
        ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;
        ssl_session_timeout 1d;
        ssl_session_cache shared:MozSSL:10m;
        ssl_session_tickets off;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }
        location ~ \\.php\$ {
            fastcgi_pass unix:/var/run/php/php$php_version-fpm.sock;
            fastcgi_index index.php;
            fastcgi_buffers 512 64k;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }

        location ~ /\.ht {
            deny all;
        }
        include /etc/nginx/conf.d/*.conf;
    }
}
EOF

read -p "请输入wordpress的database_name: " database_name
read -p "请输入wordpress的database_user: " database_user
database_user_password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 12)

# Create database
sudo mysql -u root -e "CREATE DATABASE $database_name;"

# Create user and grant privileges
sudo mysql -u root -e "CREATE USER $database_user@localhost IDENTIFIED BY '$database_user_password';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON $database_name.* TO $database_user@localhost;"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

sudo rm -rf /usr/share/nginx/html/*
sudo curl -L https://cn.wordpress.org/latest-zh_CN.zip -o html.zip
sudo unzip html.zip
sudo mv ./wordpress/* /usr/share/nginx/html
sudo rm -rf wordpress

sudo groupadd www
sudo useradd -r -s /sbin/nologin -g www-data www
chown -R www-data:www /usr/share/nginx/html
systemctl restart nginx
#输出
echo "wordpress的数据库名为：$database_name"
echo "wordpress的用户名为：$database_user"
echo "wordpress的数据库密码为：$database_user_password"
