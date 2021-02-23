#
# provision homestead 10.1.1 (php-8.0 introduced).
#
if [ $# -gt 0 ] && [ $1 = "config" ]; then
    CONFIG_ONLY=1
fi

# packer set nounset on -u, turn it off for our script as CONFIG_ONLY may not be defined

set +u
rpm_versions pre_provision_10.1.1
echo -e "Starting build for version: ${PACKER_BOX_VERSION}\n"
yum-config-manager --disable blackfire &>/dev/null || true
yum clean all && rm -rf /var/cache/yum/* || true
yum install -y yum-presto || true
yum makecache fast || true
set_profile

yum_prepare
yum_install

#install_supervisor
install_node
install_nginx

# install switch_php for root - take current function from this script and export to file
declare -f switch_php > /usr/sbin/switch_php.sh && echo "source /usr/sbin/switch_php.sh" >> /root/.bash_profile
install_php_remi 7.0 && configure_php_remi 7.0
install_php_remi 7.1 && configure_php_remi 7.1
install_php_remi 7.2 && configure_php_remi 7.2
install_php_remi 7.3 && configure_php_remi 7.3
install_php_remi 7.4 && configure_php_remi 7.4
install_php_remi 8.0 && configure_php_remi 8.0
switch_php 8.0

install_composer
install_git2

install_sqlite

install_postgresql 9.5
install_pghashlib 9.5
configure_postgresql 9.5

install_postgresql 9.6
install_pghashlib 9.6
configure_postgresql 9.6

install_postgresql 10
install_pghashlib 10
configure_postgresql 10

declare -f switch_postgres > /usr/sbin/switch_postgres.sh && echo "source /usr/sbin/switch_postgres.sh" >> /root/.bash_profile

install_postgresql 11
configure_postgresql 11
switch_postgres 11
install_pghashlib 11
install_timescaledb_for_postgresql 11

install_postgresql 12
configure_postgresql 12
switch_postgres 12
install_pghashlib 12
install_timescaledb_for_postgresql 12

install_postgresql 13
configure_postgresql 13
switch_postgres 13
install_pghashlib 13
# install_timescaledb_for_postgresql 13 - not available for 13 as of 2021-02-14

switch_postgres 12

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
install_crystal
install_heroku_tooling
install_lucky
install_rabbitmq

disable_blackfire

finish_build_meta ${PACKER_BOX_VERSION}
rpm_versions post_provision_10.1.1
set -u
