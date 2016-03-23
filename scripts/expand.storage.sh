#!/usr/bin/env bash

if [ -e /etc/redhat-release ] && [ "$1" == "grow" ] ; then

    # On the GUEST

    # https://ma.ttias.be/increase-a-vmware-disk-size-vmdk-formatted-as-linux-lvm-without-rebooting/
    # http://superuser.com/questions/332252/creating-and-formating-a-partition-using-a-bash-script
    if [ ! -e fdisk_done ]; then
        fdisk /dev/sda <<EOF
n
p
3


t
3
8e
w
EOF
        touch fdisk_done
        reboot
    fi

    pvcreate /dev/sda3
    vlg=$(vgdisplay | grep 'VG Name'| sed 's/[[:space:]]//g' | sed 's/VGName//')
    vgextend $vlg /dev/sda3
    pvscan
    lvextend /dev/${vlg}/LogVol00 /dev/sda3
    resize2fs /dev/${vlg}/LogVol00

fi

hddsize=120

if [[ "$OSTYPE" == "darwin"* ]]; then
    # On the HOST

    if [ "$1" == "vb" ]; then

        vagrant halt

        # http://stackoverflow.com/questions/11659005/how-to-resize-a-virtualbox-vmdk-file

        buildvm_id=$(echo $(VBoxManage list vms | grep $(cat .vagrant/machines/default/virtualbox/id)) | cut -d '"' -f 2)
        buildhdd_uuid=$(VBoxManage list hdds | grep -F5 $buildvm_id | grep '^UUID'|cut -d ':' -f 2- | sed 's/ //g')
        buildhdd_path=/$(VBoxManage list hdds | grep -F5 $buildvm_id | grep '^Location'|cut -d '/' -f 2- )

        pushd ~/VirtualBox*VMs/${buildvm_id}
        echo -e "buildvm_id    : ${buildvm_id}\nbuildhdd_uuid : ${buildhdd_uuid}\nbuildhdd_path : ${buildhdd_path}"

        ls "$buildhdd_path"

        VBoxManage clonehd "${buildhdd_path}" "cloned.vdi" --format vdi
        VBoxManage modifyhd "cloned.vdi" --resize "$((1024 * $hddsize))"

        # remove original DISK from VM and archive it just in case.
        VBoxManage storageattach "${buildvm_id}" --medium none --storagectl "SATA Controller" --port 0

        VBoxManage closemedium disk ${buildhdd_uuid}
        mv "${buildhdd_path}" "${buildhdd_path}_original"

        VBoxManage clonehd cloned.vdi "${buildhdd_path}" --format vmdk
        # Attach newly resized HD
        VBoxManage storageattach "${buildvm_id}" --medium "${buildhdd_path}" --storagectl "SATA Controller" --port 0 --type hdd

    elif [ "$1" == "vm" ]; then

        vagrant halt

        "/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager" -x ${hddsize}Gb .vagrant/machines/default/vmware_fusion/*-*-*-*-*/disk.vmdk

    fi

    echo "Restart the VM without provisioning"
    echo "Run the commands $0 grow in the GUEST CentOS VM"

fi
