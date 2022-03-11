#!/bin/bash

function settings::set_nginx_conf() {
cat << WORDPRESS_CONFIG > /etc/nginx/sites-available/wordpress
# Managed by installation script - Do not change
server {
       listen 80;
       root /var/www/wordpress;
       index index.php index.html index.htm index.nginx-debian.html;
       server_name localhost;
       location / {
               try_files \$uri \$uri/ =404;
       }
       location ~ \.php\$ {
               include snippets/fastcgi-php.conf;
               fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
       }
       location ~ /\.ht {
               deny all;
       }
}
WORDPRESS_CONFIG
}

function settings::create_wp_db() {
mysql << WORDPRESS_DB_SCRIPT 
DROP DATABASE IF EXISTS wordpress;
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
GRANT ALL ON wordpress.* TO 'wordpressuser'@'localhost' IDENTIFIED BY 'keepcoding';
FLUSH PRIVILEGES;
WORDPRESS_DB_SCRIPT
}

function settings::mysql_secure_installation() {
mysql --user=root << MYSQL_SECURE
  UPDATE mysql.user SET Password=PASSWORD('${db_root_password}') WHERE User='root';
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
MYSQL_SECURE
}

function settings::set_filebeat_configuration() {
cat << FILEBEAT_CONFIG > /etc/filebeat/filebeat.yml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/*.log
    - /var/log/nginx/*.log
    - /var/log/mysql/*.log

output.logstash:
  hosts: ["192.168.0.10:5044"]
FILEBEAT_CONFIG
}

