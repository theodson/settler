#!/usr/bin/env bash
[ $# -ne 1 ] && {
        echo -e "missing argument\nusage: $0 version ( n.n.n )" && exit 1
    };
echo $1 | egrep '[1-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}' || {
        echo -e "invalid argument, numeric release format required\nusage: $0 version ( n.n.n )" && exit 2
};
PACKER_BOX_VERSION=$1

git clone https://github.com/chef/bento.git 2>/dev/null || echo 'bento/bento dir exists - moving on ...'

packer_options=' --on-error=abort '

packer_vars=" -var name=homestead-co7 -var memory=2048 -var disk_size=105000 -var cpus=2 -var box_basename=homestead-co7 -var version=$PACKER_BOX_VERSION "

rm -f scripts/homestead.sh &> /dev/null
cp -rf scripts/provision.sh bento/centos/scripts/homestead.sh

pushd bento/centos
# Add `scripts/homestead.sh` to `provisioners.scripts` after `"scripts/hyperv.sh",` in file `centos/centos-7.5-x86_64.json`
grep 'homestead.sh' centos-7.5-x86_64.json &> /dev/null || (
    lineno=$(grep -n '"scripts/cleanup.sh"' centos-7.5-x86_64.json | cut -d: -f1) && \
    echo "Attempting insert of homestead settler script at ${lineno}" && \
    ex -sc "${lineno}i|\"scripts/homestead.sh\"," -cx centos-7.5-x86_64.json )

# Ensure simple partitioning
grep 'autopart --nohome' http/7/ks.cfg &> /dev/null || (
    lineno=$(grep -n '^autopart' http/7/ks.cfg | cut -d: -f1) && \
    echo "Attempting insert of simple auto partition for kickstart file at ${lineno}" && \
    ex -sc "${lineno}d|${lineno}i|autopart --nohome" -cx http/7/ks.cfg )


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
