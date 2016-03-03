#!/usr/bin/env bash
HOME_DIR="${HOME_DIR:-/home/vagrant}";


update_vmware_tools() {

    echo "[vmware_tools] update and install"

    yum -y group install 'Development Tools'

    # Upgrade the VMWare tools if iso is supplied.
    mkdir -p /tmp/vmfusion;
    mkdir -p /tmp/vmfusion-archive;

    mount -o loop $HOME_DIR/linux.iso /tmp/vmfusion;

    tar xzf /tmp/vmfusion/VMwareTools-*.tar.gz -C /tmp/vmfusion-archive;
    umount /tmp/vmfusion;

    /bin/vmware-uninstall-tools.pl
    /tmp/vmfusion-archive/vmware-tools-distrib/vmware-install.pl -d || true

}


# Vmware Tools
echo "[vmware_tools] preparing for vmware tools install"
yum -y install perl

# An issue 'Waiting for HGFS kernel module to load...' exists when privisioning VMware based vagrant box -
# this might fix it - http://dantehranian.wordpress.com/2014/08/19/vagrant-vmware-resolving-waiting-for-hgfs-kernel-module-timeouts/
echo "answer AUTO_KMODS_ENABLED yes" | tee -a /etc/vmware-tools/locations || true

if [ -e $HOME_DIR/linux.iso ]; then
    # lets upgrade
    update_vmware_tools
else
    echo "[vmware_tools] configure vmware tools"
    /usr/bin/vmware-config-tools.pl -d || true
fi



