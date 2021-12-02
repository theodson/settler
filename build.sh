#!/usr/bin/env bash
#
# building on macosx - https://learn.hashicorp.com/tutorials/packer/getting-started-install
#   brew tap hashicorp/tap && brew install hashicorp/tap/packer
#
[ $# -ne 1 ] && {
        echo -e "missing argument\nusage: $0 version ( n.n.n )" && exit 1
    };
echo $1 | egrep '[1-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}' || {
        echo -e "invalid argument, numeric release format required\nusage: $0 version ( n.n.n )" && exit 2
};
PACKER_BOX_VERSION=$1

git clone https://github.com/chef/bento.git 2>/dev/null || echo 'bento/bento dir exists - moving on ...'

packer_options=' --on-error=abort '

#packer_vars=" -var name=homestead-co7 -var memory=2048 -var disk_size=105000 -var cpus=2 -var box_basename=homestead-co7 -var version=$PACKER_BOX_VERSION "
packer_vars=" -var name=homestead-co7 -var memory=2048 -var disk_size=105000 -var cpus=2 -var version=$PACKER_BOX_VERSION "

rm -f scripts/homestead.sh &> /dev/null
cp -rf scripts/provision.sh bento/centos/scripts/homestead.sh
cat scripts/provision-${PACKER_BOX_VERSION}.sh >> bento/centos/scripts/homestead.sh

pushd bento/centos
# Add `scripts/homestead.sh` to `provisioners.scripts` after `"scripts/hyperv.sh",` in file `centos/centos-7.5-x86_64.json`
grep 'homestead.sh' centos-7.5-x86_64.json &> /dev/null || (
    lineno=$(grep -n '"scripts/cleanup.sh"' centos-7.5-x86_64.json | cut -d: -f1) && \
    echo "Attempting insert of homestead settler script at ${lineno}" && \
    ex -sc "${lineno}i|\"scripts/homestead.sh\"," -cx centos-7.5-x86_64.json )

# Ensure simple partitioning
lineno=$(grep -n '^autopart' http/7/ks.cfg | cut -d: -f1)
if [ ! -z $lineno ]; then
    # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/sect-kickstart-syntax
    # Disk partitioning information
    echo "Attempting insert of simple auto partition for kickstart file at ${lineno}" && \
    ex -sc "${lineno}d" -cx http/7/ks.cfg 
    ex -sc "${lineno}i|part /boot --fstype=\"xfs\" --size=1024" -cx http/7/ks.cfg 
    ex -sc "$((++lineno))i|part pv.01 --size 1 --grow" -cx http/7/ks.cfg 
    ex -sc "$((++lineno))i|volgroup centos pv.01" -cx http/7/ks.cfg 
    ex -sc "$((++lineno))i|logvol / --fstype=\"xfs\" --size=4096 --grow --vgname=centos --name=lv_root" -cx http/7/ks.cfg 
    ex -sc "$((++lineno))i|logvol swap --size=8192 --vgname=centos --name=lv_swap" -cx http/7/ks.cfg 
    ex -sc "$((++lineno))i|logvol /tmp --fstype=\"xfs\" --size=1024 --vgname=centos --name=lv_tmp" -cx http/7/ks.cfg 
fi

# Add VERSIONING information into homestead.sh
grep 'PACKER_BOX_VERSION=' scripts/homestead.sh &> /dev/null || (
    lineno=4 && \
    echo "Attempting insert of PACKER_BOX_VERSION into homestead settler script at ${lineno}" && \
    ex -sc "${lineno}i|PACKER_BOX_VERSION=${PACKER_BOX_VERSION=}" -cx scripts/homestead.sh )


echo packer build ${packer_options} ${packer_vars} centos-7.5-x86_64.json

packer validate ${packer_vars} centos-7.5-x86_64.json && 
packer build ${packer_options} ${packer_vars} centos-7.5-x86_64.json
[ -e packer_cache/*.iso ] && (ln packer_cache/*.iso ../../;echo "ISO linked to save re-download")
popd

# echo "adding your built box to local vagrant boxes" && vagrant box add bento/builds/homestead-co7.vmware.box --name bgdevlab/homestead-co7
