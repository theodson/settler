#
# upgrade homestead 6.1.1 to 11.0.0 (php-8.0 introduced at 10.1.1).
#
UPGRADE_BOX_VERSION='11.0.0<6.1.1'

# packer set nounset on -u, turn it off for our script as CONFIG_ONLY may not be defined
[ -e ./provision.sh ] && source ./provision.sh

set +u
echo -e "Starting upgrade to version: ${UPGRADE_BOX_VERSION}\n"
rpm_versions pre_upgrade_6.1.1-10.1.1
disable_blackfire

args=("$@")
[ $# -eq 0 ] && {
  # args+=("php73" "php74" "php80" "postgresql12") # default upgrades
  args+=("php80" "postgresql12" "rabbitmq") # default upgrades
}
echo -e "\nUpgrade tasks: ${args[*]}\n"

yum-config-manager --disable blackfire &>/dev/null || true
#yum clean all && rm -rf /var/cache/yum/* || true
yum install -y yum-presto || true
yum makecache fast || true
#set_profile

#yum_prepare
#yum_install

#install_supervisor
#install_node
#install_nginx

declare -f switch_php >/usr/sbin/switch_php.sh && echo "source /usr/sbin/switch_php.sh" >>/root/.bash_profile

#install_php_remi 7.0 && configure_php_remi 7.0
#install_php_remi 7.1 && configure_php_remi 7.1
#install_php_remi 7.2 && configure_php_remi 7.2
[[ "${args[*]}" =~ 'php73' ]] && {
  install_php_remi 7.3 && configure_php_remi 7.3
}
[[ "${args[*]}" =~ 'php74' ]] && {
  install_php_remi 7.4 && configure_php_remi 7.4
}
[[ "${args[*]}" =~ 'php80' ]] && {
  install_php_remi 8.0 && configure_php_remi 8.0
}

#install_composer
#install_git2

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

[[ "${args[*]}" =~ 'postgresql11' ]] && {
  install_postgresql 11
  configure_postgresql 11
  switch_postgres 11
  install_pghashlib 11
  install_timescaledb_for_postgresql 11
}

[[ "${args[*]}" =~ 'postgresql12' ]] && {
  install_postgresql 12
  configure_postgresql 12
  switch_postgres 12
  install_pghashlib 12
  install_timescaledb_for_postgresql 12
}

[[ "${args[*]}" =~ 'postgresql13' ]] && {
  install_postgresql 13
  configure_postgresql 13
  switch_postgres 13
  install_pghashlib 13
  # install_timescaledb_for_postgresql 13 - not available for 13 as of 2021-02-14
}

#install_mysql
#configure_mysql

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
  install_rabbitmq
}

finish_build_meta ${UPGRADE_BOX_VERSION}
rpm_versions post_upgrade_6.1.1-10.1.1

set -u
