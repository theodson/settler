#!/usr/bin/env bash
git clone https://github.com/chef/bento.git

packer_options=' --on-error=abort '
packer_vars=" -var 'name=homestead-co7' -var 'memory=1024' -var 'disk_size=65536' -var 'cpus=1' "

cp -rf scripts/provision.sh bento/centos/scripts/homestead.sh

pushd bento/centos
# Add `scripts/homestead.sh` to `provisioners.scripts` after `"scripts/hyperv.sh",` in file `centos/centos-7.5-x86_64.json`
grep 'homestead.sh' centos-7.5-x86_64.json &> /dev/null || (
    lineno=$(grep -n '"scripts/cleanup.sh"' centos-7.5-x86_64.json | cut -d: -f1) && \
    echo "Attempting insert of homestead settler script at ${lineno}" && \
    ex -sc "${lineno}i|\"scripts/homestead.sh\"," -cx centos-7.5-x86_64.json )

echo packer build ${packer_options} ${packer_vars} centos-7.5-x86_64.json
packer build ${packer_options} ${packer_vars} centos-7.5-x86_64.json
[ -e packer_cache/*.iso ] && (ln packer_cache/*.iso ../../;echo "ISO linked to save re-download")
popd

# echo "adding your built box to local vagrant boxes" && vagrant box add bento/builds/centos-7.5.vmware.box --name bgdevlab/homestead-co7
