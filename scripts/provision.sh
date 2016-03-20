#!/usr/bin/env bash


yum_prepare() {

    # To add the CentOS 7 EPEL repository, open terminal and use the following command:
    yum -y install epel-release
    yum -y install yum-priorities yum-utils yum-plugin-versionlock yum-plugin-show-leaves yum-plugin-upgrade-helper

    # ensure build tools are installed.
    yum -y group install 'Development Tools'

    # nodes repo
    curl --silent --location https://rpm.nodesource.com/setup_5.x | bash -

    yum -y update
}

yum_install() {
    yum -y install autoconf make automake sendmail sendmail-cf m4

    yum -y install vim mlocate curl htop wget dos2unix tree
    yum -y install ntp nmap nc whois libnotify inotify-tools telnet ngrep
}

install_node5() {
    # https://nodejs.org/en/download/package-manager/#enterprise-linux-and-fedora

    yum install -y nodejs
    /usr/bin/npm install -g gulp
    /usr/bin/npm install -g bower
}

install_git2() {
    # http://tecadmin.net/install-git-2-0-on-centos-rhel-fedora/
    v=2.5.4
    yum install -y perl-Tk-devel curl-devel expat-devel gettext-devel openssl-devel zlib-devel
    yum remove -y git
    pushd /usr/src
    wget "https://www.kernel.org/pub/software/scm/git/git-$v.tar.gz"
    tar -xvf "git-$v.tar.gz"
    pushd "git-$v"
    make prefix=/usr/local/git all
    make prefix=/usr/local/git install
    echo "export PATH=\$PATH:/usr/local/git/bin" >> /etc/bashrc

    echo "Installation of git-$v complete"
}

install_nginx() {
    # https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-centos-7
    yum install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx

    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --permanent --zone=public --add-service=https
    # firewall-cmd --reload

    # Server Block Configuration

    # Any additional server blocks, known as Virtual Hosts in Apache, can be added by creating new configuration files in /etc/nginx/conf.d.
    # Files that end with .conf in that directory will be loaded when Nginx is started.

    # Nginx Global Configuration

    # The main Nginx configuration file is located at /etc/nginx/nginx.conf.
    # This is where you can change settings like the user that runs the Nginx daemon processes,
    # and the number of worker processes that get spawned when Nginx is running, among other things.
}


install_hhvm() {

    # TODO Can We Install from RPM????

    # OR Build from source
    # https://github.com/facebook/hhvm/wiki/Building-and-installing-hhvm-on-CentOS-7.x
    # http://lifeandshell.com/php-hhvm-aka-the-hiphop-virtual-machine-on-centos-7/

    # Build The HHVM Key & Repository

    yum -y install cpp gcc-c++ cmake git psmisc {binutils,boost,jemalloc,numactl}-devel \
    {ImageMagick,sqlite,tbb,bzip2,openldap,readline,elfutils-libelf,gmp,lz4,pcre}-devel \
    lib{xslt,event,yaml,vpx,png,zip,icu,mcrypt,memcached,cap,dwarf}-devel \
    {unixODBC,expat,mysql}-devel lib{edit,curl,xml2,xslt}-devel \
    glog-devel oniguruma-devel ocaml gperf enca libjpeg-turbo-devel openssl-devel \
    mysql mysql-server make

    # Optional dependencies (these extensions are not built by default)

    yum -y install {fribidi,libc-client}-devel

    # Get our hhvm
    cd /tmp
    git clone https://github.com/facebook/hhvm -b master  hhvm  --recursive
    cd hhvm

    # Okay let's go
    cmake .
    # Multithreads compiling
    make -j$(($(nproc)+1))
    # Compiled?
    ./hphp/hhvm/hhvm --version
    # Install it
    make install
    # Final
    hhvm --version

    exit;

    # TODO Configure HHVM To Run As Homestead

    service hhvm stop
    sed -i 's/#RUN_AS_USER="www-data"/RUN_AS_USER="vagrant"/' /etc/default/hhvm
    service hhvm start

    # Start HHVM On System Start

    update-rc.d hhvm defaults

}


install_supervisor() {

    # install supervisor
    # http://vicendominguez.blogspot.com.au/2015/02/supervisord-in-centos-7-systemd-version.html
    # http://www.alphadevx.com/a/455-Installing-Supervisor-and-Superlance-on-CentOS
    yum install -y python-setuptools python-pip
    easy_install supervisor
    mkdir -p /etc/supervisor
    echo_supervisord_conf > /etc/supervisor/supervisord.conf

    cat << SUPERVISOR_EOF > "/usr/lib/systemd/system/supervisord.service"
[Unit]
Description=supervisord - Supervisor process control system for UNIX
Documentation=http://supervisord.org
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
ExecReload=/usr/bin/supervisorctl reload
ExecStop=/usr/bin/supervisorctl shutdown
User=root

[Install]
WantedBy=multi-user.target
SUPERVISOR_EOF

    chmod 755 /usr/lib/systemd/system/supervisord.service
    systemctl enable supervisord
}

install_sqlite() {
    yum -y install sqlite-devel sqlite
}

install_postgresql95() {
    # http://tecadmin.net/install-postgresql-9-5-on-centos/
    rpm -Uvh http://yum.postgresql.org/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-2.noarch.rpm

    yum -y install postgresql95-server postgresql95 postgresql95-contrib
    /usr/pgsql-9.5/bin/postgresql95-setup initdb

    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/9.5/data/postgresql.conf

    sed -ir "s/local[[:space:]]*all[[:space:]]*all[[:space:]]*peer/#local     all       all       peer/g"  /var/lib/pgsql/9.5/data/pg_hba.conf

    cat << POSTGRESQL > "/var/lib/pgsql/9.5/data/pg_hba.conf"
# PostgreSQL Client Authentication Configuration File
# ===================================================
#
# Refer to the "Client Authentication" section in the PostgreSQL
# documentation for a complete description of this file.  A short
# synopsis follows.
#
# This file controls: which hosts are allowed to connect, how clients
# are authenticated, which PostgreSQL user names they can use, which
# databases they can access.  Records take one of these forms:
#
# local      DATABASE  USER  METHOD  [OPTIONS]
# host       DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostssl    DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostnossl  DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
#
# (The uppercase items must be replaced by actual values.)
#
# The first field is the connection type: "local" is a Unix-domain
# socket, "host" is either a plain or SSL-encrypted TCP/IP socket,
# "hostssl" is an SSL-encrypted TCP/IP socket, and "hostnossl" is a
# plain TCP/IP socket.
#
# DATABASE can be "all", "sameuser", "samerole", "replication", a
# database name, or a comma-separated list thereof. The "all"
# keyword does not match "replication". Access to replication
# must be enabled in a separate record (see example below).
#
# USER can be "all", a user name, a group name prefixed with "+", or a
# comma-separated list thereof.  In both the DATABASE and USER fields
# you can also write a file name prefixed with "@" to include names
# from a separate file.
#
# ADDRESS specifies the set of hosts the record matches.  It can be a
# host name, or it is made up of an IP address and a CIDR mask that is
# an integer (between 0 and 32 (IPv4) or 128 (IPv6) inclusive) that
# specifies the number of significant bits in the mask.  A host name
# that starts with a dot (.) matches a suffix of the actual host name.
# Alternatively, you can write an IP address and netmask in separate
# columns to specify the set of hosts.  Instead of a CIDR-address, you
# can write "samehost" to match any of the server's own IP addresses,
# or "samenet" to match any address in any subnet that the server is
# directly connected to.
#
# METHOD can be "trust", "reject", "md5", "password", "gss", "sspi",
# "ident", "peer", "pam", "ldap", "radius" or "cert".  Note that
# "password" sends passwords in clear text; "md5" is preferred since
# it sends encrypted passwords.
#
# OPTIONS are a set of options for the authentication in the format
# NAME=VALUE.  The available options depend on the different
# authentication methods -- refer to the "Client Authentication"
# section in the documentation for a list of which options are
# available for which authentication methods.
#
# Database and user names containing spaces, commas, quotes and other
# special characters must be quoted.  Quoting one of the keywords
# "all", "sameuser", "samerole" or "replication" makes the name lose
# its special character, and just match a database or username with
# that name.
#
# This file is read on server startup and when the postmaster receives
# a SIGHUP signal.  If you edit the file on a running system, you have
# to SIGHUP the postmaster for the changes to take effect.  You can
# use "pg_ctl reload" to do that.

# Allow root on the local system to connect to any database with
# any database user name using Unix-domain sockets (the default for local
# connections).
#
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local	all             postgres				trust
local	all             root             			trust
local	homestead	homestead             			md5

# Replication server settings.
local   replication     postgres                                peer
host    replication     postgres        127.0.0.1/32            ident
host    replication     postgres        ::1/128                 ident

# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    homestead	all             127.0.0.1/32            md5
host    homestead	all             ::1/128			md5
host    homestead	all             10.0.0.0/8		md5
host    homestead	all             192.168.0.0/16		md5

POSTGRESQL

    systemctl start postgresql-9.5
    systemctl enable postgresql-9.5

    sudo -u postgres psql -c "CREATE ROLE homestead LOGIN UNENCRYPTED PASSWORD 'secret' SUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;"
    sudo -u postgres /usr/bin/createdb --echo --owner=homestead homestead

    systemctl restart postgresql-9.5
}

install_postgresql95_bdr() {
    echo "TODO look at bdr extension for pg95"
}

install_other() {
    # http://tecadmin.net/install-postgresql-9-5-on-centos/
    yum -y install redis

    systemctl start redis.service
    systemctl enable redis.service
    systemctl restart redis.service

    # install memcache
    yum -y install memcached

    systemctl enable memcached.service
    systemctl start memcached.service
    systemctl restart memcached.service


    # install beanstalk
    yum -y install beanstalkd

    systemctl enable beanstalkd.service
    systemctl start beanstalkd.service
    systemctl restart beanstalkd.service

}

install_php_remi() {
    # https://www.cloudinsidr.com/content/how-to-install-php-7-on-centos-7-red-hat-rhel-7-fedora/

    #rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm

    yum-config-manager --enable remi-php70

    yum -y install \
        php70-php \
        php70-php-cli \
        php70-php-common \
        php70-php-intl \
        php70-php-fpm \
        php70-php-xml \
        php70-php-xmlrpc \
        php70-php-pdo \
        php70-php-gmp \
        php70-php-process \
        php70-php-devel \
        php70-php-mbstring \
        php70-php-mcrypt \
        php70-php-gd \
        php70-php-readline \
        php70-php-pecl-imagick \
        php70-php-opcache \
        php70-php-memcached \
        php70-php-pecl-apcu \
        php70-php-imap \
        php70-php-dba \
        php70-php-enchant \
        php70-php-soap \
        php70-php-pecl-zip \
        php70-php-pecl-jsond \
        php70-php-pecl-jsond-devel \
        php70-php-pecl-xdebug \
        php70-php-bcmath \
        php70-php-mysqlnd \
        php70-php-pgsql \
        php70-php-imap \
        php70-php-pear

    systemctl enable php70-php-fpm

    systemctl start php70-php-fpm

    ln -s /usr/bin/php70 /usr/bin/php

    # Set Some PHP CLI Settings

    sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/opt/remi/php70/php.ini
    sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/opt/remi/php70/php.ini
    sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/opt/remi/php70/php.ini
    sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/opt/remi/php70/php.ini

    # disable xdebug
    sed -i 's/^\(zend_extension.*\)/;\1/' /etc/opt/remi/php70/php.d/15-xdebug.ini


    # Setup Some PHP-FPM Options
    phpfpm='/etc/opt/remi/php70/php.ini'

    # possible to load different php.ini per worker BUT we can Pass environment variables and PHP settings
    # to a pool (worker), which is like loading different php.ini file.
    # see http://stackoverflow.com/questions/20930969/php5-fpm-per-worker-php-ini-file

    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" $phpfpm
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" $phpfpm
    sed -i "s/post_max_size = .*/post_max_size = 100M/" $phpfpm


    # Set The Nginx & PHP-FPM User
#    sed -i "s/user nginx;/user vagrant;/" /etc/nginx/nginx.conf
#    sed -i "s/http {/http {\n    server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
    install_nginx_conf

    # fix differences between centos and ubuntu.
    mkdir -p /etc/nginx/sites-available
    sudo ln -s /etc/nginx/default.d /etc/nginx/sites-enabled


    fpm_pool_www=/etc/opt/remi/php70/php-fpm.d/www.conf

    sed -i "s/user = apache/user = vagrant/" $fpm_pool_www
    sed -i "s/group = apache/group = vagrant/" $fpm_pool_www

    echo "listen.owner = vagrant" >> $fpm_pool_www
    echo "listen.group = vagrant" >> $fpm_pool_www
    echo "listen.mode = 0666" >> $fpm_pool_www


    cat $fpm_pool_www | egrep -v '^;|^[[:space:]]*$'
    systemctl restart nginx
    systemctl restart php70-php-fpm

    # Add Vagrant User To WWW-Data (ubuntu)
    # Add Vagrant User To nginx or apache? (centos)

    usermod -a -G nginx vagrant
    usermod -a -G apache vagrant
    id vagrant
    groups vagrant

    # nginx write error for vagrant (TODO do we really need to run as vagrant??)
    chmod -R g+x /var/lib/nginx

    # systemd links
    # https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files
    # https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units

    #fix different locations used by php-fpm, homestead scripts rely on php70-fpm
    systemctl disable php70-php-fpm
    sed -i 's/\[Install\]/\[Install\]\nAlias=php7.0-fpm.service/' /usr/lib/systemd/system/php70-php-fpm.service
    systemctl enable php70-php-fpm
    # use new alias to restart service (as homestead would).
    systemctl restart php7.0-fpm

    mkdir -p /etc/php/7.0/fpm/
    ln -s /etc/opt/remi/php70/php-fpm.conf /etc/php/7.0/fpm/php-fpm.conf

    # fix different reference to crond to alias as cron
    ln -s /usr/lib/systemd/system/crond.service /etc/systemd/system/cron.service
    sed -i 's/\[Install\]/\[Install\]\nAlias=cron.service/' /etc/systemd/system/multi-user.target.wants/crond.service

}


install_nginx_conf() {

cat << NGINX > /etc/nginx/nginx.conf
user vagrant;
worker_processes auto;
pid /run/nginx.pid;

events {
	worker_connections 768;
	# multi_accept on;
}

http {

	##
	# Basic Settings
	##

	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	# server_tokens off;

	server_names_hash_bucket_size 64;
	# server_name_in_redirect off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	##
	# SSL Settings
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;

	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	##
	# Gzip Settings
	##

	gzip on;
	gzip_disable "msie6";

	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	##
	# Virtual Host Configs
	##

	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}

NGINX
}


install_php_webtatic() {
    #rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm

    yum -y install \
        php70w \
        php70w-cli \
        php70w-common \
        php70w-intl \
        php70w-fpm \
        php70w-xml \
        php70w-pdo \
        php70w-devel \
        php70w-xmlrpc \
        php70w-gd \
        php70w-pecl-imagick
        php70w-opcache \
        php70w-pecl-apcu \
        php70w-imap \
        php70w-mysql \
        php70w-curl \
        php70w-memcached \
        php70w-readline \
        php70w-pecl-xdebug
}

install_composer() {
    # Install Composer

    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer

    cat << COMPOSER_HOME >> /etc/bashrc
# Add Composer Global Bin To Path
export COMPOSER_HOME=~/.composer
export PATH=\$COMPOSER_HOME/vendor/bin:/usr/local/bin:$PATH
COMPOSER_HOME

    /usr/local/bin/composer config --list --global

     # Install Laravel Envoy & Installer
    sudo su - vagrant <<'EOF'
    export COMPOSER_HOME=~/.composer
    /usr/local/bin/composer config --list --global

    /usr/local/bin/composer global require "laravel/envoy=~1.0"
    /usr/local/bin/composer global require "laravel/installer=~1.1"
    /usr/local/bin/composer global require "phing/phing=~2.9"

EOF

     # Install Laravel Envoy & Installer
    export COMPOSER_HOME=~/.composer/
    /usr/local/bin/composer config --list --global

    /usr/local/bin/composer global require "laravel/envoy=~1.0"
    /usr/local/bin/composer global require "laravel/installer=~1.1"
    /usr/local/bin/composer global require "phing/phing=~2.9"

}

install_mysql() {

    # http://www.tecmint.com/install-latest-mysql-on-rhel-centos-and-fedora/
    wget http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
    yum -y localinstall mysql57-community-release-el7-7.noarch.rpm

    # check repos installed.
    yum repolist enabled | grep "mysql.*-community.*"

    yum -y install mysql-community-server

    systemctl enable mysqld.service
    systemctl start mysqld.service

    # Configure Centos Mysql 5.7+

    # http://blog.astaz3l.com/2015/03/03/mysql-install-on-centos/
    echo "default_password_lifetime = 0" >> /etc/my.cnf
    echo "bind-address = 0.0.0.0" >> /etc/my.cnf
    echo "validate_password_policy=LOW" >> /etc/my.cnf
    echo "validate_password_length=6" >> /etc/my.cnf
    systemctl restart mysqld.service

    # find temporary password
    mysql_password=`sudo grep 'temporary password' /var/log/mysqld.log | sed 's/.*localhost: //'`
    mysqladmin -u root -p"$mysql_password" password secret
    mysqladmin -u root -psecret variables | grep validate_password

    mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO root@'0.0.0.0' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
    systemctl restart mysqld.service

    mysql --user="root" --password="secret" -e "CREATE USER 'homestead'@'0.0.0.0' IDENTIFIED BY 'secret';"
    mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO 'homestead'@'0.0.0.0' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
    mysql --user="root" --password="secret" -e "GRANT ALL ON *.* TO 'homestead'@'%' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
    mysql --user="root" --password="secret" -e "FLUSH PRIVILEGES;"
    mysql --user="root" --password="secret" -e "CREATE DATABASE homestead;"
    systemctl restart mysqld.service

    # Add Timezone Support To MySQL
    mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql --user=root --password=secret mysql

}

{
    touch /home/vagrant/.profile && chown vagrant:vagrant /home/vagrant/.profile

    cat << HOMESTEAD_BASH_FIX >> "/home/vagrant/.bash_profile"
# User specific environment and startup programs
PATH=\$PATH:\$HOME/bin

# Homestead fix - incorporate ~/.profile
source ~/.profile
HOMESTEAD_BASH_FIX
}

expand_disk() {
    exit
    # https://ma.ttias.be/increase-expand-xfs-filesystem-in-red-hat-rhel-7-cento7/

    # "/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager" -x 240Gb .vagrant/machines/default/vmware_fusion/*-*-*-*-*/disk.vmdk

    # Steps required to expand the disk
    # fdisk /dev/sda
        # steps taken are :  n, p, 3, enter, enter, t, 3, 8e, w
    # reboot
    # pvcreate /dev/sda3
    # vgextend centos /dev/sda3
    # lvextend /dev/centos/root /dev/sda3
    # xfs_growfs /dev/mapper/centos-root
}


yum_prepare
yum_install
install_supervisor
install_nginx
install_git2
install_node5
install_sqlite
install_postgresql95
install_mysql
install_other
install_php_remi
#install_hhvm
install_composer


