#!/usr/bin/env bash
git clone https://github.com/chef/bento.git

packer_options=' --on-error=abort '

cp -rf scripts/provision.sh bento/centos/scripts/homestead.sh

pushd bento/centos
# Add `scripts/homestead.sh` to `provisioners.scripts` after `"scripts/hyperv.sh",` in file `centos/centos-7.5-x86_64.json`
grep 'homestead.sh' centos-7.5-x86_64.json &> /dev/null || (
    lineno=$(grep -n '"scripts/cleanup.sh"' centos-7.5-x86_64.json | cut -d: -f1) && \
    echo "Attempting insert of homestead settler script at ${lineno}" && \
    ex -sc "${lineno}i|\"scripts/homestead.sh\"," -cx centos-7.5-x86_64.json )

packer build $packer_options centos-7.5-x86_64.json
popd