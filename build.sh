#!/usr/bin/env bash

echo "remove any virtualbox.box or vmware_fusion.box files as build will NOT override them"

if [ "$1" == "plugins" ]; then
	# install required vagrant plugin to handle reloads during provisioning
	vagrant plugin install vagrant-reload

	# install proxy helper for slow connections (for repeated builds)
	#vagrant plugin install vagrant-proxyconf
fi


if [ "$1" == "vb" ] || [ "$1" == "all" ]; then

	# start with no machines
	vagrant destroy -f
	rm -rf .vagrant

	time vagrant up --provider virtualbox 2>&1 | tee virtualbox-build-output.log
	vagrant halt
	vagrant package --base `ls ~/VirtualBox\ VMs | grep $(basename $(pwd))` --output virtualbox.box

	ls -lh virtualbox.box
	vagrant destroy -f
	rm -rf .vagrant
fi


if [ "$1" == "vm" ] || [ "$1" == "all" ]; then

	# start with no machines
	vagrant destroy -f
	rm -rf .vagrant
	
	# copy current iso images
	rm -f linux.iso
	ln /Applications/VMware\ Fusion.app/Contents/Library/isoimages/linux.iso .

	time vagrant up --provider vmware_fusion 2>&1 | tee vmware-build-output.log
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
	rm -f linux.iso

	vagrant destroy -f
	rm -rf .vagrant
fi