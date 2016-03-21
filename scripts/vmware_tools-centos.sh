#!/usr/bin/env bash
HOME_DIR="${HOME_DIR:-/home/vagrant}";

update_vmware_tools() {

    echo "[vmware_tools] update and install : START"

    yum -y group install 'Development Tools'
    yum -y install perl kernel-headers gcc

    # Upgrade the VMWare tools if iso is supplied.
    mkdir -p /tmp/vmfusion;
    mkdir -p /tmp/vmfusion-archive;

    mount -o loop $HOME_DIR/linux.iso /tmp/vmfusion;

    tar xzf /tmp/vmfusion/VMwareTools-*.tar.gz -C /tmp/vmfusion-archive;
    umount /tmp/vmfusion;

    /bin/vmware-uninstall-tools.pl
    /tmp/vmfusion-archive/vmware-tools-distrib/vmware-install.pl -d || true
    echo "[vmware_tools] update and install : FINISH"

    echo "answer AUTO_KMODS_ENABLED yes" | tee -a /etc/vmware-tools/locations || true
}

yum -y install virt-what

# check we are running in vmware.
virt-what | grep 'vmware'
if [ $? -eq 0 ]; then
    if [ -e $HOME_DIR/linux.iso ]; then
        # lets upgrade
        update_vmware_tools

    else
        # An issue 'Waiting for HGFS kernel module to load...' exists when privisioning VMware based vagrant box -
        # this might fix it - http://dantehranian.wordpress.com/2014/08/19/vagrant-vmware-resolving-waiting-for-hgfs-kernel-module-timeouts/
        echo "answer AUTO_KMODS_ENABLED yes" | tee -a /etc/vmware-tools/locations || true

        /usr/bin/vmware-config-tools.pl -d || true
    fi
fi



