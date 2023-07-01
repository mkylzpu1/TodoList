#!/bin/bash

# タイムゾーンの設定
sudo sed -i 's/ZONE="UTC"/ZONE="Asia\/Tokyo"/g' /etc/sysconfig/clock
sudo sed -i 's/UTC=true/UTC=False/g' /etc/sysconfig/clock
sudo ln -sf /usr/share/zoneinfo/Japan /etc/localtime

#install php
sudo yum update -y
sudo amazon-linux-extras enable php8.0
sudo amazon-linux-extras install -y php8.0
sudo yum install -y php-mbstring php-xml php-bcmath
yum clean metadata

#install nginx
sudo amazon-linux-extras enable nginx1
sudo amazon-linux-extras install nginx1
yum clean metadata
sudo yum -y install nginx-mod*
rpm -qa|grep nginx

# php-fpmの設定
sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen.owner = nobody/listen.owner = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen.group = nobody/listen.group = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' /etc/php-fpm.d/www.conf

# 再起動
sudo systemctl restart nginx
sudo systemctl restart php-fpm

# nginxとphp-fpmの自動起動設定
sudo systemctl enable nginx
sudo systemctl enable php-fpm

# install git
sudo yum install -y git
# ssh-keygen -t rsa -b 4096
# cat ~/.ssh/id_rsa.pub

# composerでファイルが見つからないエラーがみつかるため挿入　本来はいらない
export HOME=/root
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# install node.js
git clone https://github.com/creationix/nvm.git ~/.nvm
source ~/.nvm/nvm.sh
echo -e "\n# nvm\nif [[ -s ~/.nvm/nvm.sh ]] ; then\n    source ~/.nvm/nvm.sh ;\nfi" >> ~/.bash_profile
nvm install 16.13.1
nvm use v16.13.1


# install composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'e21205b207c3ff031906575712edab6f13eb0b361f2085f1f1237b7126d785e826a450292b6cfd1d64d92e6563bbde02') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/local/bin/composer

# gitからアプリをクローン
sudo mkdir /var/www
cd /var/www
git clone https://github.com/mkylzpu1/TodoList.git
cd TodoList
cp .env.example .env
composer update
composer install
php artisan key:generate
touch database/database.sqlite
cd ~/

# nginx.confを記載
cat > /etc/nginx/nginx.conf << EOF
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /var/www/TodoList/public;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
           try_files \$uri \$uri/ /index.php?\$query_string;
        }
    }

# Settings for a TLS enabled server.
#
#    server {
#        listen       443 ssl http2;
#        listen       [::]:443 ssl http2;
#        server_name  _;
#        root         /var/www/TodoList/public;
#
#        ssl_certificate "/etc/pki/nginx/server.crt";
#        ssl_certificate_key "/etc/pki/nginx/private/server.key";
#        ssl_session_cache shared:SSL:1m;
#        ssl_session_timeout  10m;
#        ssl_ciphers PROFILE=SYSTEM;
#        ssl_prefer_server_ciphers on;
#
#        # Load configuration files for the default server block.
#        include /etc/nginx/default.d/*.conf;
#
#        error_page 404 /404.html;
#            location = /40x.html {
#        }
#
#        error_page 500 502 503 504 /50x.html;
#            location = /50x.html {
#        }
#    }
}
EOF

sudo nginx -s reload

# 権限周り
cd /var/www/TodoList
sudo chmod 777 storage/logs/laravel.log
sudo chmod -R 777 storage
sudo chmod -R 775 bootstrap/cache
sudo chmod 777 database
sudo chmod 777 database/database.sqlite

# DB
php artisan migrate

# vite
npm install -D tailwindcss postcss autoprefixer

cd /var/www/TodoList
npm run build

sudo nginx -s reload
