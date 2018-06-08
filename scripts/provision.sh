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
        jq httpie

YUM
}

install_node6() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
    # https://nodejs.org/en/download/package-manager/#enterprise-linux-and-fedora
    sudo su - <<'YUM'
    node -v | grep 'v6' || (
        yum remove -y nodejs npm
        curl --silent --location https://rpm.nodesource.com/setup_6.x | bash -

        # install nodejs and update npm to the latest version.
        yum install -y nodejs

        /usr/bin/npm install -g npm
        /usr/bin/npm install -g gulp
        /usr/bin/npm install -g bower
        /usr/bin/npm install -g yarn
        /usr/bin/npm install -g grunt-cli

    ) && echo "node 6 appears installed.. moving on"
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

install_hhvm() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"
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

install_postgresql95() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # http://tecadmin.net/install-postgresql-9-5-on-centos/
    sudo rpm -Uvh http://yum.postgresql.org/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-2.noarch.rpm || echo 'postgresql95 repo already exists'

    sudo yum -y install postgresql95-server postgresql95 postgresql95-contrib
}


configure_postgresql95() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    sudo /usr/pgsql-9.5/bin/postgresql95-setup initdb && ( \

        sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/9.5/data/postgresql.conf

        sudo sed -ir "s/local[[:space:]]*all[[:space:]]*all[[:space:]]*peer/#local     all       all       peer/g"  /var/lib/pgsql/9.5/data/pg_hba.conf

        sudo cat << POSTGRESQL > "/var/lib/pgsql/9.5/data/pg_hba.conf"
# PostgreSQL Client Authentication Configuration File
# ===================================================

# TYPE  DATABASE        USER            ADDRESS                 METHOD
local	all             postgres		                        trust
local	all             root                                    trust
local	homestead	    homestead                               md5

# Replication server settings.
local   replication     postgres                                peer
host    replication     postgres        127.0.0.1/32            ident
host    replication     postgres        ::1/128                 ident

# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    homestead	    all             127.0.0.1/32            md5
host    homestead	    all             ::1/128			        md5
host    homestead	    all             10.0.0.0/8		        md5
host    homestead	    all             192.168.0.0/16		    md5

POSTGRESQL
    ) || echo ""
    sudo systemctl start postgresql-9.5
    sudo systemctl enable postgresql-9.5

    sudo -u postgres psql -c "CREATE ROLE homestead LOGIN UNENCRYPTED PASSWORD 'secret' SUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;" || echo 'homestead role already exists'
    sudo -u postgres /usr/bin/createdb --echo --owner=homestead homestead || echo 'homestead DB already exists'

    sudo systemctl restart postgresql-9.5
}

install_postgresql95_bdr() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    echo "TODO look at bdr extension for pg95"
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

    [ -h /usr/bin/php70-pecl ] && rm -f /usr/bin/php70-pecl
    ln -s /opt/remi/php${PHP_VERSION}/root/usr/bin/pecl /usr/bin/php70-pecl

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



install_php_webtatic() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    #rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    sudo rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm

    sudo yum -y install \
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
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # Install Composer

    sudo su - << COMPOSER
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer

    cat << COMPOSER_HOME >> /etc/bashrc
# Add Composer Global Bin To Path
export COMPOSER_HOME=~/.composer
export PATH=\$COMPOSER_HOME/vendor/bin:/usr/local/bin:\$PATH
COMPOSER_HOME

    # Install Laravel Envoy & Installer
    export COMPOSER_HOME=~/.composer/
    /usr/local/bin/composer config --list --global

    /usr/local/bin/composer global require "laravel/envoy=~1.0"
    /usr/local/bin/composer global require "laravel/installer=~1.1"
    /usr/local/bin/composer global require "phing/phing=~2.9"
COMPOSER

    /usr/local/bin/composer config --list --global

     # Install Laravel Envoy & Installer
    sudo su - vagrant <<EOF
    export COMPOSER_HOME=~/.composer
    /usr/local/bin/composer config --list --global

    /usr/local/bin/composer global require "laravel/envoy=~1.0"
    /usr/local/bin/composer global require "laravel/installer=~1.1"
    /usr/local/bin/composer global require "phing/phing=~2.9"

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

expand_disk() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    echo "Manual process for disc resizing - please read comments"
    exit
    # Rather than building a new bento/centos-7.2 box with larger disc we will modify existing.

    # https://ma.ttias.be/increase-expand-xfs-filesystem-in-red-hat-rhel-7-cento7/

    # "/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager" -x 240Gb .vagrant/machines/default/vmware_fusion/*-*-*-*-*/disk.vmdk

    # Steps required to expand the disk
    # fdisk /dev/sda
        # steps taken are :  n, p, 3, enter, enter, t, 3, 8e, w
    # reboot
    # pvcreate /dev/sda3

    # Centos7 -
    # vgextend centos /dev/sda3
    # lvextend /dev/centos/root /dev/sda3
    # xfs_growfs /dev/mapper/centos-root

    # Centos5 - https://ma.ttias.be/increase-a-vmware-disk-size-vmdk-formatted-as-linux-lvm-without-rebooting/
    # vgextend VolGroup00 /dev/sda3
    #

fdisk /dev/sda <<EOF
n
p
3


t
3
8e
w
EOF
    pvcreate /dev/sda3
    vlg=$(vgdisplay | grep 'VG Name'| sed 's/[[:space:]]//g' | sed 's/VGName//')
    vgextend $vlg /dev/sda3
    pvscan
    lvextend /dev/${vlg}/LogVol00 /dev/sda3
    resize2fs /dev/${vlg}/LogVol00

}
expand_disk_virtualbox() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    echo "Manual process for disc resizing - please read comments"
    exit
    # Rather than building a new bento/centos-7.2 box with larger disc we will modify existing.

    # http://stackoverflow.com/questions/11659005/how-to-resize-a-virtualbox-vmdk-file
    #buildvm=`ls ~/VirtualBox\ VMs/ | grep $(basename $(pwd))`
    #pushd ~/VirtualBox\ VMs/${buildvm}
    #VBoxManage clonehd *.vmdk "cloned.vdi" --format vdi
    #VBoxManage modifyhd "cloned.vdi" --resize 286720
    #VBoxManage clonehd cloned.vdi centos-7.2-x86_64-disk_1.vmdk --format vmdk
    # Manually remove old HD (*disk1.vmdk) and and new HD (*disk_1.vmdk)

    # Steps required to expand the disk
    # fdisk /dev/sda
        # steps taken are :  n, p, 3, enter, enter, t, 3, 8e, w
    # reboot
    # pvcreate /dev/sda3
    # vgextend centos /dev/sda3
    # lvextend /dev/centos/root /dev/sda3
    # xfs_growfs /dev/mapper/centos-root
}

install_yum_updates_1() {
    echo -e "\n${FUNCNAME[ 0 ]}()\n"

    # updates to base OS
    sudo yum -y install bind-utils traceroute cyrus-sasl-plain supervisor netcat

    # add mail command for system management.
    sudo yum -y install mailx mutt

    # Add postgres contribution extensions
    sudo yum -y install postgresql95-contrib

    # update php install php-imagick and ensure mod_ssl
    sudo yum -y install php-imagick mod_ssl httpd

    # Fix small file cache issue on vagrant mounts - http://stackoverflow.com/questions/6298933/shared-folder-in-virtualbox-for-apache
    sed -i 's/^EnableSendfile on/EnableSendfile off/'  /etc/httpd/conf/httpd.conf
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
install_node6
install_nginx

install_php_remi
configure_php_remi
#install_hhvm
install_composer
install_git2

install_sqlite

install_postgresql95
configure_postgresql95

install_mysql
configure_mysql

install_cache_queue
configure_cache_queue

install_yum_updates_1

finish_build_meta
set -u
