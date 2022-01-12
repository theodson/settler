#!/usr/bin/env bash
#
# collection of functions used to build server for homestead
#
yum_cleanup() {
    yum clean all && rm -rf /var/cache/yum/* || true
}

yum_prepare() {
  echo -e "\n${FUNCNAME[0]}()\n"
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
  echo -e "\n${FUNCNAME[0]}()\n"
  sudo su - <<'YUM'
    yum -y install autoconf make automake sendmail sendmail-cf m4 virt-what \
        vim mlocate curl htop wget dos2unix tree \
        ntp nmap nc whois libnotify inotify-tools telnet ngrep bind-utils traceroute \
        cyrus-sasl-plain supervisor mailx mutt netcat \
        bash-completion-extras mcrypt vim cifs-utils zsh re2c pv \
        jq httpie mod_ssl httpd ntpdate poppler-utils

    # Fix small file cache issue on vagrant mounts - http://stackoverflow.com/questions/6298933/shared-folder-in-virtualbox-for-apache
    sed -i 's/^EnableSendfile on/EnableSendfile off/'  /etc/httpd/conf/httpd.conf
YUM

  sudo su - <<SERVICES
    # systemd links
    # https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files
    # https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units

    # Homestead scripts rely on different systemd names in Ubuntu compared to CentOS - add Aliases for CentOS.
    # Fix different reference to crond to alias as cron (Ubuntu uses cron)

    rm -f /etc/systemd/system/multi-user.target.wants/crond.service || echo '..'
    [ -e /usr/lib/systemd/system/crond.service ] && ln -fs /usr/lib/systemd/system/crond.service /etc/systemd/system/multi-user.target.wants/crond.service
    [ -e /usr/lib/systemd/system/crond.service ] && ln -fs /usr/lib/systemd/system/crond.service /etc/systemd/system/cron.service

    grep '^Alias=cron.service' /etc/systemd/system/multi-user.target.wants/crond.service &>/dev/null || sed -i 's/\[Install\]/\[Install\]\nAlias=cron.service/' /etc/systemd/system/multi-user.target.wants/crond.service

    systemctl daemon-reload
    systemctl status cron.service

    echo 'export HISTTIMEFORMAT="%Y-%m-%d - %H:%M:%S "' >> /etc/profile
SERVICES

}

upgrade_node() {
    echo -e "\n${FUNCNAME[0]}()\n"
    # easier to use NVM
    sudo su - <<'NODE'
    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
    . /root/.bashrc
    nvm install 9 --lts
    nvm install 10 --lts
    nvm install 14 --lts
    nvm install stable
    nvm install 16 --lts --default
    nvm install-latest-npm
NODE

}

install_node() {
  echo -e "\n${FUNCNAME[0]}()\n"
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
  echo -e "\n${FUNCNAME[0]}()\n"
  # http://tecadmin.net/install-git-2-0-on-centos-rhel-fedora/
  sudo su - <<'EOF'
        git --version 2> /dev/null | grep '2.34' || \
        (
	v=2.34.1
        yum remove -y git && \
        yum install -y gcc perl-Tk-devel curl-devel expat-devel openssl-devel zlib-devel && \
        pushd /usr/src && \
        [ ! -e "git-$v.tar.gz" ] && wget "https://www.kernel.org/pub/software/scm/git/git-$v.tar.gz" || true && \
        tar -xf "git-$v.tar.gz" && \
        pushd "git-$v" && \
        make prefix=/usr/local/git all &>/tmp/git-build.log && \
        make prefix=/usr/local/git install &>/tmp/git-build.log && \
        echo 'export PATH=/usr/local/git/bin:$PATH' >> /etc/bashrc && \
        source /etc/bashrc && \
        echo "Installation of git-$v complete" &&
        popd && /bin/rm -rf "/usr/src/git-$v" ||
        echo "Installation FAILED for git-$v"
        )
EOF
  source /etc/bashrc
}

os_support_updates() {
    sudo yum -y install iftop
}

upgrade_nginx() {
    echo -e "\n${FUNCNAME[0]}()\n"
    # https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-centos-7
    sudo su - <<'YUM'

    systemctl stop nginx

    yum upgrade -y nginx

    systemctl enable nginx
    systemctl start nginx
YUM
}

install_nginx() {
  echo -e "\n${FUNCNAME[0]}()\n"
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
    echo -e "\n${FUNCNAME[0]}()\n"

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

reconfigure_supervisord() {
    # have supervisord auto restart
    sudo su - <<'SUPERVISOR'
# comment out existing and replace with new ExecStart
sed -i '/ExecStart/ d' /usr/lib/systemd/system/supervisord.service
sed -i '/Restart=/ d' /usr/lib/systemd/system/supervisord.service
sed -i '/RestartSec=/ d' /usr/lib/systemd/system/supervisord.service

sed -i "/Type=forking/ a ExecStart=/usr/bin/supervisord -c /etc/supervisord.conf\nRestart=always\nRestartSec=10" /usr/lib/systemd/system/supervisord.service
SUPERVISOR
}

install_sqlite() {
  echo -e "\n${FUNCNAME[0]}()\n"

  sudo yum -y install sqlite-devel sqlite
}

install_postgresql() {

  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} 9.5|9.6|10|11|12|13|14" && return 1
  }
  echo "$1" | grep -E '9.5$|9.6$|10$|11$|12$|13$|14$' || {
    echo -e "invalid argument\nusage: ${FUNCNAME[0]} 9.5|9.6|10|11|12|13|14" && return 2
  }
  echo -e "\n${FUNCNAME[0]}($@) - install postgresql\n"

  PGDB_VERSION=$1
  PGDB_VER=$(echo $PGDB_VERSION | tr -d '.') # remove the dots
  rpm -qa --qf '%{NAME},%{VERSION}\n' | grep postgresql${PGDB_VER}-server && {
    echo "Postgresql $PGDB_VERSION is installed - skipping."
    return
  }

  sudo systemctl stop postgresql-9.5 2>/dev/null || echo ""
  sudo systemctl disable postgresql-9.5 2>/dev/null || echo ""
  sudo systemctl stop postgresql-9.6 2>/dev/null || echo ""
  sudo systemctl disable postgresql-9.6 2>/dev/null || echo ""
  sudo systemctl stop postgresql-10 2>/dev/null || echo ""
  sudo systemctl disable postgresql-10 2>/dev/null || echo ""
  sudo systemctl stop postgresql-11 2>/dev/null || echo ""
  sudo systemctl disable postgresql-11 2>/dev/null || echo ""
  sudo systemctl stop postgresql-12 2>/dev/null || echo ""
  sudo systemctl disable postgresql-12 2>/dev/null || echo ""
  sudo systemctl stop postgresql-13 2>/dev/null || echo ""
  sudo systemctl disable postgresql-13 2>/dev/null || echo ""
  sudo systemctl stop postgresql-14 2>/dev/null || echo ""
  sudo systemctl disable postgresql-14 2>/dev/null || echo ""

  case "$PGDB_VERSION" in
  9.5)
    sudo rpm -Uvh http://yum.postgresql.org/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-3.noarch.rpm || echo 'postgresql95 repo already exists'
    sudo yum -y install postgresql95-server postgresql95 postgresql95-contrib
    ;;
  9.6)
    sudo rpm -Uvh http://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm || echo 'postgresql96 repo already exists'
    sudo yum -y install postgresql96-server postgresql96 postgresql96-contrib
    ;;
  10)
    sudo rpm -Uvh http://yum.postgresql.org/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm || echo 'postgresql10 repo already exists'
    sudo yum -y install postgresql10-server postgresql10 postgresql10-contrib
    ;;
  11)
    sudo rpm -Uvh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm || echo 'postgresql11 repo already exists'
    sudo yum -y install postgresql11-server postgresql11 postgresql11-contrib
    ;;
  12)
    sudo rpm -Uvh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm || echo 'postgresql12 repo already exists'
    sudo yum -y install postgresql12-server postgresql12 postgresql12-contrib
    ;;
  13)
    sudo rpm -Uvh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm || echo 'postgresql13 repo already exists'
    sudo yum -y install postgresql13-server postgresql13 postgresql13-contrib
    ;;
  14)
    sudo rpm -Uvh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm || echo 'postgresql14 repo already exists'
    sudo yum -y install postgresql14-server postgresql14 postgresql14-contrib
    ;;
  esac

}

configure_postgresql() {

  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} 9.5|9.6|10|11|12|13|14" && return 1
  }
  echo "$1" | grep -E '9.5$|9.6$|10$|11$|12$|13$|14$' || {
    echo -e "invalid argument '$1'\nusage: ${FUNCNAME[0]} 9.5|9.6|10|11|12|13|14" && return 2
  }
  echo -e "\n${FUNCNAME[0]}($@) - configure postgresql\n"

  PGDB_VERSION=$1
  case "$PGDB_VERSION" in
  9.5)
    setup_script=postgresql95-setup
    ;;
  9.6)
    setup_script=postgresql96-setup
    ;;
  10)
    setup_script=postgresql-10-setup
    ;;
  11)
    setup_script=postgresql-11-setup
    ;;
  12)
    setup_script=postgresql-12-setup
    ;;
  13)
    setup_script=postgresql-13-setup
    ;;
  14)
    setup_script=postgresql-14-setup
    ;;
  esac

  sudo su - <<PGINSTALL
    /usr/pgsql-${PGDB_VERSION}/bin/$setup_script initdb && ( \

        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/${PGDB_VERSION}/data/postgresql.conf

        sed -ir "s/local[[:space:]]*all[[:space:]]*all[[:space:]]*peer/#local     all       all       peer/g"  /var/lib/pgsql/${PGDB_VERSION}/data/pg_hba.conf

        cat << POSTGRESQL > "/var/lib/pgsql/${PGDB_VERSION}/data/pg_hba.conf"
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
host    all             all             192.168.0.0/16            md5


POSTGRESQL
    ) || echo ""
    systemctl start postgresql-${PGDB_VERSION}  2> /dev/null || echo 'failed to start postgresql-${PGDB_VERSION}'
    systemctl enable postgresql-${PGDB_VERSION} 2> /dev/null || echo 'failed to enable postgresql-${PGDB_VERSION}'

    pushd /tmp && sudo -u postgres psql -c "CREATE ROLE homestead LOGIN PASSWORD 'secret' SUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;" 2>/dev/null || echo 'homestead role already exists'
    sudo -u postgres /usr/bin/createdb --owner=homestead homestead || echo 'homestead DB already exists'
    systemctl restart postgresql-${PGDB_VERSION} 2> /dev/null || echo 'failed to restart postgresql-${PGDB_VERSION}'
PGINSTALL
}

switch_postgres() {

  versions_installed="$(rpm -qa postgresql*-server --qf '%{VERSION}\n' | egrep -oE '^[1-2][0-9]|[9]\.[5-7]' | sort -n | tr '\n' ' ' | tr ' ' '|' | sed 's/.$//')"
  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} $versions_installed" && return 1
  }
  echo "$1" | grep -E "$versions_installed" || {
    echo -e "invalid argument '$1'\nusage: ${FUNCNAME[0]} $versions_installed" && return 2
  }
  echo -e "\n${FUNCNAME[0]}($@) - switch postgresql\n"
  PGDB_VERSION=$1
  SWITCH_DATE=$(date +"%Y-%m-%d - %H:%M:%S")
  PGDB_VER=$(echo $PGDB_VERSION | tr -d '.') # remove the dots

  # rely on .pgsql_profile to set env - remove entry in bash_profile as created by yum install script for postgresNn
  grep '/var/lib/pgsql/.pgsql_profile' /var/lib/pgsql/.bash_profile &>/dev/null
  if [ $? -eq 0 ]; then
    sed -i '/^PGDATA/d' /var/lib/pgsql/.bash_profile && echo 'removed redundant PGDATA' || echo 'no PGDATA found'
    sed -i '/export PGDATA/d' /var/lib/pgsql/.bash_profile && echo 'removed export PGDATA' || echo 'no export PGDATA found'
  fi

  # rpm -q --scripts postgresql10-server shows the scripts used during installation - these set the postgresql's env .bash_profile
  # Update environment that will not be overwritten in any yum/rpm updates, use /var/lib/pgsql/.bash_profile
  sudo su postgres - <<PGDATA_CHANGE
    echo -e '# switched postgresql version to (${PGDB_VERSION}) on (${SWITCH_DATE}).\nPGVERSION=${PGDB_VERSION}\nPGDATA=/var/lib/pgsql/${PGDB_VERSION}/data' > /var/lib/pgsql/.pgsql_profile
    echo -e 'PGVER=${PGDB_VERSION}\nPGLIB=/usr/pgsql-${PGDB_VERSION}\nPG_PATH=/usr/pgsql-${PGDB_VERSION}/bin/' >> /var/lib/pgsql/.pgsql_profile
    echo -e '\nexport PGDATA PGVERSION PGVER PGLIB PG_PATH' >> /var/lib/pgsql/.pgsql_profile

PGDATA_CHANGE

  sudo systemctl stop postgresql-9.5 2>/dev/null || true && echo "stopped postgresql-9.5"
  sudo systemctl disable postgresql-9.5 2>/dev/null || true && echo "disabled postgresql-9.5"

  sudo systemctl stop postgresql-9.6 2>/dev/null || true && echo "stopped postgresql-9.6"
  sudo systemctl disable postgresql-9.6 2>/dev/null || true && echo "disabled postgresql-9.6"

  sudo systemctl stop postgresql-10 2>/dev/null || true && echo "stopped postgresql-10"
  sudo systemctl disable postgresql-10 2>/dev/null || true && echo "disabled postgresql-10"

  sudo systemctl stop postgresql-11 2>/dev/null || true && echo "stopped postgresql-11"
  sudo systemctl disable postgresql-11 2>/dev/null || true && echo "disabled postgresql-11"

  sudo systemctl stop postgresql-12 2>/dev/null || true && echo "stopped postgresql-12"
  sudo systemctl disable postgresql-12 2>/dev/null || true && echo "disabled postgresql-12"

  sudo systemctl stop postgresql-13 2>/dev/null || true && echo "stopped postgresql-13"
  sudo systemctl disable postgresql-13 2>/dev/null || true && echo "disabled postgresql-13"

  sudo systemctl stop postgresql-14 2>/dev/null || true && echo "stopped postgresql-14"
  sudo systemctl disable postgresql-14 2>/dev/null || true && echo "disabled postgresql-14"

  sudo systemctl enable postgresql-${PGDB_VERSION} 2>/dev/null || echo "failed to enable postgresql-${PGDB_VERSION}"
  sudo systemctl start postgresql-${PGDB_VERSION} 2>/dev/null || echo "failed to start postgresql-${PGDB_VERSION}"

  # rely on installed alternatives
  for pgsql_bin in $(find /etc/alternatives/ -name 'pgsql-*' -exec basename {} \;); do
    # alternatives --display $pgsql_bin;
    position=$(alternatives --display $pgsql_bin | grep 'priority' | grep -n ${PGDB_VERSION} | cut -d':' -f1)

    # goto be a better way than this - expecting 2 versions installed, choose older 9.5 to enabled by default (idx 2)
    sudo alternatives --config ${pgsql_bin} <<<$position >/dev/null && echo "switching $pgsql_bin to $position"
  done

  # PG 9.5 and 9.6 have createlang and droplang commands that dont exist in 10+
  for REMPG in 9.5 9.6; do
    /usr/sbin/update-alternatives --remove pgsql-createlang /usr/pgsql-${REMPG}/bin/createlang
    /usr/sbin/update-alternatives --remove pgsql-createlangman /usr/pgsql-${REMPG}/share/man/man1/createlang.1
    /usr/sbin/update-alternatives --remove pgsql-droplang /usr/pgsql-${REMPG}/bin/droplang
    /usr/sbin/update-alternatives --remove pgsql-droplangman /usr/pgsql-${REMPG}/share/man/man1/droplang.1
  done

  echo ${PGDB_VERSION} | egrep '9.5$|9.6$' && {
    priority=$(printf %.0f $(echo "scale=2 ;${PGDB_VERSION}*100" | bc))
    /usr/sbin/update-alternatives --install /usr/bin/createlang pgsql-createlang /usr/pgsql-${PGDB_VERSION}/bin/createlang 950
    /usr/sbin/update-alternatives --install /usr/bin/droplang pgsql-droplang /usr/pgsql-${PGDB_VERSION}/bin/droplang 950
    /usr/sbin/update-alternatives --install /usr/share/man/man1/createlang.1 pgsql-createlangman /usr/pgsql-${PGDB_VERSION}/share/man/man1/createlang.1 950
    /usr/sbin/update-alternatives --install /usr/share/man/man1/droplang.1 pgsql-droplangman /usr/pgsql-${PGDB_VERSION}/share/man/man1/droplang.1 950
  }

  ls -l /etc/alternatives/pg*
  echo "you are now using postgresql-${PGDB_VERSION}"

}

install_cache_queue() {
  echo -e "\n${FUNCNAME[0]}()\n"

  # http://tecadmin.net/install-postgresql-9-5-on-centos/
  sudo yum -y install redis

  # install memcache
  sudo yum -y install memcached

  # install beanstalk
  sudo yum -y install beanstalkd
}

configure_cache_queue() {
  echo -e "\n${FUNCNAME[0]}()\n"

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

  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} 7.0|7.1|7.2|7.3|7.4|8.0" && return 1
  }
  echo $1 | egrep '[7,8]\.[0,1,2,3,4]' || {
    echo -e "invalid argument\nusage: ${FUNCNAME[0]} 7.0|7.1|7.2|7.3|7.4|8.0" && return 2
  }
  echo -e "\n${FUNCNAME[0]}($@)\n"

  # https://developers.redhat.com/blog/2017/10/18/use-software-collections-without-bothering-alternative-path/
  # https://www.cloudinsidr.com/content/how-to-install-php-7-on-centos-7-red-hat-rhel-7-fedora/

  #rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  sudo rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm || echo "Repo already installed....continuing"

  PHP_DOT_VERSION=$1
  PHP_VERSION=$(echo $PHP_DOT_VERSION | tr -d '.')

  #sudo yum-config-manager --disable remi-php70
  #sudo yum-config-manager --disable remi-php71
  # disable all remi-php repos.
  for repo in $(find /etc/yum.repos.d/ -type f -name 'remi-php*' -exec basename -s '.repo' {} \;); do
    echo $repo
    sudo yum-config-manager --disable $repo &>/dev/null || echo "disabled already $repo"
  done
  sudo yum-config-manager --enable remi-php${PHP_VERSION} && echo "Enabled Repo remi-php${PHP_VERSION}" || echo "FAILED to enable Repo remi-php${PHP_VERSION}"

  sudo yum --enablerepo=remi-php${PHP_VERSION} install -y \
    php${PHP_VERSION}-php-xml \
    php${PHP_VERSION}-php-soap \
    php${PHP_VERSION}-php-xmlrpc \
    php${PHP_VERSION}-php-mbstring \
    php${PHP_VERSION}-php-json \
    gd-last \
    php${PHP_VERSION}-php-gd \
    php${PHP_VERSION}-php-mcrypt \
    php${PHP_VERSION}-php-cli \
    php${PHP_VERSION}-php-common \
    php${PHP_VERSION}-php-intl \
    php${PHP_VERSION}-php-fpm \
    php${PHP_VERSION}-php-xml \
    php${PHP_VERSION}-php-xmlrpc \
    php${PHP_VERSION}-php-pdo \
    php${PHP_VERSION}-php-gmp \
    php${PHP_VERSION}-php-process \
    php${PHP_VERSION}-php-devel \
    php${PHP_VERSION}-php-mbstring \
    php${PHP_VERSION}-php-pecl-mcrypt \
    php${PHP_VERSION}-php-gd \
    php${PHP_VERSION}-php-readline \
    php${PHP_VERSION}-php-pecl-imagick \
    php${PHP_VERSION}-php-opcache \
    php${PHP_VERSION}-php-memcached \
    php${PHP_VERSION}-php-pecl-apcu \
    php${PHP_VERSION}-php-imap \
    php${PHP_VERSION}-php-dba \
    php${PHP_VERSION}-php-enchant \
    php${PHP_VERSION}-php-soap \
    php${PHP_VERSION}-php-pecl-zip \
    php${PHP_VERSION}-php-pecl-jsond \
    php${PHP_VERSION}-php-pecl-jsond-devel \
    php${PHP_VERSION}-php-pecl-xdebug \
    php${PHP_VERSION}-php-pecl-stomp \
    php${PHP_VERSION}-php-bcmath \
    php${PHP_VERSION}-php-mysqlnd \
    php${PHP_VERSION}-php-pgsql \
    php${PHP_VERSION}-php-imap \
    php${PHP_VERSION}-php-ldap \
    php${PHP_VERSION}-php-pear

  [ $PHP_VERSION -eq '74' ] && yum install -y php74-php-pecl-interbase.x86_64

  switch_php $PHP_DOT_VERSION
  php -v

}

configure_php_remi() {

  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} 7.0|7.1|7.2|7.3|7.4|8.0|8.1" && return 1
  }
  echo $1 | egrep '[7,8]\.[0,1,2,3,4]' || {
    echo -e "invalid argument\nusage: ${FUNCNAME[0]} 7.0|7.1|7.2|7.3|7.4|8.0|8.1" && return 2
  }
  echo -e "\n${FUNCNAME[0]}($@) - configure nginx php-fpm\n"

  PHP_DOT_VERSION=$1
  PHP_VERSION=$(echo $PHP_DOT_VERSION | tr -d '.')
  # phpfpm="$(php -i | grep 'Loaded Configuration File' | cut -d '>' -f 2- | xargs)"
  phpfpm="/etc/opt/remi/php${PHP_VERSION}/php.ini"
  echo "configure $phpfpm"

  sudo su - <<PHP

    # Setup Some PHP-FPM Options
    phpfpm='$phpfpm'

    yum-config-manager --enable remi-php${PHP_VERSION} &> /dev/null

    systemctl enable php${PHP_VERSION}-php-fpm
    systemctl start php${PHP_VERSION}-php-fpm

    # configure xdebug if not already, port 10000 to avoid clash with phpfpm
    grep 'xdebug.idekey' $phpfpm || cat << EOF >> $phpfpm
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
    sed -i 's/^\(zend_extension.*\)/;\1/' /etc/opt/remi/php${PHP_VERSION}/php.d/15-xdebug.ini || echo "XDEBUG not available for /etc/opt/remi/php${PHP_VERSION}/php.d/15-xdebug.ini"

PHP

  echo "Overwrite /etc/nginx/nginx.conf"
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
  sudo su - <<NGINXDIFF

    rm -rf /etc/nginx/{default.d,sites-enabled}
    mkdir -p /etc/nginx/{sites-available,sites-enabled,default.d}

    sed -i "s/user = apache/user = vagrant/" $fpm_pool_www
    sed -i "s/group = apache/group = vagrant/" $fpm_pool_www

    grep 'listen.owner = vagrant' $fpm_pool_www || echo "listen.owner = vagrant" >> $fpm_pool_www
    grep 'listen.group = vagrant' $fpm_pool_www || echo "listen.group = vagrant" >> $fpm_pool_www
    grep 'listen.mode = 0666' $fpm_pool_www || echo "listen.mode = 0666" >> $fpm_pool_www

    systemctl restart nginx
    systemctl restart php${PHP_VERSION}-php-fpm

    # Add Vagrant User To WWW-Data (ubuntu)
    # Add Vagrant User To nginx or apache? (centos)

    usermod -a -G nginx vagrant
    usermod -a -G apache vagrant

    chmod -R g+x /var/lib/nginx

NGINXDIFF
  # output useful details
  id vagrant
  groups vagrant
  egrep -v '^;|^[[:space:]]*$' $fpm_pool_www

}

switch_php() {
  versions_installed="$(rpm -qa php*-runtime --qf '%{NAME}\n' | egrep -oE '[789][0-9]' | sort -n | sed 's/./&\./1' | tr '\n' '|' | sed 's/.$//')"
  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} $versions_installed" && return 1
  }
  echo "$1" | grep -E "$versions_installed" || {
    echo -e "invalid argument\nusage: ${FUNCNAME[0]} $versions_installed" && return 2
  }

  echo -e "\n${FUNCNAME[0]}($@)\n"

  # https://access.redhat.com/solutions/528643 - /etc/alternatives and the dynamic software collections framework

  PHP_DOT_VERSION=$1
  PHP_VERSION=$(echo $PHP_DOT_VERSION | tr -d '.')
  sudo su - <<SWITCH_PHP
    unset X_SCLS && export X_SCLS="$(scl enable php${PHP_VERSION} 'echo $X_SCLS')"
    source scl_source enable php${PHP_VERSION}

    # Update Link - possibly better handled with "alternatives"
    for phpbin in debugclient pear peardev pecl php-cgi php-config phpize
    do
        echo "confirming symbolic links for remi \${phpbin} to /usr/bin/php${PHP_VERSION}-\${phpbin}"
        [ -f /opt/remi/php${PHP_VERSION}/root/usr/bin/\${phpbin} ] \
            && ln -fs /opt/remi/php${PHP_VERSION}/root/usr/bin/\${phpbin} /usr/bin/php${PHP_VERSION}-\${phpbin} \
            || { rm -f /usr/bin/php${PHP_VERSION}-\${phpbin} && echo "/usr/bin/php${PHP_VERSION}-\${phpbin} does not exist ..removing link"; }
    done
    [ -f /opt/remi/php${PHP_VERSION}/root/usr/bin/php ] &&          ln -fs /opt/remi/php${PHP_VERSION}/root/usr/bin/php          /usr/bin/php${PHP_VERSION}
    [ -f /opt/remi/php${PHP_VERSION}/root/usr/bin/phar.phar ] &&    ln -fs /opt/remi/php${PHP_VERSION}/root/usr/bin/phar.phar    /usr/bin/php${PHP_VERSION}-phar

    # set defaults
    for phpbin in debugclient pear peardev pecl php-cgi php-config phpize phar
    do
        echo "making default \${phpbin} to /usr/bin/php${PHP_VERSION}-\${phpbin}"
        [ -h /usr/bin/php${PHP_VERSION}-\${phpbin} ] && ln -fs /usr/bin/php${PHP_VERSION}-\${phpbin} /usr/bin/\${phpbin} || echo "/usr/bin/\${phpbin} already exists ..moving on!"
    done
    [ -h /usr/bin/php${PHP_VERSION} ] && ln -fs /usr/bin/php${PHP_VERSION} /usr/bin/php || echo "/usr/bin/php already exists ..moving on!"
    # TODO /bin/php, /bin/pecl need reviewing - what creates those links.
SWITCH_PHP

  # https://access.redhat.com/solutions/527703 - Enabling userspace environment automatically after logout/reboot

  sudo su - <<SWITCH_BASHENV
    # remove previous SCL and set PHP VERSION to use by default using SoftwareCollections commands
    echo "Updating /etc/bashrc source scl_source enable php${PHP_VERSION} call."
    echo "unset X_SCLS;source scl_source enable php${PHP_VERSION} || echo 'scl_enable php having problems' > /dev/stderr " > /etc/profile.d/scl_enablephp7.sh
SWITCH_BASHENV

  sudo su <<'PHP_SYSCTL'
    # check SCL for installed PHP versions, stop and disable all of them.
    echo "Reconfigure php-fpm services"
    phpversions=`scl --list | grep 'php' | tr -d 'php'`
    for ver in $phpversions
    do
        systemctl stop    php${ver}-php-fpm && echo "service php${ver} stopped " || echo "service php{$ver} failed to stop"
        systemctl disable php${ver}-php-fpm && echo "service php${ver} disabled" || echo "service php{\}$ver} disablement failed"
    done
PHP_SYSCTL

  sudo su - <<PHP_FPM
    # systemd links
    # https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files
    # https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units

    # fix different locations used by php-fpm, Homestead scripts rely on php${PHP_VERSION}-fpm
    echo "Support Homestead dependency on php-fpm naming - add Alias php${PHP_DOT_VERSION}-fpm.service"
    grep '^Alias=php${PHP_DOT_VERSION}-fpm.service' /usr/lib/systemd/system/php${PHP_VERSION}-php-fpm.service &>/dev/null || sed -i 's/\[Install\]/\[Install\]\nAlias=php${PHP_DOT_VERSION}-fpm.service\nAlias=php-fpm.service/' /usr/lib/systemd/system/php${PHP_VERSION}-php-fpm.service
    systemctl daemon-reload

    # enable the required PHP version (needs to be filename php${PHP_VERSION}-php-fpm.service) - then alias can be used
    systemctl enable php${PHP_VERSION}-php-fpm

    # use new alias to restart service (as homestead would - e.g. its uses php70-fpm).
    systemctl restart php${PHP_DOT_VERSION}-fpm

    # Homestead relies on /etc/php/${PHP_DOT_VERSION}/fpm/php-fpm.conf
    mkdir -p /etc/php/${PHP_DOT_VERSION}/fpm/
    [ -e /etc/opt/remi/php${PHP_VERSION}/php-fpm.conf ] && ln -fs /etc/opt/remi/php${PHP_VERSION}/php-fpm.conf /etc/php/${PHP_DOT_VERSION}/fpm/php-fpm.conf
PHP_FPM

  # keep ENV vars tidy when allowing multiple switch_php calls
  unset X_SCLS
  LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed 's#/opt/remi/php[0-9][0-9]/root/usr/lib64:*##g')
  PATH=$(echo $PATH | sed 's#/opt/remi/php[0-9][0-9]/root/usr/[s]*bin:*##g')
  MANPATH=$(echo $MANPATH | sed 's#/opt/remi/php[0-9][0-9]/root/usr/share/man:*##g')
  export LD_LIBRARY_PATH PATH MANPATH

  source scl_source enable php${PHP_VERSION} || echo 'scl_enable php having problems' >/dev/stderr
  systemctl status php${PHP_VERSION}-php-fpm

  return 0
}

install_composer() {
  echo -e "\n${FUNCNAME[0]}()\n"

  # Install Composer

  sudo su - <<COMPOSER
    type composer &>/dev/null || {
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
    }
    cat << 'COMPOSER_HOME' >> /etc/bashrc
# Add Composer Global Bin To Path
export PATH=$(composer global config -q --absolute home)/vendor/bin:\$PATH
export PATH=/usr/local/bin:\$PATH
COMPOSER_HOME


  # Install Laravel Envoy & Installer
  # export COMPOSER_HOME=~/.composer/ # use composer 2 default of $HOME/.config/composer
  #/usr/local/bin/composer config --list --global

  #/usr/local/bin/composer global require --no-interaction "laravel/envoy=^2.0"
  #/usr/local/bin/composer global require --no-interaction "laravel/installer=^4.0.2"
  #/usr/local/bin/composer global require --no-interaction "laravel/spark-installer=dev-master"
  #/usr/local/bin/composer global require --no-interaction "slince/composer-registry-manager=^2.0"
  echo "composer global require - dev tools"
  /usr/local/bin/composer global require --with-all-dependencies --no-interaction \
    "laravel/envoy" \
    "laravel/installer" \
    "laravel/spark-installer" \
    "slince/composer-registry-manager" \
    tightenco/takeout &>/dev/null

  #/usr/local/bin/composer global show --no-interaction --self
  /usr/local/bin/composer global show --no-interaction -D

  /usr/local/bin/composer -V --no-interaction
COMPOSER

  # /usr/local/bin/composer config --no-interaction --list --global

  # Install Laravel Envoy & Installer
  sudo su - vagrant <<EOF
    # export COMPOSER_HOME=~/.composer  # use composer 2 default of $HOME/.config/composer
    #/usr/local/bin/composer config --list --global

    #/usr/local/bin/composer global require --no-interaction "laravel/envoy=^2.0"
    #/usr/local/bin/composer global require --no-interaction "laravel/installer=^4.0.2"
    #/usr/local/bin/composer global require --no-interaction "laravel/spark-installer=dev-master"
    #/usr/local/bin/composer global require --no-interaction "slince/composer-registry-manager=^2.0"

    echo "composer global require - dev tools (vagrant)"

    /usr/local/bin/composer global require --with-all-dependencies --no-interaction \
      "laravel/envoy" \
      "laravel/installer" \
      "laravel/spark-installer" \
      "slince/composer-registry-manager" \
      tightenco/takeout &>/dev/null

EOF

}

install_mysql80() {
    echo -e "\n${FUNCNAME[0]}()\n"
    # stop existing 5.7
    systemctl disable mysqld
    systemctl stop mysqld
    yum erase mysql57-community-release.noarch

    # upadate repo and install latest 8.x
    rpm -Uvh https://repo.mysql.com/mysql80-community-release-el7-3.noarch.rpm
    yum -y install mysql-community-server
    systemctl disable mysqld
    systemctl stop mysqld
}



install_mysql() {
  echo -e "\n${FUNCNAME[0]}()\n"

  # http://www.tecmint.com/install-latest-mysql-on-rhel-centos-and-fedora/
  wget http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
  yum -y localinstall mysql57-community-release-el7-7.noarch.rpm

  # check repos installed.
  yum repolist enabled | grep "mysql.*-community.*"

  yum -y install mysql-community-server

  rm -f mysql57-community-release-el7-7.noarch.rpm
}

configure_mysql() {
  echo -e "\n${FUNCNAME[0]}()\n"

  systemctl enable mysqld.service
  systemctl start mysqld.service

  # Configure Centos Mysql 5.7+

  # http://blog.astaz3l.com/2015/03/03/mysql-install-on-centos/
  echo "default_password_lifetime = 0" >>/etc/my.cnf
  echo "bind-address = 0.0.0.0" >>/etc/my.cnf
  echo "validate_password_policy=LOW" >>/etc/my.cnf
  echo "validate_password_length=6" >>/etc/my.cnf
  systemctl restart mysqld.service

  # find temporary password
  mysql_password=$(sudo grep 'temporary password' /var/log/mysqld.log | sed 's/.*localhost: //')
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
  echo -e "\n${FUNCNAME[0]}()\n"
  sudo yum -y install pygpgme
  wget -O - "http://packages.blackfire.io/fedora/blackfire.repo" | sudo tee /etc/yum.repos.d/blackfire.repo
  sudo yum -y install blackfire-agent blackfire-php
}

install_mailhog() {
  echo -e "\n${FUNCNAME[0]}()\n"
  sudo su - <<MAILHOG
    wget --quiet -O /usr/local/bin/mailhog https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64
    chmod +x /usr/local/bin/mailhog
    tee /etc/systemd/system/mailhog.service <<EOL
[Unit]
Description=Mailhog
After=network.target
[Service]
User=vagrant
#ExecStart=/usr/bin/env /usr/local/bin/mailhog -storage=maildir -maildir-path=/tmp/mailhog > /var/log/maillog 2>&1 &
ExecStart=/usr/bin/env /usr/local/bin/mailhog > /var/log/maillog 2>&1 &
[Install]
WantedBy=multi-user.target
EOL
    systemctl daemon-reload
    systemctl enable mailhog
MAILHOG
}

install_ngrok() {
  echo -e "\n${FUNCNAME[0]}()\n"
  wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
  unzip ngrok-stable-linux-amd64.zip -d /usr/local/bin
  rm -rf ngrok-stable-linux-amd64.zip
}

install_flyway() {
  echo -e "\n${FUNCNAME[0]}()\n"
  wget https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/4.2.0/flyway-commandline-4.2.0-linux-x64.tar.gz
  tar -zxvf flyway-commandline-4.2.0-linux-x64.tar.gz -C /usr/local
  [ ! -e /usr/local/bin/flyway ] && ln -s /usr/local/flyway-4.2.0/flyway /usr/local/bin/flyway || echo 'flyway already installed'
  chmod +x /usr/local/flyway-4.2.0/flyway
  rm -rf flyway-commandline-4.2.0-linux-x64.tar.gz
}

install_wp_cli() {
  echo -e "\n${FUNCNAME[0]}()\n"
  sudo su - <<WPCLI
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    [ ! -e /usr/local/bin/wp ] && mv wp-cli.phar /usr/local/bin/wp || echo 'WP-CLI already installed'
WPCLI
}

install_oh_my_zsh() {
  echo -e "\n${FUNCNAME[0]}()\n"
  sudo su - <<MYZSH
    git clone git://github.com/robbyrussell/oh-my-zsh.git /home/vagrant/.oh-my-zsh
    cp /home/vagrant/.oh-my-zsh/templates/zshrc.zsh-template /home/vagrant/.zshrc
    printf "\nsource ~/.bash_aliases\n" | tee -a /home/vagrant/.zshrc
    printf "\nsource ~/.profile\n" | tee -a /home/vagrant/.zshrc
    chown -R vagrant:vagrant /home/vagrant/.oh-my-zsh
    chown vagrant:vagrant /home/vagrant/.zshrc
MYZSH
}

install_browsershot_dependencies() {
  echo -e "\n${FUNCNAME[0]}()\n"
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
  echo -e "\n${FUNCNAME[0]}()\n"
  echo 'skipping zend zray - conficting libssl dependency'
  return 0

  # Install Zend Z-Ray -
  # doesnt work in centos 7 due to openssl libssl 1.0.0 dependency - co7 use 1.0.2

  sudo wget http://repos.zend.com/zend-server/early-access/ZRay-Homestead/zray-standalone-${PHP_VERSION}.tar.gz -O - | sudo tar -xzf - -C /opt
  sudo ln -sf /opt/zray/zray.ini /etc/php/7.2/cli/conf.d/zray.ini
  sudo ln -sf /opt/zray/zray.ini /etc/php/7.2/fpm/conf.d/zray.ini
  sudo ln -sf /opt/zray/lib/zray.so /usr/lib/php/20170718/zray.so
  sudo chown -R vagrant:vagrant /opt/zray
}

install_pghashlib() {
  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} 9.5|9.6|10|11|12|13|14" && return 1
  }
  echo "$1" | grep -E '9.5$|9.6$|10$|11$|12$|13$|14$' || {
    echo -e "invalid argument\nusage: ${FUNCNAME[0]} 9.5|9.6|10|11|12|13|14" && return 2
  }
  echo -e "\n${FUNCNAME[0]}($@) - install pghashlib\n"

  # old installer added script to profile.d - this is redundant and should have only be used during installation of pghashlib
  [ -e /etc/profile.d/postgres_hashlib.sh ] && rm -f /etc/profile.d/postgres_hashlib.sh || true

  PGVER=$1
  PGVER_DEVEL_LIB="postgresql$(echo $PGVER | tr -d '.')-devel"
  PGLIB="/usr/pgsql-${PGVER}"
  PG_PATH="${PGLIB}/bin/"

  echo $PGVER | egrep '11$|12$|13$|14$' && {
    # look for prebuild libs for hashlib - at https://github.com/bgdevlab/pghashlib
    pghashlib="postgresql${PGVER}-hashlib.rhel7.minimum-base.tar.gz"
    [ ! -e "/tmp/${pghashlib}" ] && {
      # download required and extract into postgresql path.
      echo -e "Local pghashlib not found - download pre-built ${pghashlib} to /tmp/$pghashlib"
      echo -e "trying https://github.com/bgdevlab/pghashlib/blob/bgdevlab/builds/builds/rhel/${pghashlib}?raw=true"
      wget -qO- https://github.com/bgdevlab/pghashlib/blob/bgdevlab/builds/builds/rhel/${pghashlib}?raw=true >/tmp/${pghashlib} || echo 'Failed to download'
    } || {
      echo -e "Local copy found at /tmp/$pghashlib"
    }
    [ -e /tmp/${pghashlib} -a -e "${PGLIB}/bin" ] && tar -xvf /tmp/${pghashlib} -C ${PGLIB} || echo "failed to find and install ${pghashlib}"
  }

  [ -e ${PGLIB}/lib/hashlib.so ] && {
    # check for ext and test - return if successful.
    su - postgres -c "psql -U postgres -c 'CREATE EXTENSION hashlib;'"
    su - postgres -c "psql -U postgres -c \"select encode(hash128_string('abcdefg', 'murmur3'), 'hex');\"" && return 0
  }

  # we are here because its all checks for existing and downloadable pre built extension have failed. build from source is the last option.

  # centos 7 for pg11+ requires additional libraries - https://www.softwarecollections.org/en/scls/rhscl/llvm-toolset-7.0/
  # https://stackoverflow.com/questions/61904796/cloudlinux-7-8-error-installing-postgresql-11-requires-llvm-toolset-7-clang
  sudo yum -y install centos-release-scl || true
  sudo yum -y install llvm-toolset-7.0 gcc python-docutils || true
  # https://command-not-found.com/rst2html.py `yum install python-docutils`

  #echo "\$PGVER_DEVEL_LIB: $PGVER_DEVEL_LIB"
  #echo "\$PGLIB:           $PGLIB"
  #echo "\$PG_PATH:         $PG_PATH"
  #echo "\$PGVER:           $PGVER"

  cat <<PGHASHLIB > /tmp/install_pghashlib
        pushd /tmp/ && \
        wget --quiet https://github.com/markokr/pghashlib/archive/master.zip -O pghashlib.zip && \
        rm -rf pghashlib-master && \
        unzip pghashlib.zip && \
        cd pghashlib-master && \
        yum install -y $PGVER_DEVEL_LIB && \
        echo -e "PG_PATH=${PG_PATH}\nPATH=\\\$PATH:\\\$PG_PATH\n" > /tmp/postgres_hashlib.sh && \
        source /tmp/postgres_hashlib.sh && \
        make && \
        [[ -f hashlib.html ]] || make html && \
        chown $(whoami) ${PGLIB}/lib/ && \
        chown $(whoami) ${PGLIB}/share/extension && \
        chown $(whoami) ${PGLIB}/doc/extension && \
        make install && \
        cd .. && \
        rm -rf pghashlib-master && \
        rm -f pghashlib.zip
PGHASHLIB
  sudo chmod +x /tmp/install_pghashlib
  sudo scl enable llvm-toolset-7.0 /tmp/install_pghashlib

  su - postgres -c "psql -U postgres -c 'CREATE EXTENSION hashlib;'"
  su - postgres -c "psql -U postgres -c \"select encode(hash128_string('abcdefg', 'murmur3'), 'hex');\""

  echo -e "\n===============\ncheck hashlib is installed using commands\n"
  echo "psql -U postgres -c 'CREATE EXTENSION hashlib;'"
  echo "psql -U postgres -c \"select encode(hash128_string('abcdefg', 'murmur3'), 'hex');\""
}

install_golang() {
  echo -e "\n${FUNCNAME[0]}()\n"
  # Install Golang
  GO_VERSION='1.10.3'
  sudo su - <<GOLANG
    wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz  -O - | tar -xz -C /usr/local
    echo 'export PATH=/usr/local/go/bin:\$PATH' >> /etc/bashrc
GOLANG
}

install_postfix() {
  echo -e "\n${FUNCNAME[0]}()\n"
  # Install & Configure Postfix
  FQDN='homestead.test'
  sudo su - <<POSTFIX
    echo "myhostname = ${FQDN}" >> /etc/postfix/main.cf
    yum install -y postfix &&
        systemctl disable sendmail &&
        systemctl stop sendmail &&
        yum erase -y sendmail

    grep '^relayhost' /etc/postfix/main.cf \
        && (echo 'relayhost appears to be configured already - will comment out' \
        && sed -i 's/^relayhost/#relayhost/g' /etc/postfix/main.cf)

    echo "relayhost = [localhost]:1025" >> /etc/postfix/main.cf && echo "postfix configured to send mail to localhost MailHog"

    touch /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
    sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
    sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

    systemctl enable postfix
    systemctl restart postfix
POSTFIX
}

configure_postfix_for_sendgrid() {
  echo -e "\n${FUNCNAME[0]}()\n"
  USERNAME=${1:-username}
  PASSWORD=${2:-password}
  sudo su - <<POSTFIX
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
POSTFIX

  # comment out any existing credentials
  sed -i 's/^\[smtp.sendgrid/#\[smtp.sendgrid/g' /etc/postfix/sasl_passwd
  echo "[smtp.sendgrid.net]:587 $USERNAME:$PASSWORD" >>/etc/postfix/sasl_passwd

  # build passwords
  postmap /etc/postfix/sasl_passwd

  sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
  sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

  systemctl restart postfix

  POSTFIX

  # echo "Test Email from - $(hostname)" | mail -s "Test Email - ($(date))" -r "$(whoami)@$(hostname)" test@gmail.com
}

generate_chromium_test_script() {
  echo -e "\n${FUNCNAME[0]}()\n"
  cat <<SCRIPT >>test_chromium.sh
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

install_crystal() {

  echo -e "\n${FUNCNAME[0]}()\n"
  # Fast as C, Slick as Ruby - https://crystal-lang.org
  curl https://dist.crystal-lang.org/rpm/setup.sh | sudo bash
  sudo yum -y install crystal

}

install_heroku_tooling() {

  echo -e "\n${FUNCNAME[0]}()\n"
  sudo su - <<'HEROKU'
    PATH=$PATH:/usr/local/bin;
    export PATH;
    env | grep PATH
    curl https://cli-assets.heroku.com/install.sh | sh
HEROKU

}

install_lucky() {

  echo -e "\n${FUNCNAME[0]}()\n"
  # Install Lucky Framework for Crystal
  sudo su - <<'LUCKY'
yum -y install libpng-devel
go_version=0.11.0
tmpdir=/tmp/lucky_cli-${go_version}

wget -qO- https://github.com/luckyframework/lucky_cli/archive/v${go_version}.tar.gz | tar xz -C /tmp
pushd $tmpdir
shards install && crystal build src/lucky.cr --release --no-debug
[ -e ${tmpdir}/lucky ] && mv ${tmpdir}/lucky /usr/local/bin/. || echo "Cant find ${tmpdir}/lucky"
popd
rm -rf ${tmpdir}

LUCKY
}

install_rabbitmq() {
  echo -e "\n${FUNCNAME[0]}()\n"

  rpm --import https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey ||true
  rpm --import https://packagecloud.io/gpg.key||true
  curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | sudo bash
  curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | sudo bash
  yum install -y erlang rabbitmq-server
  # TODO docs suggest pinning erlang and the 22 version
  echo "pin yum erlang"
}

install_timescaledb_for_postgresql() {
  # https://www.digitalocean.com/community/tutorials/how-to-install-and-use-timescaledb-on-centos-7

  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} 11|12|13|14" && return 1
  }
  echo "$1" | grep -E '11$|12$|13$|14$' || {
    echo -e "invalid argument\nusage: ${FUNCNAME[0]} 11|12|13|14" && return 2
  }
  echo -e "\n${FUNCNAME[0]}($@) - install postgresql\n"

  PGDB_VERSION=$1

  cat <<TIMESCALE_DB_REPO >>"/etc/yum.repos.d/timescaledb.repo"
[timescale_timescaledb]
name=timescale_timescaledb
baseurl=https://packagecloud.io/timescale/timescaledb/el/$(rpm -E %{rhel})/\$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/timescale/timescaledb/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
TIMESCALE_DB_REPO

  sudo yum install -y timescaledb-2-postgresql-${PGDB_VERSION}
  echo "shared_preload_libraries = 'timescaledb'" >>/var/lib/pgsql/${PGDB_VERSION}/data/postgresql.conf
  sudo systemctl restart postgresql-${PGDB_VERSION}.service
  su postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;'"

}

finish_build_meta() {
  echo -e "\n${FUNCNAME[0]}()\n"
  [ $# -lt 1 ] && HSVER=$(date +%s) || HSVER=$1
  sudo su - <<BUILD_META
echo 'HOMESTEAD_CENTOS_VERSION=${HSVER}' > ~/build.info
echo 'HOMESTEAD_CENTOS_DATE=$(date)' >> ~/build.info
[ -f ~/build.info ] && ln -nf ~/build.info /etc/homestead_co7
BUILD_META

}

disable_blackfire() {
  echo -e "\n${FUNCNAME[0]}()"
  # don't load blackfire
  find /etc/opt/remi -path '/etc/opt/remi/*/php.d/*-blackfire.ini' -exec sed -i 's/^/;/g' {} \; || true
  sudo systemctl disable blackfire-agent 2>/dev/null || true

  # disable repo as it has issues
  yum-config-manager -y --disable blackfire &>/dev/null || true
}

set_profile() {
  echo -e "\n${FUNCNAME[0]}()\n"

  touch /home/vagrant/.profile && chown vagrant:vagrant /home/vagrant/.profile

  cat <<HOMESTEAD_BASH_FIX >>"/home/vagrant/.bash_profile"
# User specific environment and startup programs
PATH=\$PATH:\$HOME/bin

# Homestead fix - incorporate ~/.profile
source ~/.profile
HOMESTEAD_BASH_FIX
}

rpm_versions() {
  echo -e "\n${FUNCNAME[0]}()\n"
  [ ! -z $1 ] && tagged=".$1" || tagged=''
  # list all packages installed and versions
  outputfile=/tmp/rpm-versions.$(date +"%Y%m%d_%H%M%S_%s")${tagged}.txt
  rpm -qa --qf '%{NAME}_%{VERSION}\n' | sort > $outputfile
  echo "rpm versions tracked in $outputfile"
}

upgrade_composer() {
    echo -e "\n${FUNCNAME[0]}()\n"
    [ -e /etc/bashrc ] && sed -i '/export PATH=~\/\.composer.*$/d' /etc/bashrc || true

    rm -rf $HOME/.composer &>/dev/null || true
    sudo su - vagrant <<EOF
        rm -rf $HOME/.composer &>/dev/null || true
EOF
    type composer && {
        composer selfupdate --no-interaction -q
        COMPOSER_HOME="$(composer global config -q --absolute home)"
    }
    install_composer

}

fix_letsencrypt_certificate_issue() {
    echo -e "\n${FUNCNAME[0]}()"

    # - https://blog.devgenius.io/rhel-centos-7-fix-for-lets-encrypt-change-8af2de587fe4
    # TL;DR — For TLS certificates issued by Let’s Encrypt, the root certificate (DST Root CA X3)
    # in the default chain expires on September 30, 2021. Due to their unique approach,
    # the expired certificate will continue to be part of the certificate chain till 2024.
    # This affects OpenSSL 1.0.2k on RHEL/CentOS 7 servers, and will result in applications/tools
    # failing to establish TLS/HTTPS connections with a certificate has expired message.
    #

    if test ! -e /etc/pki/ca-trust/source/blacklist/DST-Root-CA-X3.pem; then
        sudo trust dump --filter "pkcs11:id=%c4%a7%b1%a4%7b%2c%71%fa%db%e1%4b%90%75%ff%c4%15%60%85%89%10" | openssl x509 | sudo tee /etc/pki/ca-trust/source/blacklist/DST-Root-CA-X3.pem &>/dev/null
        sudo update-ca-trust extract || echo 'FAILED to install centos-7-fix-for-lets-encrypt-change'
    fi

}

install_docker() {
    echo -e "\n${FUNCNAME[0]}()\n"

    # docker
    sudo yum -y -q install yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum -y -q install docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl disable docker # not started by default

    # docker composer
    sudo curl -s -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose && echo "$(/usr/local/bin/docker-compose -v)"
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # Enable vagrant user to run docker commands
    usermod -aG docker vagrant

}

install_chromebrowser() {
    echo -e "\n${FUNCNAME[0]}()\n"
    # used for Dusk tests.
    sudo yum -y -q install https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
}

install_phpunit() {
    echo -e "\n${FUNCNAME[0]}()\n"
    # used for Dusk tests.
    mkdir -p /opt/phpunit/phpunit-{5,6,7,8,9};
    for v in 5 6 7 8 9 ; do
        wget -nv -O /opt/phpunit/phpunit-$v/phpunit https://phar.phpunit.de/phpunit-$v.phar;
        chmod +x /opt/phpunit/phpunit-$v/phpunit;
    done
}

update_services() {
  # fyi - lots of homestead optional features are installed outside of the standard build.
  # https://github.com/laravel/homestead/tree/main/scripts/features
  sudo yum -y -q --enablerepo=remi install redis beanstalkd sqlite
}
