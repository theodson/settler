#!/usr/bin/env bash

# TODO REVIEW Match YUM install to APT install
#yum -y install \
#autoconf make automake sendmail sendmail-cf m4 virt-what \
#vim mlocate curl htop wget dos2unix tree \
#ntp nmap nc whois libnotify inotify-tools telnet ngrep bind-utils traceroute \
#cyrus-sasl-plain supervisor mailx mutt netcat \
#bash-completion-extras mcrypt vim cifs-utils zsh re2c pv \
#jq httpie mod_ssl httpd ntpdate poppler-utils \
#python-setuptools python-pip \
#iftop \
#yum-utils docker-ce docker-ce-cli containerd.io \
#python3 postgresql15-contrib postgresql15-plpython3 \
#redis memcached beanstalkd \
#httpie jq openconnect \
#libsodium libsodium-devel 
## prov-extra
#yum -y install \
#httpie jq openconnect \
#libsodium libsodium-devel 

for package in autoconf make automake sendmail sendmail-cf m4 virt-what vim mlocate curl htop wget dos2unix tree ntp nmap nc whois libnotify inotify-tools telnet ngrep bind-utils traceroute cyrus-sasl supervisor mailx mutt netcat bash-completion-extras mcrypt vim cifs-utils zsh re2c pv jq httpie mod_ssl httpd ntpdate poppler-utils python-setuptools python-pip iftop yum-utils docker-ce docker-ce-cli containerd.io python3 postgresql15-contrib postgresql15-plpython3 redis memcached beanstalkd httpie jq openconnect libsodium libsodium-devel; do
        sudo apt info $package &>/dev/null || echo "unknown $package"
        sudo apt info $package &>/dev/null && echo "matched $package"
done | tee packages.list

#for package in autoconf make automake sendmail sendmail-cf m4 virt-what vim mlocate curl htop wget dos2unix tree ntp nmap nc whois libnotify inotify-tools telnet ngrep bind-utils traceroute cyrus-sasl supervisor mailx mutt netcat bash-completion-extras mcrypt vim cifs-utils zsh re2c pv jq httpie mod_ssl httpd ntpdate poppler-utils python-setuptools python-pip iftop yum-utils docker-ce docker-ce-cli containerd.io python3 postgresql15-contrib postgresql15-plpython3 redis memcached beanstalkd httpie jq openconnect libsodium libsodium-devel; do
#       apt list --installed 2>/dev/null | grep -q $package && echo "found $package" || echo "missing $package"
#done | tee package.matching

for package in $(grep '^matched' packages.list | cut -d ' ' -f2)
do
        apt list --installed 2>/dev/null | grep -q $package && echo "installed $package" || echo "missing $package"
done
# the above can be placed in check-packages.sh file - then run 
bash ./check-packages.sh | grep -v '^matched' | sort > packages.status
cat package.status| sort | uniq | grep 'missing' | cut -d' ' -f2 | xargs > packages.install
cat package.status| sort | uniq | grep 'unknown' | cut -d' ' -f2 | xargs > packages.findalt



# apt equivalents
sudo apt install -y \
  httpie iftop inotify-tools jq ngrep nmap openconnect sntp poppler-utils traceroute tree virt-what \
  python3-docutils postgresql-plpython3-15 python-setuptools \
  network-manager 

sudo apt install -y openjdk-17-jdk-headless openjdk-8-jdk-headless mlocate 

#  apt alternatives
ntpdate - ntpdate is deprecated. Please use sntp instead for manual or scripted NTP queries/syncs.
  

# TODO REVIEW Apache EnableSendfile
# Fix small file cache issue on vagrant mounts - http://stackoverflow.com/questions/6298933/shared-folder-in-virtualbox-for-apache
sed -i 's/^EnableSendfile on/EnableSendfile off/'  /etc/httpd/conf/httpd.conf

# TODO REVIEW HISTTIMEFORMAT
echo 'export HISTTIMEFORMAT="%Y-%m-%d - %H:%M:%S "' >> /etc/profile

# TODO - Install JAVA

# TODO - Install NVM

# TODO - REVIEW POSTGRESQL Extensions
# REDIS FDW - https://github.com/nahanni/rw_redis_fdw/issues/18
# plpython3u - python3 postgresql15-contrib postgresql15-plpython3
# pghashlib - https://github.com/bgdevlab/pghashlib

# TODO - FileSystem PERMISSIONS
# this fixes upload failures due to inability towrite to tmp folder.
sudo chown -R nginx:nginx /var/lib/nginx /var/lib/nginx/tmp
sudo chmod -R g+s /var/lib/nginx /var/lib/nginx/tmp


# TODO - REVIEW these helper functions compatability
source ./additional_functions.sh
# install switch_php for root - take current function from this script and export to file
declare -f get_php_version >/usr/sbin/switch_php.sh || true
declare -f switch_php >>/usr/sbin/switch_php.sh && echo "source /usr/sbin/switch_php.sh" >>/root/.bash_profile
