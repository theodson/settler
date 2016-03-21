#!/usr/bin/env bash
if [ -e /etc/redhat-release ]; then
    source ./vmware_tools-centos.sh
    exit
fi

# Vmware Tools

apt-get install -y linux-headers-$(uname -r) build-essential

echo "answer AUTO_KMODS_ENABLED yes" | tee -a /etc/vmware-tools/locations || true

/usr/bin/vmware-config-tools.pl -d || true
