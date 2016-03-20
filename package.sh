#!/usr/bin/env bash

if [ "$1" == "vm" ] || [ "$1" == "all" ]; then

    vagrant halt
    # defrag disk (assumes running on osx)
    /Applications/VMware\ Fusion.app/Contents/Library/vmware-vdiskmanager -d .vagrant/machines/default/vmware_fusion/*-*-*-*-*/disk.vmdk
    # shrink disk (assumes running on osx)
    /Applications/VMware\ Fusion.app/Contents/Library/vmware-vdiskmanager -k .vagrant/machines/default/vmware_fusion/*-*-*-*-*/disk.vmdk
    # 'vagrant package' does not work with vmware boxes (http://docs.vagrantup.com/v2/vmware/boxes.html)
    cd .vagrant/machines/default/vmware_fusion/*-*-*-*-*/
    rm -f vmware*.log
    tar cvzf ../../../../../vmware_fusion.box *
    cd ../../../../../
    ls -lh vmware_fusion.box

    if [ "$2" == "clean" ]; then
        vagrant destroy -f
        rm -rf .vagrant
    fi

fi

if [ "$1" == "vb" ] || [ "$1" == "all" ]; then

    vagrant halt
    vagrant package --base `ls ~/VirtualBox\ VMs | grep $(basename $(pwd))` --output virtualbox.box

    ls -lh virtualbox.box

    if [ "$2" == "clean" ]; then
        vagrant destroy -f
        rm -rf .vagrant
    fi

fi

