#!/usr/bin/env bash
#
# provision homestead 11.5.0 (php-8.0 php-8.1 introduced).
#
if [ $# -gt 0 ] && [ $1 = "config" ]; then
    CONFIG_ONLY=1
fi

MAINTAIN_PHP_AT_VERSION="${MAINTAIN_PHP_AT_VERSION:-8.0}"
MAINTAIN_NODE_AT_VERSION="${MAINTAIN_NODE_AT_VERSION:-17}"

# packer set nounset on -u, turn it off for our script as CONFIG_ONLY may not be defined
[ -e ./provision.sh ] && source ./provision.sh

set +u
echo -e "Starting build for version: ${PACKER_BOX_VERSION}\n"
rpm_versions pre_provision_11.5.0
disable_blackfire
fix_letsencrypt_certificate_issue

yum clean all && rm -rf /var/cache/yum/* || true
yum -y -q install yum-presto || true
yum -y -q makecache fast || true
set_profile

yum_prepare
yum_install

install_supervisor
reconfigure_supervisord
#install_node
upgrade_node

update_services # update already installed services to latest (redis, beanstalkd)
os_support_updates
reconfigure_supervisord

install_nginx
upgrade_nginx

# install switch_php for root - take current function from this script and export to file
declare -f get_php_version >/usr/sbin/switch_php.sh || true
declare -f switch_php >>/usr/sbin/switch_php.sh && echo "source /usr/sbin/switch_php.sh" >>/root/.bash_profile
install_php_remi 7.0 switch && configure_php_remi 7.0
install_php_remi 7.1 switch && configure_php_remi 7.1
install_php_remi 7.2 switch && configure_php_remi 7.2
install_php_remi 7.3 switch && configure_php_remi 7.3
install_php_remi 7.4 switch && configure_php_remi 7.4
install_php_remi 8.0 switch && configure_php_remi 8.0
install_php_remi 8.1 switch && configure_php_remi 8.1
install_php_remi 8.2 switch && configure_php_remi 8.2
switch_php 8.1
nvm alias default "$MAINTAIN_NODE_AT_VERSION" && nvm use default || true

upgrade_composer
install_phpunit
install_chromebrowser # Dusk tests require it
install_docker

install_git2

install_sqlite

install_postgresql 9.5
initdb_postgresql 9.5
configure_postgresql 9.5
add_postgresql_user 9.5 homestead secret
install_pghashlib 9.5
install_postgres_plpython 9.5    
install_postgres_fdw_redis 9.5

declare -f switch_postgres > /usr/sbin/switch_postgres.sh && echo "source /usr/sbin/switch_postgres.sh" >> /root/.bash_profile

PGPORT=5436
install_postgresql 13
initdb_postgresql 13
configure_postgresql 13
add_postgresql_user 13 homestead secret
install_pghashlib 13
install_postgres_plpython 13    
install_postgres_fdw_redis 13
install_timescaledb_for_postgresql 13
unset PGPORT

PGPORT=5438
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

PGPORT=5440
install_postgresql 15
initdb_postgresql 15
configure_postgresql 15
add_postgresql_user 15 homestead secret
install_pghashlib 15
install_postgres_plpython 15    
# https://github.com/nahanni/rw_redis_fdw/issues/18
# install_postgres_fdw_redis 14 # as of 2022-09-03 fwd-redis-14 is not available.
install_timescaledb_for_postgresql 15
unset PGPORT

install_mysql80
configure_mysql # untested with 80!
systemctl disable mysqld && systemctl stop mysqld


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
install_crystal
install_heroku_tooling
install_lucky
install_rabbitmq

disable_blackfire

log_build_meta ${PACKER_BOX_VERSION}
rpm_versions post_provision_11.5.0

set -u
