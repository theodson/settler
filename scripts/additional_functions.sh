#!/usr/bin/env bash

log_build_meta() {
  [ $# -lt 1 ] && BUILD_VER=$(date +%s) || BUILD_VER=$1
  cat <<<BUILD_META> ~/build.info
BUILD_VERSION=${BUILD_VER} 
BUILD_DATE=$(date)
BUILD_GIT_HASH=$(git describe &>/dev/null && git describe || git rev-parse --short HEAD)
BUILD_META

}

function download_install_jdk() {
    time curl -q https://gist.githubusercontent.com/bgdevlab/e29b5c07242d7d874982c5d20f98de5b/raw/a3eb1c3b639f2c94b35625833153295483dca0ee/getOracleJDK.sh | bash -s "rpm" "8" 2>/dev/null \
        && yum -y localinstall --nogpgcheck jdk-8u*-linux-x64*.rpm* \
        && echo "SKIPPING rm -f jdk-8u*-linux-x64*.rpm*"
}


function get_php_version() {
    # get the php version in the path
    type -p php &>/dev/null || return 1
    echo $(php -r 'echo "\n".PHP_VERSION;' | tail -1 | cut -d. -f-2)
}

switch_php() {
  versions_installed="$(rpm -qa php*-runtime --qf '%{NAME}\n' | egrep -oE '[789][0-9]' | sort -n | sed 's/./&\./1' | tr '\n' '|' | sed 's/.$//')"
  [ $# -lt 1 ] && {
    echo -e "missing argument\nusage: ${FUNCNAME[0]} $versions_installed" && return 1
  }
  echo "$1" | grep -E "$versions_installed" || {
    echo -e "invalid argument\nusage: ${FUNCNAME[0]} $versions_installed" && return 2
  }
  force=false
  if test $# -eq 2 -a $2=='force'; then
    force=true
  fi
  echo -e "\n✨ ${FUNCNAME[0]}()\n"

  # https://access.redhat.com/solutions/528643 - /etc/alternatives and the dynamic software collections framework

  PHP_DOT_VERSION=$1
  PHP_VERSION=$(echo $PHP_DOT_VERSION | tr -d '.')
  CURRENT_PHP_VERSION=$(echo "$(get_php_version)" | tr -d '.')
  
  if [ "$CURRENT_PHP_VERSION" = "$PHP_VERSION" ] && ! $force; then
    echo -e "\n✨ Request and Current PHP Version are the same - FORCE switch NOT requested - skipping\n"
    return
  fi

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
  echo -e "\n✨ ${FUNCNAME[0]}() done\n"

  return 0
}
