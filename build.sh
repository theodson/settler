#!/usr/bin/env bash

# install required vagrant plugin to handle reloads during provisioning
vagrant plugin install vagrant-reload
if [ "$1" == "plugins" ]; then

	vagrant plugin install vagrant-cachier
	exit
fi


if [ "$1" == "vb" ] || [ "$1" == "all" ]; then

	# start with no machines
	vagrant destroy -f
	rm -rf .vagrant virtualbox-build-output.log

	time vagrant up --provider virtualbox 2>&1 | tee virtualbox-build-output.log
	vagrant halt

	echo -e "\nTo package the VM into a Vagrant box [and optionally cleanup removing VM] run the following command \n\n./package.sh vb [clean]"
fi


if [ "$1" == "vm" ] || [ "$1" == "all" ]; then

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

