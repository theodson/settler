#!/usr/bin/env bash
#
# upgrade homestead 6.1.1 to 11.5.0 (php-8.0 introduced at 10.1.1).
#
UPGRADE_BOX_VERSION='11.5.0<6.1.1'
MAINTAIN_PHP_AT_VERSION="${MAINTAIN_PHP_AT_VERSION:-7.0}"
MAINTAIN_POSTGRES_AT_VERSION="${MAINTAIN_POSTGRES_AT_VERSION:-9.5}"
MAINTAIN_NODE_AT_VERSION="${MAINTAIN_NODE_AT_VERSION:-9}"

# if any arguments are passed use them
# otherwise use UPGRADE_PACK env var (defaults to basic if not specified).
# UPGRADE_ADHOC is used to allow single method 'arg' calls to be made.
[ $# -eq 0 ] && UPGRADE_PACK="${UPGRADE_PACK:-full}" || UPGRADE_PACK="adhoc"

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!      IMPORTANT      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#   This upgrade script should be run "out of work hours" as it can change default
#   binary paths for php and postgres, thus interrupting existing running processes.
#   
#  

chmod 777 . || true

# packer set nounset on -u, turn it off for our script as CONFIG_ONLY may not be defined
[ -e ./provision.sh ] && source ./provision.sh || {
  echo -e "failed to load provision.sh - stopping !"
  exit 1
}

pushd "$(mktemp -d '/tmp/tmp.XXXXX')" && chmod 777 . || true

set +u
echo -e "⚡️ Starting upgrade to version: ${UPGRADE_BOX_VERSION} - ${UPGRADE_PACK}\n"

log_build_meta ${UPGRADE_BOX_VERSION}

rpm_versions "${UPGRADE_PACK}_pre_upgrade_6.1.1-11.5.0"

function prepare() {
  yum -y -q install yum-presto || true
  yum -y -q makecache fast || true
  disable_blackfire
  fix_letsencrypt_certificate_issue
}

args=("$@")
[ $# -eq 0 ] && {

    case "$UPGRADE_PACK" in
    developer)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")
        args+=("composer" "git2" "node" "nginx")
        args+=( "php73" "php74" "php80" "php81" "php82" "maintain_php" "rabbitmq" "postgresql13" "postgresql14" "postgresql15" "phptesting" "docker" "mysql80")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] full upgrade for laravel 9 and dev platform\n\t${args[*]}"
        ;;
    full)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")
        args+=("composer" "git2" "node" "nginx")
        args+=("php80" "php81" "php82" "maintain_php" "rabbitmq" "postgresql13" "postgresql14" "postgresql15" "maintain_postgres" "mysql80")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] full upgrade for laravel 9 and dev platform\n\t${args[*]}"
        ;;
    standard)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")      
        args+=("composer" "git2" "node" "nginx")
        args+=("php80" "php81" "php82" "maintain_php" "rabbitmq" "postgresql13" "postgresql14" "postgresql15")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] minimum upgrades laravel 9\n\t${args[*]}"
        ;;
    upgrade)
        # 1st step in upgrading 6.1.1 VM
        args+=("prepare") # always call prepare
        args+=("os_support_updates")
        args+=("composer" "git2" "node" "nginx" "rabbitmq" )
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] prep upgrades supporting Laravel 9 ( NSS-1351 )\n\t${args[*]}"
        ;;
    upgrade_php)
        # 2nd step in upgrading 6.1.1 VM
        args+=("prepare") # always call prepare
        args+=("php80" "php81" "php82" "maintain_php")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] php upgrades supporting Laravel 9 ( NSS-1351 )\n\t${args[*]}"
        ;;      
    upgrade_postgres)
        # 3rd step in upgrading 6.1.1 VM -  do this after 'upgrade' has been run.        
        args+=("prepare") # always call prepare
        args+=("postgresql95") # postgresql95 is run to install extensions.
        args+=("postgresql13" "postgresql14" "postgresql15") # prepare for new rdbms
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] postgres upgrades for new platform for Laravel 9 ( NSS-1351 )\n\t${args[*]}"
        ;;
    minimum)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")      
        args+=("composer" "git2" "node" "nginx")
        args+=("php80" "php81" "php82" "maintain_php")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] minimum upgrades laravel 8\n\t${args[*]}"
        ;;
    basic)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")      
        args+=("composer" "git2" "node")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] basic os upgrades\n\t${args[*]}"
        ;;
    yum_update)
        args+=("prepare") # always call prepare
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] yum updates only\n\t${args[*]}\n"
        yum -y update
        ;;
    *) ;;

    esac
}

echo -e "$(date +"%Y%m%d_%H%M%S_%s"):Upgrade Tasks:START: ${args[*]}" | tee -a /root/build.info

# yum_cleanup
#set_profile

#yum_prepare
#yum_install

[[ "${args[*]}" =~ 'prepare' ]] && {
    prepare
}

#install_supervisor
#install_node
[[ "${args[*]}" =~ 'node' ]] && {
    upgrade_node
}

[[ "${args[*]}" =~ 'os_support_updates' ]] && {
    update_services # update already installed services to latest (redis, beanstalkd)
    os_support_updates
    reconfigure_supervisord
}

[[ "${args[*]}" =~ 'nginx' ]] && {
    upgrade_nginx
}

declare -f get_php_version >/usr/sbin/switch_php.sh || true
declare -f switch_php >>/usr/sbin/switch_php.sh && echo "source /usr/sbin/switch_php.sh" >>/root/.bash_profile

#install_php_remi 7.0 && configure_php_remi 7.0
#install_php_remi 7.1 && configure_php_remi 7.1
#install_php_remi 7.2 && configure_php_remi 7.2
[[ "${args[*]}" =~ 'php73' ]] && {
    install_php_remi 7.3 && configure_php_remi 7.3 upgrade
}
[[ "${args[*]}" =~ 'php74' ]] && {
    install_php_remi 7.4 && configure_php_remi 7.4 upgrade
}
[[ "${args[*]}" =~ 'php80' ]] && {
    install_php_remi 8.0 && configure_php_remi 8.0 upgrade
}
[[ "${args[*]}" =~ 'php81' ]] && {
    install_php_remi 8.1 && configure_php_remi 8.1 upgrade
}
[[ "${args[*]}" =~ 'php82' ]] && {
    install_php_remi 8.2 && configure_php_remi 8.2 upgrade
}

[[ "${args[*]}" =~ 'composer' ]] && {
    upgrade_composer
}

[[ "${args[*]}" =~ 'phptesting' ]] && {
    install_phpunit
    install_chromebrowser # Dusk tests require it
}

[[ "${args[*]}" =~ 'maintain_php' ]] && {
    # ensure script returns to expected PHP version
    switch_and_cycle_all_php_version 
    switch_php "$MAINTAIN_PHP_AT_VERSION"
}

[[ "${args[*]}" =~ 'node' ]] && {
    # ensure script returns to expected PHP version
    source /root/.bashrc
    nvm alias default "$MAINTAIN_NODE_AT_VERSION" && nvm use default || true
}

[[ "${args[*]}" =~ 'docker' ]] && {
    install_docker
}

[[ "${args[*]}" =~ 'mysql80' ]] && {
    install_mysql80
    configure_mysql 8
    systemctl disable mysqld.service
}

[[ "${args[*]}" =~ 'git2' ]] && {
    install_git2
}

#install_sqlite

#install_postgresql 9.5
#install_pghashlib 9.5
#configure_postgresql 9.5

#install_postgresql 9.6
#install_pghashlib 9.6
#configure_postgresql 9.6

#install_postgresql 10
#install_pghashlib 10
#configure_postgresql 10

declare -f switch_postgres >/usr/sbin/switch_postgres.sh && echo "source /usr/sbin/switch_postgres.sh" >>/root/.bash_profile

[[ "${args[*]}" =~ 'postgresql95' ]] && {
    PGPORT="${PGPORT:-5432}"
    echo -e "Assuming postgres 95 is already installed...\nInstalling extensions.\n"
    install_postgres_plpython 9.5    
    install_postgres_fdw_redis 9.5
    echo -e "\n✨ extensions for postgresql 9.5"
    su - postgres -c "psql -U postgres -p $PGPORT -c '\dx'"
    unset PGPORT    
}
[[ "${args[*]}" =~ 'pg95_switch' ]] && {
    PGPORT="${PGPORT:-5432}"
    switch_postgres 9.5
}

[[ "${args[*]}" =~ 'postgresql12' ]] && {
    PGPORT="${PGPORT:-5434}"
    install_postgresql 12
    initdb_postgresql 12
    configure_postgresql 12
    add_postgresql_user 12 homestead secret
    install_pghashlib 12
    install_postgres_plpython 12    
    install_postgres_fdw_redis 12
    install_timescaledb_for_postgresql 12
    echo -e "\n✨ extensions for postgresql 12"
    systemctl stop postgresql-12.service
    systemctl disable postgresql-12.service
    unset PGPORT    
}
[[ "${args[*]}" =~ 'pg12_switch' ]] && {
    PGPORT="${PGPORT:-5434}"
    switch_postgres 12
    unset PGPORT    
}

[[ "${args[*]}" =~ 'postgresql13' ]] && {
    PGPORT="${PGPORT:-5436}"
    install_postgresql 13
    initdb_postgresql 13
    configure_postgresql 13
    add_postgresql_user 13 homestead secret
    install_pghashlib 13
    install_postgres_plpython 13    
    install_postgres_fdw_redis 13
    install_timescaledb_for_postgresql 13
    echo -e "\n✨ extensions for postgresql 13"
    su - postgres -c "psql -U postgres -p $PGPORT -c '\dx'"
    systemctl stop postgresql-13.service
    systemctl disable postgresql-13.service
    unset PGPORT    
}
[[ "${args[*]}" =~ 'pg13_switch' ]] && {
    PGPORT="${PGPORT:-5436}"
    switch_postgres 13
    unset PGPORT    
}

[[ "${args[*]}" =~ 'postgresql14' ]] && {
    PGPORT="${PGPORT:-5438}"
    install_postgresql 14
    initdb_postgresql 14
    configure_postgresql 14
    add_postgresql_user 14 homestead secret
    install_pghashlib 14
    install_postgres_plpython 14
    # https://github.com/nahanni/rw_redis_fdw/issues/18
    # install_postgres_fdw_redis 14 # as of 2022-09-03 fwd-redis-14 is not available.
    install_timescaledb_for_postgresql 14
    echo -e "\n✨ extensions for postgresql 14"
    su - postgres -c "psql -U postgres -p $PGPORT -c '\dx'"
    systemctl stop postgresql-14.service
    systemctl disable postgresql-14.service
    unset PGPORT
}
[[ "${args[*]}" =~ 'pg14_switch' ]] && {
    PGPORT="${PGPORT:-5438}"
    switch_postgres 14
    unset PGPORT    
}

[[ "${args[*]}" =~ 'postgresql15' ]] && {
    PGPORT="${PGPORT:-5440}"
    install_postgresql 15
    initdb_postgresql 15
    configure_postgresql 15
    add_postgresql_user 15 homestead secret
    install_pghashlib 15
    install_postgres_plpython 15
    # https://github.com/nahanni/rw_redis_fdw/issues/18
    # install_postgres_fdw_redis 15 # as of 2022-09-03 fwd-redis-14 is not available.
    # install_timescaledb_for_postgresql 15 not available yet
    echo -e "\n✨ extensions for postgresql 15"
    su - postgres -c "psql -U postgres -p $PGPORT -c '\dx'"
    systemctl stop postgresql-15.service
    systemctl disable postgresql-15.service
    unset PGPORT
}
[[ "${args[*]}" =~ 'pg15_switch' ]] && {
    PGPORT="${PGPORT:-5440}"
    switch_postgres 15
    unset PGPORT    
}

[[ "${args[*]}" =~ 'maintain_postgres' ]] && {
    # ensure script returns to expected POSTGRES version
    switch_postgres "$MAINTAIN_POSTGRES_AT_VERSION"
    unset PGPORT
}
#install_mysql
#configure_mysql 8

#install_cache_queue
#configure_cache_queue

#install_blackfire
#install_mailhog
#install_ngrok
#install_flyway
#install_wp_cli
#install_oh_my_zsh
#install_browsershot_dependencies
#install_zend_zray # not compatible with centos7 - libssl clash
#install_golang
#install_postfix
# configure_postfix_for_sendgrid $sendgrid_user $sendgrid_pass
#install_crystal
#install_heroku_tooling
#install_lucky
[[ "${args[*]}" =~ 'rabbitmq' ]] && {
    install_rabbitmq || echo "rabbitmq install returned '$?'"
}

rpm_versions "${UPGRADE_PACK}_post_upgrade_6.1.1-11.5.0"
set -u

echo -e "$(date +"%Y%m%d_%H%M%S_%s"):Upgrade Tasks:FINISH: ${args[*]}" | tee -a /root/build.info
