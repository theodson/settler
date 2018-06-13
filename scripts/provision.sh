#!/usr/bin/env bash
set -e
set +u

if [ $# -gt 0 ] && [ $1 = "config" ]; then
    CONFIG_ONLY=1
fi

yum_prepare() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    # To add the CentOS 7 EPEL repository, open terminal and use the following command:
    sudo su - <<'YUM'
    yum -y install epel-release
    yum -y install yum-priorities yum-utils yum-plugin-versionlock yum-plugin-show-leaves yum-plugin-upgrade-helper deltarpm

	yum clean dbcache expire-cache
	yum makecache fast

    # ensure build tools are installed.
    yum -y group install 'Development Tools'

    # (info) to mark a group as being non-installed use - yum groups mark-remove install "Development Tools"

    yum -y update
YUM
}

yum_install() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    sudo su - <<'YUM'
    yum -y install autoconf make automake sendmail sendmail-cf m4 virt-what \
        vim mlocate curl htop wget dos2unix tree \
        ntp nmap nc whois libnotify inotify-tools telnet ngrep bind-utils traceroute \
        cyrus-sasl-plain supervisor mailx mutt netcat \
        bash-completion-extras mcrypt vim cifs-utils zsh re2c pv \
        jq httpie mod_ssl httpd ntpdate

    # Fix small file cache issue on vagrant mounts - http://stackoverflow.com/questions/6298933/shared-folder-in-virtualbox-for-apache
    sed -i 's/^EnableSendfile on/EnableSendfile off/'  /etc/httpd/conf/httpd.conf
YUM

}

install_node() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    # https://nodejs.org/en/download/package-manager/#enterprise-linux-and-fedora
    sudo su - <<'YUM'
    nv=9
    node -v | grep "v${nv}" || (
        find /etc/yum.repos.d/ -type f -name 'node*' | xargs rm -f {} && \
        curl --silent --location https://rpm.nodesource.com/setup_${nv}.x | sudo bash - && \
        yum remove -y nodejs npm && yum clean all && yum install -y nodejs

        # install nodejs and update npm to the latest version.
        yum install -y nodejs

        /usr/bin/npm install -g npm
        /usr/bin/npm install -g gulp-cli
        /usr/bin/npm install -g bower
        /usr/bin/npm install -g yarn
        /usr/bin/npm install -g grunt-cli

    ) && echo "node ${nv} appears installed.. moving on"
YUM
}

install_git2() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    # http://tecadmin.net/install-git-2-0-on-centos-rhel-fedora/
    sudo su - <<'EOF'
        git --version 2> /dev/null | grep '2.9' || \
        (
	v=2.9.5
        yum remove -y git && \
        yum install -y perl-Tk-devel curl-devel expat-devel openssl-devel zlib-devel && \
        pushd /usr/src && \
        wget "https://www.kernel.org/pub/software/scm/git/git-$v.tar.gz" && \
        tar -xvf "git-$v.tar.gz" && \
        pushd "git-$v" && \
        make prefix=/usr/local/git all && \
        make prefix=/usr/local/git install && \
        echo "export PATH=\$PATH:/usr/local/git/bin" >> /etc/bashrc && \
        source /etc/bashrc && \
        echo "Installation of git-$v complete" )
EOF
    source /etc/bashrc
}

install_nginx() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    # https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-centos-7
    sudo su - <<'YUM'
    yum install -y nginx

    systemctl enable nginx
    systemctl start nginx

    systemctl start firewalld

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
YUM

}

install_supervisor() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # install supervisor
    # http://vicendominguez.blogspot.com.au/2015/02/supervisord-in-centos-7-systemd-version.html
    # http://www.alphadevx.com/a/455-Installing-Supervisor-and-Superlance-on-CentOS
        sudo su - <<'SUPERVISOR'
    sudo yum install -y python-setuptools python-pip
    sudo easy_install supervisor

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

SUPERVISOR

}

install_sqlite() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    sudo yum -y install sqlite-devel sqlite
}

install_postgresql10() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    sudo rpm -Uvh http://yum.postgresql.org/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm || echo 'postgresql10 repo already exists'

    sudo yum -y install postgresql10-server postgresql10 postgresql10-contrib
}


configure_postgresql10() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    PGDG_VERSION=10

    sudo su - <<POSTGRESQL10
    /usr/pgsql-${PGDG_VERSION}/bin/postgresql-${PGDG_VERSION}-setup initdb && ( \

        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/${PGDG_VERSION}/data/postgresql.conf

        sed -ir "s/local[[:space:]]*all[[:space:]]*all[[:space:]]*peer/#local     all       all       peer/g"  /var/lib/pgsql/${PGDG_VERSION}/data/pg_hba.conf

        cat << POSTGRESQL > "/var/lib/pgsql/${PGDG_VERSION}/data/pg_hba.conf"
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
# METHOD can be "trust", "reject", "md5", "password", "scram-sha-256",
# "gss", "sspi", "ident", "peer", "pam", "ldap", "radius" or "cert".
# Note that "password" sends passwords in clear text; "md5" or
# "scram-sha-256" are preferred since they send encrypted passwords.
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
# This file is read on server startup and when the server receives a
# SIGHUP signal.  If you edit the file on a running system, you have to
# SIGHUP the server for the changes to take effect, run "pg_ctl reload",
# or execute "SELECT pg_reload_conf()".
#
# Put your actual configuration here
# ----------------------------------
#
# If you want to allow non-local connections, you need to add more
# "host" records.  In that case you will also need to make PostgreSQL
# listen on a non-local interface via the listen_addresses
# configuration parameter, or via the -i or -h command line switches.



# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            ident
# IPv6 local connections:
host    all             all             ::1/128                 ident
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            ident
host    replication     all             ::1/128                 ident

# Homestead
host    all             all             10.0.2.2/32               md5

POSTGRESQL
    ) || echo ""
    systemctl start postgresql-${PGDG_VERSION}
    systemctl enable postgresql-${PGDG_VERSION}

    pushd /tmp && sudo -u postgres psql -c "CREATE ROLE homestead LOGIN PASSWORD 'secret' SUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;" 2>/dev/null || echo 'homestead role already exists'
    sudo -u postgres /usr/bin/createdb --echo --owner=homestead homestead || echo 'homestead DB already exists'

    systemctl restart postgresql-${PGDG_VERSION}
POSTGRESQL10
}


install_cache_queue() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # http://tecadmin.net/install-postgresql-9-5-on-centos/
    sudo yum -y install redis

    # install memcache
    sudo yum -y install memcached

    # install beanstalk
    sudo yum -y install beanstalkd
}

configure_cache_queue() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # configure redis
    sudo systemctl start redis.service
    sudo systemctl enable redis.service
    sudo systemctl restart redis.service

    # configure memcache
    sudo systemctl enable memcached.service
    sudo systemctl start memcached.service
    sudo systemctl restart memcached.service

    # configure beanstalk
    sudo systemctl enable beanstalkd.service
    sudo systemctl start beanstalkd.service
    sudo systemctl restart beanstalkd.service

}


install_php_remi() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # https://www.cloudinsidr.com/content/how-to-install-php-7-on-centos-7-red-hat-rhel-7-fedora/

    #rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    sudo rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm || echo "Repo already installed....continuing"

    sudo yum-config-manager --disable remi-php70
    sudo yum-config-manager --disable remi-php71
    sudo yum-config-manager --enable remi-php72

    sudo yum --enablerepo=remi-php72 install -y php72-php-xml php72-php-soap php72-php-xmlrpc php72-php-mbstring php72-php-json php72-php-gd php72-php-mcrypt \
        php72-php-cli \
        php72-php-common \
        php72-php-intl \
        php72-php-fpm \
        php72-php-xml \
        php72-php-xmlrpc \
        php72-php-pdo \
        php72-php-gmp \
        php72-php-process \
        php72-php-devel \
        php72-php-mbstring \
        php72-php-pecl-mcrypt \
        php72-php-gd \
        php72-php-readline \
        php72-php-pecl-imagick \
        php72-php-opcache \
        php72-php-memcached \
        php72-php-pecl-apcu \
        php72-php-imap \
        php72-php-dba \
        php72-php-enchant \
        php72-php-soap \
        php72-php-pecl-zip \
        php72-php-pecl-jsond \
        php72-php-pecl-jsond-devel \
        php72-php-pecl-xdebug \
        php72-php-bcmath \
        php72-php-mysqlnd \
        php72-php-pgsql \
        php72-php-imap \
        php72-php-pear

}


configure_php_remi() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    PHP_DOT_VERSION=7.2
    PHP_VERSION=72
    # phpfpm="$(php -i | grep 'Loaded Configuration File' | cut -d '>' -f 2- | xargs)"
    phpfpm="/etc/opt/remi/php${PHP_VERSION}/php.ini"
    sudo su - <<PHP

    # Setup Some PHP-FPM Options
    phpfpm='$phpfpm'

    yum-config-manager --enable remi-php${PHP_VERSION}

    systemctl enable php${PHP_VERSION}-php-fpm
    systemctl start php${PHP_VERSION}-php-fpm

    [ -h /usr/bin/php ] && rm -f /usr/bin/php
    ln -s /usr/bin/php${PHP_VERSION} /usr/bin/php || echo 'php already exists ..moving on!'

    [ -h /usr/bin/pear ] && rm -f /usr/bin/pear
    ln -s /usr/bin/php${PHP_VERSION}-pear /usr/bin/pear

    [ -h /usr/bin/phar ] && rm -f /usr/bin/phar
    ln -s /usr/bin/php${PHP_VERSION}-phar /usr/bin/phar

    [ -h /usr/bin/php${PHP_VERSION}-pecl ] && rm -f /usr/bin/php${PHP_VERSION}-pecl
    ln -s /opt/remi/php${PHP_VERSION}/root/usr/bin/pecl /usr/bin/php${PHP_VERSION}-pecl

    [ -h /usr/bin/pecl ] && rm -f /usr/bin/pecl
    ln -s /usr/bin/php${PHP_VERSION}-pecl /usr/bin/pecl

    # install xdebug, port 10000 to avoid clash with phpfpm
    cat << EOF >> $phpfpm
xdebug.max_nesting_level=250
xdebug.remote_enable=1
;xdebug.remote_host="YOUR CLIENT DEV IP ADDRESS"
xdebug.remote_host="127.0.0.1"
xdebug.remote_port=10000
xdebug.idekey="PHPSTORM"
EOF



    # Set Some PHP CLI Settings
    sed -i "s/error_reporting = .*/error_reporting = E_ALL/" $phpfpm
    sed -i "s/display_errors = .*/display_errors = On/" $phpfpm
    sed -i "s/memory_limit = .*/memory_limit = 512M/" $phpfpm
    sed -i "s/;date.timezone.*/date.timezone = UTC/" $phpfpm

    # possible to load different php.ini per worker BUT we can Pass environment variables and PHP settings
    # to a pool (worker), which is like loading different php.ini file.
    # see http://stackoverflow.com/questions/20930969/php5-fpm-per-worker-php-ini-file

    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" $phpfpm
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" $phpfpm
    sed -i "s/post_max_size = .*/post_max_size = 100M/" $phpfpm

    # disable xdebug
    sed -i 's/^\(zend_extension.*\)/;\1/' /etc/opt/remi/php${PHP_VERSION}/php.d/15-xdebug.ini

PHP

    # Set The Nginx & PHP-FPM User
    #    sed -i "s/user nginx;/user vagrant;/" /etc/nginx/nginx.conf
    #    sed -i "s/http {/http {\n    server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
    sudo su - <<EOF
    cat << NGINX > /etc/nginx/nginx.conf
user vagrant;
worker_processes auto;
pid /run/nginx.pid;

events {
	worker_connections 768;
	# multi_accept on;
}

http {
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

	# SSL Settings
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;

	# Logging Settings
	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	# Gzip Settings
	gzip on;
	gzip_disable "msie6";

	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	# Virtual Host Configs
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}
NGINX
EOF

    # As Homestead is based on Ubuntu we need to fix differences between CentOS and Ubuntu.
    fpm_pool_www="/etc/opt/remi/php${PHP_VERSION}/php-fpm.d/www.conf"
    sudo su - << NGINXDIFF

    rm -rf /etc/nginx/{default.d,sites-enabled}
    mkdir -p /etc/nginx/{sites-available,sites-enabled,default.d}

    sed -i "s/user = apache/user = vagrant/" $fpm_pool_www
    sed -i "s/group = apache/group = vagrant/" $fpm_pool_www

    grep 'listen.owner = vagrant' $fpm_pool_www || echo "listen.owner = vagrant" >> $fpm_pool_www
    grep 'listen.group = vagrant' $fpm_pool_www || echo "listen.group = vagrant" >> $fpm_pool_www
    grep 'listen.mode = 0666' $fpm_pool_www || echo "listen.mode = 0666" >> $fpm_pool_www

    cat $fpm_pool_www | egrep -v '^;|^[[:space:]]*$'
    systemctl restart nginx
    systemctl restart php${PHP_VERSION}-php-fpm

    # Add Vagrant User To WWW-Data (ubuntu)
    # Add Vagrant User To nginx or apache? (centos)

    usermod -a -G nginx vagrant
    usermod -a -G apache vagrant
NGINXDIFF
    id vagrant
    groups vagrant

    sudo su - << SERVICES
    # nginx write error for vagrant (TODO do we really need to run as vagrant??)
    chmod -R g+x /var/lib/nginx

    # systemd links
    # https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files
    # https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units

    # Homestead scripts rely on different systemd names in Ubuntu compared to CentOS - add Aliases for CentOS.

    # fix different locations used by php-fpm, Homestead scripts rely on php${PHP_VERSION}-fpm
    systemctl disable php${PHP_VERSION}-php-fpm
    sed -i 's/\[Install\]/\[Install\]\nAlias=php${PHP_DOT_VERSION}-fpm.service/' /usr/lib/systemd/system/php${PHP_VERSION}-php-fpm.service
    systemctl enable php${PHP_VERSION}-php-fpm

    # use new alias to restart service (as homestead would).
    systemctl restart php${PHP_DOT_VERSION}-fpm

    mkdir -p /etc/php/${PHP_DOT_VERSION}/fpm/
    ln -fs /etc/opt/remi/php${PHP_VERSION}/php-fpm.conf /etc/php/${PHP_DOT_VERSION}/fpm/php-fpm.conf

    # fix different reference to crond to alias as cron
    ln -fs /usr/lib/systemd/system/crond.service /etc/systemd/system/cron.service
    sed -i 's/\[Install\]/\[Install\]\nAlias=cron.service/' /etc/systemd/system/multi-user.target.wants/crond.service
    systemctl status cron.service
SERVICES

}

install_composer() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # Install Composer

    sudo su - << COMPOSER
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer

    cat << COMPOSER_HOME >> /etc/bashrc
# Add Composer Global Bin To Path
export PATH=~/.composer/vendor/bin:/usr/local/bin:\$PATH
COMPOSER_HOME

    # Install Laravel Envoy & Installer
    export COMPOSER_HOME=~/.composer/
    /usr/local/bin/composer config --list --global

    /usr/local/bin/composer global require "laravel/envoy=~1.0"
    /usr/local/bin/composer global require "laravel/installer=~1.1"
    /usr/local/bin/composer global require "laravel/lumen-installer=~1.0"
    /usr/local/bin/composer global require "laravel/spark-installer=~2.0"
    /usr/local/bin/composer global require "drush/drush=~8"
    /usr/local/bin/composer global require "phing/phing"
COMPOSER

    /usr/local/bin/composer config --list --global

     # Install Laravel Envoy & Installer
    sudo su - vagrant <<EOF
    export COMPOSER_HOME=~/.composer
    /usr/local/bin/composer config --list --global

    /usr/local/bin/composer global require "laravel/envoy=~1.0"
    /usr/local/bin/composer global require "laravel/installer=~1.1"
    /usr/local/bin/composer global require "laravel/lumen-installer=~1.0"
    /usr/local/bin/composer global require "laravel/spark-installer=~2.0"
    /usr/local/bin/composer global require "drush/drush=~8"
    /usr/local/bin/composer global require "phing/phing"

EOF

}

install_mysql() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # http://www.tecmint.com/install-latest-mysql-on-rhel-centos-and-fedora/
    wget http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
    yum -y localinstall mysql57-community-release-el7-7.noarch.rpm

    # check repos installed.
    yum repolist enabled | grep "mysql.*-community.*"

    yum -y install mysql-community-server
}

configure_mysql() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

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

install_blackfire() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    sudo yum -y install pygpgme
    wget -O - "http://packages.blackfire.io/fedora/blackfire.repo" | sudo tee /etc/yum.repos.d/blackfire.repo
    sudo yum -y install blackfire-agent blackfire-php
}

install_mailhog() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    sudo su - << MAILHOG
    wget --quiet -O /usr/local/bin/mailhog https://github.com/mailhog/MailHog/releases/download/v0.2.1/MailHog_linux_amd64
    chmod +x /usr/local/bin/mailhog
    tee /etc/systemd/system/mailhog.service <<EOL
[Unit]
Description=Mailhog
After=network.target
[Service]
User=vagrant
ExecStart=/usr/bin/env /usr/local/bin/mailhog > /dev/null 2>&1 &
[Install]
WantedBy=multi-user.target
EOL
    systemctl daemon-reload
    systemctl enable mailhog
MAILHOG
}

install_ngrok() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
    unzip ngrok-stable-linux-amd64.zip -d /usr/local/bin
    rm -rf ngrok-stable-linux-amd64.zip
}

install_flyway() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    wget https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/4.2.0/flyway-commandline-4.2.0-linux-x64.tar.gz
    tar -zxvf flyway-commandline-4.2.0-linux-x64.tar.gz -C /usr/local
    [ ! -e /usr/local/bin/flyway ] && ln -s /usr/local/flyway-4.2.0/flyway /usr/local/bin/flyway || echo 'flyway already installed'
    chmod +x /usr/local/flyway-4.2.0/flyway
    rm -rf flyway-commandline-4.2.0-linux-x64.tar.gz
}

install_wp_cli() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    sudo su - << WPCLI
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    [ ! -e /usr/local/bin/wp ] && mv wp-cli.phar /usr/local/bin/wp || echo 'WP-CLI already installed'
WPCLI
}


install_oh_my_zsh() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    sudo su - << MYZSH
    git clone git://github.com/robbyrussell/oh-my-zsh.git /home/vagrant/.oh-my-zsh
    cp /home/vagrant/.oh-my-zsh/templates/zshrc.zsh-template /home/vagrant/.zshrc
    printf "\nsource ~/.bash_aliases\n" | tee -a /home/vagrant/.zshrc
    printf "\nsource ~/.profile\n" | tee -a /home/vagrant/.zshrc
    chown -R vagrant:vagrant /home/vagrant/.oh-my-zsh
    chown vagrant:vagrant /home/vagrant/.zshrc
MYZSH
}

install_browsershot_dependencies() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    # install puppeteer
    sudo npm install --global --unsafe-perm puppeteer

    # NOTES
    # https://chromium.googlesource.com/native_client/src/native_client.git/+/master/docs/linux_outer_sandbox.md
    # https://forum.unity.com/threads/why-does-chrome-sandbox-need-root-rights-suid-set.365818/
    # https://github.com/GoogleChrome/puppeteer/issues/391
    # https://github.com/GoogleChrome/puppeteer/blob/master/docs/troubleshooting.md

    # Suggested puppeteer Ubuntu libraries required
    # ca-certificates fonts-liberation gconf-service libappindicator libasound libatk libc libcairo libcups libdbus libexpat libfontconfig libgcc libgconf libgdk-pixbuf libglib libgtk libnspr libnss libpango libpangocairo libstdc++ libx libx11-xcb libxcb libxcomposite libxcursor libxdamage libxext libxfixes libxi libxrandr libxrender libxss libxtst lsb-release nodejs wget xdg-utils

    # UBUNTU MISSING LIBS - fonts-liberation gconf-service libasound libatk libc libcairo libcups libdbus libexpat libfontconfig libgconf libgdk-pixbuf libglib libgtk libnspr libnss libpango libpangocairo libx libx11-xcb libxss lsb-release

    # EQUIVALENT RHEL LIBS - liberation-fonts-common alsa-lib atk cairo cups-libs fontconfig GConf2 gdk-pixbuf2 glib2 gtk3 nspr pango libX11 redhat-lsb-core glibc dbus-libs expat nss libXScrnSaver

    sudo yum install -y \
         ipa-gothic-fonts xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi xorg-x11-utils xorg-x11-fonts-cyrillic xorg-x11-fonts-Type1 xorg-x11-fonts-misc \
         at-spi2-atk libXtst liberation-fonts-common alsa-lib atk cairo cups-libs fontconfig GConf2 gdk-pixbuf2 glib2 gtk3 nspr pango libX11 redhat-lsb-core glibc dbus-libs expat nss libXScrnSaver

# libxpm4 libxrender1 libgtk2.0-0 \
# libnss3 libgconf-2-4 chromium-browser \
# xvfb gtk2-engines-pixbuf xfonts-cyrillic \
# xfonts-100dpi xfonts-75dpi xfonts-base \
# xfonts-scalable imagemagick x11-apps


    # SANDBOX ISSUE -  no solution on Virtualized CENTOS/RHEL run
    # https://github.com/GoogleChrome/puppeteer/blob/master/docs/troubleshooting.md
    # Use the Spatie ->noSandbox()` option

    CHROME_DEVEL_SANDBOX="/usr/lib/node_modules/puppeteer/.local-chromium/linux-*/chrome-linux/chrome_sandbox"
    sudo chown root $CHROME_DEVEL_SANDBOX
    sudo chmod u+s,a+rx,g+rx $CHROME_DEVEL_SANDBOX
    sudo chmod a+rx,g+rx ${CHROME_DEVEL_SANDBOX%/*}/chrome
    sudo chmod u+r,a+r -R ${CHROME_DEVEL_SANDBOX%/*}
}

install_zend_zray() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    echo 'skipping zend zray - conficting libssl dependency'
    return 0;

    # Install Zend Z-Ray -
    # doesnt work in centos 7 due to openssl libssl 1.0.0 dependency - co7 use 1.0.2

    sudo wget http://repos.zend.com/zend-server/early-access/ZRay-Homestead/zray-standalone-php72.tar.gz -O - | sudo tar -xzf - -C /opt
    sudo ln -sf /opt/zray/zray.ini /etc/php/7.2/cli/conf.d/zray.ini
    sudo ln -sf /opt/zray/zray.ini /etc/php/7.2/fpm/conf.d/zray.ini
    sudo ln -sf /opt/zray/lib/zray.so /usr/lib/php/20170718/zray.so
    sudo chown -R vagrant:vagrant /opt/zray
}

install_pghashlib() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    PGVER=10
    PGVER_DEVEL_LIB="postgresql$(echo $PGVER | tr -d '.')-devel"
    PGLIB="/usr/pgsql-${PGVER}"
    sudo su - << PGHASHLIB
        pushd /tmp/ &&
        wget --quiet https://github.com/markokr/pghashlib/archive/master.zip -O pghashlib.zip \
        && rm -rf pghashlib-master \
        && unzip pghashlib.zip \
        && cd pghashlib-master \
        && yum install -y $PGVER_DEVEL_LIB \
        && PG_PATH=($PGLIB/bin/) \
        && echo "PATH=$PATH:\$PG_PATH" >> ~/.bashrc \
        && source ~/.bashrc \
        && make \
        && [[ -f hashlib.html ]] || cp README.rst hashlib.html \
        && chown $(whoami) ${PGLIB}/lib/ \
        && chown $(whoami) ${PGLIB}/share/extension \
        && chown $(whoami) ${PGLIB}/doc/extension \
        && make install \
        && cd .. \
        && rm -rf pghashlib-master \
        && rm -f pghashlib.zip
PGHASHLIB
}

install_golang() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    # Install Golang
    GO_VERSION='1.10'
    sudo su - << GOLANG
    wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz  -O - | tar -xz -C /usr/local
    echo "export PATH=/usr/local/go/bin:\$PATH" >> /etc/bashrc
    touch /home/vagrant/.profile && echo "export PATH=/usr/local/go/bin:\$PATH" >> /home/vagrant/.profile
GOLANG
}

install_postfix() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    # Install & Configure Postfix
    FQDN='homestead.test'
    sudo su - << POSTFIX
    echo "myhostname = ${FQDN}" >> /etc/postfix/main.cf
    yum install -y postfix &&
        systemctl disable sendmail &&
        systemctl stop sendmail

    grep '^relayhost' /etc/postfix/main.cf \
        && (echo 'relayhost appears to be configured already - will comment out' \
        && sed -i 's/^relayhost/#relayhost/g' /etc/postfix/main.cf)

    echo "relayhost = [localhost]:1025" >> /etc/postfix/main.cf && echo "postfix configured to send mail to localhost MailHog"

    touch /etc/postfix/sasl_passwd.db
    sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
    sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

    systemctl restart postfix
POSTFIX
}

configure_postfix_for_sendgrid() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    USERNAME=${1:-username}
    PASSWORD=${2:-password}
    sudo su - << POSTFIX
    grep '^relayhost' /etc/postfix/main.cf \
        && (echo 'relayhost appears to be configured already - will comment out' \
        && sed -i 's/^relayhost/#relayhost/g' /etc/postfix/main.cf)

    cat << POSTFIX_SENDGRID >> /etc/postfix/main.cf
# SendGrid - Configuration - START
relayhost = [smtp.sendgrid.net]:587

smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_sasl_tls_security_options = noanonymous
smtp_tls_security_level = encrypt
header_size_limit = 4096000

# SendGrid - Configuration - END
POSTFIX_SENDGRID

    # comment out any existing credentials
    sed -i 's/^\[smtp.sendgrid/#\[smtp.sendgrid/g' /etc/postfix/sasl_passwd
    echo "[smtp.sendgrid.net]:587 $USERNAME:$PASSWORD" >> /etc/postfix/sasl_passwd

    # build passwords
    postmap /etc/postfix/sasl_passwd

    sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
    sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

    systemctl restart postfix


POSTFIX

 # echo "Test Email from - $(hostname)" | mail -s "Test Email - ($(date))" -r "$(whoami)@$(hostname)" test@gmail.com
}

generate_chromium_test_script() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    cat << SCRIPT >> test_chromium.sh
#!/bin/bash

VALUE=$(cat /boot/config-$(uname -r) | grep CONFIG_USER_NS)

if [[ -z "$VALUE" ]]
then
  echo 'You do not have namespacing in the kernel. You will need to enable the SUID sandbox or upgrade your kernel.';
  exit 1
fi

USER_NS_AVAILABLE="${VALUE: -1}"

if [[ "$USER_NS_AVAILABLE" -eq "y" ]]
then
  echo 'You have user namespacing in the kernel. You should be good to go.';
  exit 0
else
  echo 'You do not have namespacing in the kernel. You will need to enable the SUID sandbox or upgrade your kernel.';
  exit 1
fi
SCRIPT
}

finish_build_meta() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    date >> ~/build.info
}

set_profile() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    touch /home/vagrant/.profile && chown vagrant:vagrant /home/vagrant/.profile

    cat << HOMESTEAD_BASH_FIX >> "/home/vagrant/.bash_profile"
# User specific environment and startup programs
PATH=\$PATH:\$HOME/bin

# Homestead fix - incorporate ~/.profile
source ~/.profile
HOMESTEAD_BASH_FIX
}


# packer set nounset on -u, turn it off for our script as CONFIG_ONLY may not be defined
set +u
set_profile

yum_prepare
yum_install

#install_supervisor
install_node
install_nginx

install_php_remi
configure_php_remi
install_composer
install_git2

install_sqlite

install_postgresql10
install_pghashlib
configure_postgresql10

install_mysql
configure_mysql

install_cache_queue
configure_cache_queue

install_blackfire
install_mailhog
install_ngrok
install_flyway
install_wp_cli
install_oh_my_zsh
install_browsershot_dependencies
install_zend_zray # not compatible with centos7 - libssl clash
install_golang
install_postfix
# configure_postfix_for_sendgrid $sendgrid_user $sendgrid_pass
finish_build_meta
set -u
