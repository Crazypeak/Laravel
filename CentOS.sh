yum -y install make zlib zlib-devel gcc-c++ libtool openssl openssl-devel libxml2 libxml-devel libxslt libxslt-devel gd zlib zlib-devel libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel openssl openssl-devel curl curl-devel libaio-devel
mkdir '/data'
mkdir '/data/www'
mkdir '/data/mysql'
cd /usr/local/src

PHPVERSION=7.2.26
wget https://www.php.net/distributions/php-${PHPVERSION}.tar.gz
tar -zxvf php-${PHPVERSION}.tar.gz && cd php-${PHPVERSION}
./configure --prefix=/usr/local/php --with-curl --with-freetype-dir --with-gd --with-gettext --with-iconv-dir --with-kerberos --with-libdir=lib64 --with-libxml-dir --with-mysqli --with-openssl --with-pcre-regex --with-pdo-mysql --with-pdo-sqlite --with-pear --with-png-dir --with-xmlrpc --with-xsl --with-zlib --enable-fpm --enable-bcmath --enable-libxml --enable-inline-optimization --enable-gd-native-ttf --enable-mbregex --enable-mbstring --enable-opcache --enable-pcntl --enable-shmop --enable-soap --enable-sockets --enable-sysvsem --enable-xml --enable-zip --with-jpeg-dir
make && make install
cp ./php.ini-development /usr/local/php/lib/php.ini
cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf
cp /usr/local/php/etc/php-fpm.d/www.conf.default /usr/local/php/etc/php-fpm.d/www.conf
cp -R /usr/local/php/sbin/php-fpm /etc/init.d/php-fpm
sed -i "s/pm\.max_children \= 5/pm\.max_children \= 400/g" /usr/local/php/etc/php-fpm.d/www.conf
sed -i "s/pm\.start_servers \= 2/pm\.start_servers \= 40/g" /usr/local/php/etc/php-fpm.d/www.conf
sed -i "s/pm\.min_spare_servers \= 1/pm\.min_spare_servers \= 20/g" /usr/local/php/etc/php-fpm.d/www.conf
sed -i "s/pm\.max_spare_servers \= 3/pm\.max_spare_servers \= 80/g" /usr/local/php/etc/php-fpm.d/www.conf
/usr/local/php/sbin/php-fpm
cd ..

NGINXVERSION=1.16.1
wget http://nginx.org/download/nginx-${NGINXVERSION}.tar.gz
tar -zxvf nginx-${NGINXVERSION}.tar.gz && cd nginx-${NGINXVERSION}
./configure --prefix=/usr/local/nginx --with-http_stub_status_module --with-http_ssl_module --with-pcre
make && make install
rm -f /usr/local/nginx/conf/nginx.conf && touch /usr/local/nginx/conf/nginx.conf && echo '
#user  nobody;
worker_processes  auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 65535;

#error_log  logs/error.log;
error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    client_max_body_size   20m;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    #include     vhost/*.conf;
    server {
        listen       80;
        server_name  localhost;
        rewrite ^(.*)$  https://$host$1 permanent;
    }
    server {
        listen       443 ssl;
        server_name  localhost;
        root         /data/www/default;

        ssl                  on;
        ssl_certificate      ./ssl/xzky.pem;
        ssl_certificate_key  ./ssl/xzky.key;
        #ssl_client_certificate ca.crt;
        #ssl_verify_client on;
        ssl_session_timeout  5m;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers  ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP;
        ssl_prefer_server_ciphers   on;

        location / {
            index  index.html index.htm index.php;
            if ( -f $request_filename) {
               break;
            }
            if ( !-e $request_filename) {
               rewrite ^(.*)$ /index.php/$1 last;
               break;
            }
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        location ~ \.php {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_split_path_info ^(.+\.php)(.*)$;
            fastcgi_param PATH_INFO $fastcgi_path_info;
            fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}' > /usr/local/nginx/conf/nginx.conf
/usr/local/nginx/sbin/nginx
cd ..

MYSQLVERSION=5.7.28
wget https://cdn.mysql.com//Downloads/MySQL-5.7/mysql-${MYSQLVERSION}-linux-glibc2.12-x86_64.tar.gz
tar -zxvf mysql-${MYSQLVERSION}-linux-glibc2.12-x86_64.tar.gz && mv mysql-${MYSQLVERSION}-linux-glibc2.12-x86_64 ../mysql
cd ../mysql
groupadd mysql
useradd mysql -s /sbin/nologin -g mysql
chown -R mysql:mysql /data/mysql
chown -R mysql:mysql ./
sed -i "s/var\/lib/data/g" /etc/my.cnf
sed -i '12,13d' /etc/my.cnf
./bin/mysqld --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/data/mysql
chown -R root:root ./
./support-files/mysql.server start
cd /usr/local/src

REDISVERSION=5.0.7
wget http://download.redis.io/releases/redis-{REDISVERSION}.tar.gz
tar xzf redis-{REDISVERSION}.tar.gz
mv redis-{REDISVERSION} ../redis
cd ../redis-{REDISVERSION}
make
nohup src/redis-server &
cd /usr/local/src


