GIT_BRANCH=develop
GIT_IP=127.0.0.1
DB=example
USER=example
PASSWORD=example
PROJECT_NAME=example
SERVER_NAME=127.0.0.1
SERVER_PORT=80
MYSQL_SERVER=127.0.0.1
YUM_INSTALL=yum -y install
ROOT_DIR=/usr/share/nginx/html
LARAVEL_DIR=$(ROOT_DIR)/$(PROJECT_NAME)
CRON_JOB_DROP_CACHE=* */1 * * * sync;sync;sync; echo 3 > /proc/sys/vm/drop_caches
CRON_JOB_SYNC_GIT=*/1 * * * *  cd $(LARAVEL_DIR);git pull;git checkout $(GIT_BRANCH);composer install;php artisan migrate;php artisan db:seed
RM=rm -rf

install: check environment nginx php_fpm mysql data ssh composer
install_full: check environment nginx php_fpm mysql data ssh composer laravel_init src cron
project_init: laravel_init src cron

check:
	-sudo firewall-cmd --zone=public --add-port=80/tcp
	-sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
	-sudo firewall-cmd --zone=public --add-port=22/tcp
	-sudo firewall-cmd --zone=public --add-port=22/tcp --permanent
	-sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
	-echo 0 > /sys/fs/selinux/enforce
	touch *

environment:
	sudo $(YUM_INSTALL) epel-release >> /dev/null 2>&1
	sudo rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm >> /dev/null 2>&1
	sudo cp ./nginx.repo /etc/yum.repos.d/nginx.repo
	sudo cp ./MariaDB10.repo /etc/yum.repos.d/MariaDB10.repo
	yum remove mariadb-server mariadb mariadb-libs
	yum clean all
	yum -y install MariaDB-server MariaDB-client
	sudo yum -y update
	sudo $(YUM_INSTALL) nginx php72 php72-php-fpm ntp ntpdate ntp-doc mlocate telnnet yum-cron mod_ssl mod_perl php72-php-mysqlnd zip unzip php72-php-mbstring php72-php-mcrypt redis php72-php-pecl-redis  php72-php-gd redis-cli rsync git npm php72-php-zip php72-php-xml
	(crontab -l | grep -v -F '$(CRON_JOB_DROP_CACHE)';echo '$(CRON_JOB_DROP_CACHE)') | crontab -
	#sudo ntpdate pool.ntp.org >> /dev/null 2>&1
	sudo updatedb;sudo systemctl start ntpd;sudo systemctl enable ntpd

nginx:
	sudo systemctl restart nginx;sudo systemctl enable nginx
	sudo cp ./nginx.examle.conf /etc/nginx/conf.d/$(PROJECT_NAME).conf
	-sed -i 's/{project_name}/$(PROJECT_NAME)/g' /etc/nginx/conf.d/$(PROJECT_NAME).conf /etc/nginx/conf.d/$(PROJECT_NAME).conf
	-sed -i 's/{server_name}/$(SERVER_NAME)/g' /etc/nginx/conf.d/$(PROJECT_NAME).conf /etc/nginx/conf.d/$(PROJECT_NAME).conf
	-sed -i 's/{server_port}/$(SERVER_PORT)/g' /etc/nginx/conf.d/$(PROJECT_NAME).conf /etc/nginx/conf.d/$(PROJECT_NAME).conf
	sudo chown -R nginx.nginx /usr/share/nginx/html;systemctl reload nginx

php_fpm:
	-sed -i 's/cgi.fix_pathinfo=0/cgi.fix_pathinfo=1/g' /etc/opt/remi/php72/php.ini /etc/opt/remi/php72/php.ini
	-sed -i 's/user=apache/user=nginx/g' /etc/opt/remi/php72/php-fpm.d/www.conf /etc/opt/remi/php72/php-fpm.d/www.conf
	-sed -i 's/group=apache/group=nginx/g' /etc/opt/remi/php72/php-fpm.d/www.conf /etc/opt/remi/php72/php-fpm.d/www.conf
	-sed -i 's/;listen.owner=nobody/listen.owner=nobody/g' /etc/opt/remi/php72/php-fpm.d/www.conf /etc/opt/remi/php72/php-fpm.d/www.conf
	-sed -i 's/;listen.group=nobody/listen.group=nobody/g' /etc/opt/remi/php72/php-fpm.d/www.conf /etc/opt/remi/php72/php-fpm.d/www.conf
	sudo systemctl restart php72-php-fpm;sudo systemctl enable php72-php-fpm

mysql:
	systemctl restart mariadb;systemctl enable mariadb
	#sudo echo "DROP USER $(USER)@localhost" | mysql
	sudo echo "grant all privileges on *.* to $(USER)@localhost IDENTIFIED BY '$(PASSWORD)'" | mysql

data:
	#sudo mysqladmin -f drop $(DB)
	sudo mysqladmin create $(DB) --default-character-set=utf8 >> /dev/null 2>&1

ssh:
	sudo mkdir -p /root/.ssh
	cp ./rd_sync_rsa.pub /root/.ssh/id_rsa.pub
	cp ./rd_sync_rsa /root/.ssh/id_rsa
	sudo chmod 600 -R /root/.ssh

composer:
	cd /tmp
	ln -s /usr/bin/php72 /usr/bin/php
	curl -sS https://getcomposer.org/installer | php
	mv composer.phar /usr/bin/composer
	composer global require "laravel/installer"
	ln -s /root/.config/composer/vendor/bin/laravel /usr/bin/laravel

laravel_init:
	sudo $(RM) $(PROJECT_NAME)
	git config --global user.name "部署用"
	git config --global user.email "kimi0230@gmail.com"
	git clone git@$(GIT_IP)/$(PROJECT_NAME).git
	cd $(PROJECT_NAME);composer install;cd ..
	sudo $(RM) $(LARAVEL_DIR)
	sudo mv ./$(PROJECT_NAME) $(ROOT_DIR)
	cp $(LARAVEL_DIR)/.env.example $(LARAVEL_DIR)/.env
	systemctl restart nginx;systemctl restart php72-php-fpm;systemctl restart mariadb
	-sed -i 's/DB_DATABASE=homestead/DB_DATABASE=$(DB)/g' $(LARAVEL_DIR)/.env $(LARAVEL_DIR)/.env
	-sed -i 's/DB_USERNAME=homestead/DB_USERNAME=$(USER)/g' $(LARAVEL_DIR)/.env $(LARAVEL_DIR)/.env
	-sed -i 's/DB_PASSWORD=secret/DB_PASSWORD=$(PASSWORD)/g' $(LARAVEL_DIR)/.env $(LARAVEL_DIR)/.env
	-sed -i 's/DB_USERNAME=root/DB_USERNAME=$(USER)/g' $(LARAVEL_DIR)/.env $(LARAVEL_DIR)/.env
	-sed -i 's/DB_PASSWORD=root!QAZ2wsx/DB_PASSWORD=$(PASSWORD)/g' $(LARAVEL_DIR)/.env $(LARAVEL_DIR)/.env
	chown nginx.nginx -R $(LARAVEL_DIR)
	chmod 777 -R $(LARAVEL_DIR)/storage
	chmod 777 -R $(LARAVEL_DIR)/public
	systemctl reload nginx

src:
	cd $(LARAVEL_DIR);git pull;git checkout $(GIT_BRANCH);composer install;php artisan migrate;php artisan db:seed

cron:
	(crontab -l | grep -v -F '$(CRON_JOB_SYNC_GIT)';echo '$(CRON_JOB_SYNC_GIT)') | crontab -

