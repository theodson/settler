#!/usr/bin/env bash

echo "ensure you have run '$0 plugins' to install required vagrant plugins'"
if [ $# -eq 0 ]; then
    echo -e "\nUsage: $0 plugins | [vb|virtualbox] | [vm|vmware_fusion] | all"
    echo -e "\tplugins          - install required vagrant plugins"
    echo -e "\tvirtualbox|vb    - build virtualbox"
    echo -e "\tvmware_fusion|vm    - build vmware"
    echo -e "\tall              - install plugins and build both virtualbox and vmware"
    exit
fi

# install required vagrant plugin to handle reloads during provisioning
if [ "$1" == "plugins" ] || [ "$1" == "all" ]; then
    vagrant plugin install vagrant-reload

	vagrant plugin install vagrant-cachier
fi


if [ "$1" == "vb" ] || [ "$1" == "virtualbox" ] || [ "$1" == "all" ]; then

	# start with no machines
	vagrant destroy -f
	rm -rf .vagrant virtualbox-build-output.log

	time vagrant up --provider virtualbox 2>&1 | tee virtualbox-build-output.log
	vagrant halt

	echo -e "\nTo package the VM into a Vagrant box [and optionally cleanup removing VM] run the following command \n\n./package.sh vb [clean]"
fi


if [ "$1" == "vm" ] || [ "$1" == "vmware_fusion" ] || [ "$1" == "all" ]; then

	# start with no machines
	vagrant destroy -f
	rm -rf .vagrant vmware-build-output.log
	

	rm -f linux.iso
	# copy current iso images - if it exists the VMWare libraries will be updated.
	#ln /Applications/VMware\ Fusion.app/Contents/Library/isoimages/linux.iso .

	time vagrant up --provider vmware_fusion 2>&1 | tee vmware-build-output.log
	vagrant halt

    echo -e "\nTo package the VM into a Vagrant box [and optionally cleanup removing VM] run the following command \n\n./package.sh vm [clean]"
fi

