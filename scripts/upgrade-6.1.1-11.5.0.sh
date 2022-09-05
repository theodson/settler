#!/usr/bin/env bash
#
# upgrade homestead 6.1.1 to 11.5.0 (php-8.0 introduced at 10.1.1).
#
UPGRADE_BOX_VERSION='11.5.0<6.1.1'
MAINTAIN_PHP_AT_VERSION="${MAINTAIN_PHP_AT_VERSION:-7.0}"
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
        args+=( "php73" "php74" "php80" "php81" "maintain_php" "rabbitmq" "postgresql13" "postgresql14" "phptesting" "docker" "mysql80")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] full upgrade for laravel 9 and dev platform\n\t${args[*]}"
        ;;
    full)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")
        args+=("composer" "git2" "node" "nginx")
        args+=("php80" "php81" "maintain_php" "rabbitmq" "postgresql13" "postgresql14" "mysql80")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] full upgrade for laravel 9 and dev platform\n\t${args[*]}"
        ;;
    standard)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")      
        args+=("composer" "git2" "node" "nginx")
        args+=("php80" "php81" "maintain_php" "rabbitmq" "postgresql13" "postgresql14")
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] minimum upgrades laravel 9\n\t${args[*]}"
        ;;
    upgrade)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")
        args+=("composer" "git2" "node" "nginx")
        args+=("php80" "php81" "maintain_php" "rabbitmq" )
        # args+=("postgresql95" "postgresql13" "postgresql14") # do this separately
        echo -e "⚡️ [ UPGRADE_PACK : $UPGRADE_PACK ] minimum upgrades supporting Laravel 9 ( NSS-1351 )\n\t${args[*]}"
        ;;
    minimum)
        args+=("prepare") # always call prepare
        args+=("os_support_updates")      
        args+=("composer" "git2" "node" "nginx")
        args+=("php80" "php81" "maintain_php")
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

declare -f switch_php >/usr/sbin/switch_php.sh && echo "source /usr/sbin/switch_php.sh" >>/root/.bash_profile

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

[[ "${args[*]}" =~ 'composer' ]] && {
    upgrade_composer
}

[[ "${args[*]}" =~ 'phptesting' ]] && {
    install_phpunit
    install_chromebrowser # Dusk tests require it
}

[[ "${args[*]}" =~ 'maintain_php' ]] && {
    # ensure script returns to expected PHP version
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
    install_postgres_plpython 9.5    
    install_postgres_fdw_redis 9.5
}
[[ "${args[*]}" =~ 'pg95_switch' ]] && {
    PGPORT="${PGPORT:-5432}"
    switch_postgres 9.5
}

[[ "${args[*]}" =~ 'postgresql11' ]] && {
    PGPORT="${PGPORT:-5432}"
    install_postgresql 11
    initdb_postgresql 11
    configure_postgresql 11
    add_postgresql_user 11 homestead secret    
    install_pghashlib 11
    install_postgres_plpython 11    
    install_postgres_fdw_redis 11
    install_timescaledb_for_postgresql 11
}
[[ "${args[*]}" =~ 'pg11_switch' ]] && {
    PGPORT="${PGPORT:-5432}"
    switch_postgres 11
}

[[ "${args[*]}" =~ 'postgresql12' ]] && {
    PGPORT="${PGPORT:-5432}"
    install_postgresql 12
    initdb_postgresql 12
    configure_postgresql 12
    add_postgresql_user 12 homestead secret
    install_pghashlib 12
    install_postgres_plpython 12    
    install_postgres_fdw_redis 12
    install_timescaledb_for_postgresql 12
}
[[ "${args[*]}" =~ 'pg12_switch' ]] && {
    PGPORT="${PGPORT:-5432}"
    switch_postgres 12
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
    unset PGPORT
}
[[ "${args[*]}" =~ 'pg14_switch' ]] && {
    PGPORT="${PGPORT:-5438}"
    switch_postgres 14
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
    install_rabbitmq || echo "rabbitmq install returned $?"
}

rpm_versions "${UPGRADE_PACK}_post_upgrade_6.1.1-11.5.0"
set -u

echo -e "$(date +"%Y%m%d_%H%M%S_%s"):Upgrade Tasks:FINISH: ${args[*]}" | tee -a /root/build.info
