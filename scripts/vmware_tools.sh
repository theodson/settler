#!/usr/bin/env bash

# Vmware Tools

yum -y install perl

echo "answer AUTO_KMODS_ENABLED yes" | tee -a /etc/vmware-tools/locations || true

/usr/bin/vmware-config-tools.pl -d || true
