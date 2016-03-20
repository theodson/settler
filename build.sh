#!/usr/bin/env bash

echo "remove any virtualbox.box or vmware_fusion.box files as build will NOT override them"

if [ "$1" == "plugins" ]; then
	# install required vagrant plugin to handle reloads during provisioning
	vagrant plugin install vagrant-reload

	vagrant plugin install vagrant-cachier
	exit
fi


if [ "$1" == "vb" ] || [ "$1" == "all" ]; then

	# start with no machines
	vagrant destroy -f
	rm -rf .vagrant virtualbox-build-output.log

	time vagrant up --provider virtualbox 2>&1 | tee virtualbox-build-output.log
	vagrant halt

fi


if [ "$1" == "vm" ] || [ "$1" == "all" ]; then

	# start with no machines
	vagrant destroy -f
	rm -rf .vagrant vmware-build-output.log
	
	# copy current iso images
	rm -f linux.iso
	#ln /Applications/VMware\ Fusion.app/Contents/Library/isoimages/linux.iso .

	time vagrant up --provider vmware_fusion 2>&1 | tee vmware-build-output.log
	vagrant halt

fi

