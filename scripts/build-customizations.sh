#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

ARCH=$(arch)

echo "### Settler Build Configuration ###"
echo "ARCH             = ${ARCH}"
echo "### Settler Build Configuration ###"

# Update Package List
sudo apt install -y \
    httpie iftop inotify-tools jq ngrep nmap openconnect sntp poppler-utils \
    traceroute tree virt-what python3-docutils python-setuptools network-manager \
    mlocate

# Common postgresql extensions
sudo apt install -y \
    postgresql-plpython3-15

# RESH - Context-based replacement for zsh and bash shell history. Full-text search your shell history.
# curl -fsSL https://raw.githubusercontent.com/curusarn/resh/master/scripts/rawinstall.sh | bash

# MOTD - override with a custom static build version of motd
echo "export ENABLED=0"| tee -a /etc/default/motd-news

SETTLER_VERSION="${SETTLER_VERSION:-v13.0.0}"
HOMESTEAD_VERSION="${HOMESTEAD_VERSION:-Homestead v14.5.0}"
cat <<SETTLER_BUILD_MOTD >/etc/motd
 _                               _                 _
| |                             | |               | |
| |__   ___  _ __ ___   ___  ___| |_ ___  __ _  __| |
|  _ \ / _ \|  _   _ \ / _ \/ __| __/ _ \/ _  |/ _  |
| | | | (_) | | | | | |  __/\__ \ ||  __/ (_| | (_| |
|_| |_|\___/|_| |_| |_|\___||___/\__\___|\__,_|\__,_|

* $HOMESTEAD_VERSION | Thanks for using Homestead
* $SETTLER_VERSION (vmware-ubuntu)
* Tweaked Version Build Date: $(date)

SETTLER_BUILD_MOTD

