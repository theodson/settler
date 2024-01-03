# Laravel/Homestead on VMWare 
How the build a Larvel/Homestead VM for for VMWare + Extend features.

- The target virtualisation platform is VMWare.
- Discover how best to extend build whilst maintaining vagrant/homestead compatibility.

## TLDR
To generate a new VM see the [Build the VM](#build-the-vm) section below.

# Discovery Research

The VM is based on the standard build process as used for the Laravel/Homestead VM.   
Laravel/Homestead VM is generated combining both `laravel/settler` and `chef/bento`.
VMWare support has been dropped in the standard Laravel/Homestead VM builds from v13+.

Vagrant boxes are available at vagrantup, supported Virt platforms for pre build images are listed here. 
https://app.vagrantup.com/laravel/boxes/homestead

This Vagrant Repository of VM boxes shows the latest `Laravel/Vagrant` box to be version 13.
#### v13
Version 13 does **not support VMware**, only virtualbox, parallels, and libvert.
- https://github.com/laravel/settler/releases/tag/v13.0.0
- https://app.vagrantup.com/laravel/boxes/homestead/versions/13.0.0

#### v12.1.0
Version **12.1.0** is the **last official version** that supports VMWare. 
To use the latest version on VMWare you must **build your own**.  

- https://github.com/laravel/settler/releases/tag/v12.1.0
- https://app.vagrantup.com/laravel/boxes/homestead/versions/12.1.0

See issues
- [No longer providing Hyper-V or VMware base boxes #1606](https://github.com/laravel/homestead/issues/1606)

# Build the VM

To build the homestead VM checkout **laravel/settler** and **chef/bento** projects. 

This is for Homestead 14 and Settler 13 - Ubuntu 20.

> Note: Settler v14 homestead build as  of 2023-12 is still in development.
> It uses main line bento which has switched from `bento/ubuntu-20.04` to `bento/ubuntu-22.04`


- `laravel/settler`
  - Clone the forked [laravel/settler](https://github.com/theodson/settler) project.
  - Checkout branch for v13 (if no branch, find `v13` tag with the most recent commit before the `v14` tag), see any notes in `readme.md`.
- `chef/bento`
  - Clone [chef/bento](https://github.com/chef/bento) at same dir level (_directory siblings_) as the settler project.
  - Checkout branch `bento_old_json_templates` - this branch in compatible with the v13 build.
- `laravel/homestead` 
  - _this deviates from standard settler build_
  - Clone [laravel/homestead](https://github.com/laravel/homestead) at same dir level (_directory siblings_) as the settler project.


``` 
mkdir vmbuild && \
cd vmbuild && \
git clone https://github.com/theodson/settler -b ubuntu-vmware && \ 
git clone https://github.com/chef/bento -b bento_old_json_templates && \
git clone https://github.com/laravel/homestead
```

Expected directory structure

```
├── bento
├── homestead
└── settler 
```


Link Laravel settler files to the bento project. 
```
pushd settler 

# when running on macOs fix sed if required (check for -i '' first)
if uname | grep -qi darwin;  then 
    grep -q "sed -i '' " bin/link-to-bento.sh || sed -i '' "s#sed -i '#sed -i '' '#"  bin/link-to-bento.sh; 
fi

./bin/link-to-bento.sh
```
These linked files are pivotal and control how the VM is built
- packer_templates/ubuntu/scripts/homestead.sh
- packer_templates/ubuntu/ubuntu-20.04-amd64.json
- packer_templates/ubuntu/http/preseed.cfg

## Optional Features inclusion

### _using Homestead Features_
This non standard "features" build process uses the feature scripts of the Laravel/Homestead project.
To use the features in the base VM build run use the following command.
> Warning! Experimental WIP 
``` 
bin/use_homestead_features.sh
```

Work from bento project for the remainder of tasks.  
Follow normal [Packer](https://www.packer.io/) practice of building `ubuntu/ubuntu-20.04-amd64.json`

``` 
pushd ../bento/packer_templates/ubuntu && \
packer build -only=vmware-iso ubuntu-20.04-amd64.json
```
The generated VM will be placed in the builds directory, `builds/ubuntu-20.04.vmware.box`

## Locally register the generated VM as a vagrant box
This is to allow Homestead build testing using the generated VM.
```
cd ../../ # change to base of the bento project

homestead_version=13.0.0
homestead_arch=amd64
vagrant box add --force --name laravel/homestead --architecture $homestead_arch builds/ubuntu-20.04.vmware.box

# manually move to versioned box  
src_box=$HOME/.vagrant.d/boxes/laravel-VAGRANTSLASH-homestead/0/vmware_desktop
ver_box=$HOME/.vagrant.d/boxes/laravel-VAGRANTSLASH-homestead/$homestead_version/$homestead_arch/ 
if [ -e "$src_box" ]; then
    mkdir -p $ver_box &>/dev/null
    mv "$src_box" "$ver_box"
fi    
    
vagrant box list    
```


# Extension points
A requirement for building a VM is to maintain vagrant/homestead compatibility.
- Any extension mechanism should honour this requirement.
- Any extention script should follow chosen compatible conventions where possible.

## 1 - `bento build` process
This is the earliest point at which to customize the generated VM.


1 - Add scripts to the existing, and already overridden, `packer_templates/ubuntu/scripts/homestead.sh` file. 
> Adding any new scripting should be done during and before the tidy section. These lines (see below) 
mark the start of the _tidy up_ section of the script, we should capitalize on that cleanup also.

The ⚡️ [use_homestead_features.sh](bin/use_homestead_features.sh) script performs the feature updates.
```
# SCRIPTS INSERTED HERE

# One last upgrade check
apt-get upgrade -y

# Clean Up
```

## 2 - Vagrant Homestead `feature scripts`
This approach utilises the convention of loading shell scripts from the 
`vendor/laravel/homestead/scripts/features/` folder when the Homestead VM starts via Vagrant.

- The Laravel `Homestead.yml` file within an App's root folder controls which features should be loaded. 
- The feature scripts are loaded from the Host's shared/mapped folders with the VM.
- This approach relies on features being "opted in" and ran when time the VM starts (if not already ran). 

> ⚡️ The [use_homestead_features.sh](bin/use_homestead_features.sh) script pulls in the contents
> of some feature scripts during the build process. This approach allows the Vagrant Homestead
> features to be used as expected by Laravel (see `homestead.rb` / `Homestead.yaml` ). 

## 3 - Vagrant Homestead `after.sh` or `user-customizations.sh` scripts
This is an existing Homestead convention of running the `after.sh` or `user-customizations.sh` script when the VM starts.

> 💡 This is a good way to test scripts during development of the required VM.
> These scripts could be refined and used in the `bento build` process as described above.


# Ubuntu

## Network

### Install NetworkManager to allow `nmtui`.



https://osnote.com/how-to-install-and-use-networkmanager-nmcli-on-ubuntu/

https://computingforgeeks.com/install-and-use-networkmanager-nmcli-on-ubuntu-debian/?expand_article=1

https://www.nixcraft.com/t/ubuntu-error-connection-activation-failed-connection-is-not-available-on-device-because-device-is-strictly-unmanaged/4533/2

https://ubuntu.com/core/docs/networkmanager/networkmanager-and-netplan



```
sudo apt install -y network-manager
sudo systemctl start NetworkManager


# Allow NetworkManager to manage the eth0 device

# 1. add except:type:ethernet
vim /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf

# 2. add device to manager
nmcli dev set eth0 managed yes

# 3. restart network
systemctl restart NetworkManager

# check settings
ip link show
```





## Database

### pghashlib

https://github.com/bgdevlab/pghashlib.git

needs `rst2html` installing, so use

```
sudo apt install python3-docutils
```

then clone and make

```
git clone https://github.com/bgdevlab/pghashlib.git
cd pghashlib/
make
make install

# install extension
sudo su - postgres -c "psql -U postgres -c 'CREATE EXTENSION hashlib;'"
sudo su - postgres -c "psql -U postgres -c \"select encode(hash128_string('abcdefg', 'murmur3'), 'hex');\""

# package the build extension
tar -czf ubuntu-20-postgresql-15.hashlib.tgz $(find /usr/share/doc/postgresql-doc-15/  /usr/lib/postgresql/15/lib/bitcode/hashlib /usr/lib/postgresql/15/lib/hashlib.so /usr/share/postgresql/15/extension/hash*)

```

resulting in

```
/bin/mkdir -p '/usr/lib/postgresql/15/lib'
/bin/mkdir -p '/usr/share/postgresql/15/extension'
/bin/mkdir -p '/usr/share/postgresql/15/extension'
/bin/mkdir -p '/usr/share/doc/postgresql-doc-15/extension'
/usr/bin/install -c -m 755  hashlib.so '/usr/lib/postgresql/15/lib/hashlib.so'
rst2html README.rst > hashlib.html
/usr/bin/install -c -m 644 .//hashlib.control '/usr/share/postgresql/15/extension/'
/usr/bin/install -c -m 644 .//sql/hashlib--1.0.sql .//sql/hashlib--unpackaged--1.0.sql .//sql/hashlib--1.1.sql .//sql/hashlib--unpackaged--1.1.sql .//sql/hashlib--1.0--1.1.sql  '/usr/share/postgresql/15/extension/'
/usr/bin/install -c -m 644 .//hashlib.html '/usr/share/doc/postgresql-doc-15/extension/'
/bin/mkdir -p '/usr/lib/postgresql/15/lib/bitcode/hashlib'
/bin/mkdir -p '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/pghashlib.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/crc32.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/lookup2.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/lookup3.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/inthash.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/murmur3.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/pgsql84.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/city.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/spooky.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/md5.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
/usr/bin/install -c -m 644 src/siphash.bc '/usr/lib/postgresql/15/lib/bitcode'/hashlib/src/
cd '/usr/lib/postgresql/15/lib/bitcode' && /usr/lib/llvm-10/bin/llvm-lto -thinlto -thinlto-action=thinlink -o hashlib.index.bc hashlib/src/pghashlib.bc hashlib/src/crc32.bc hashlib/src/lookup2.bc hashlib/src/lookup3.bc hashlib/src/inthash.bc hashlib/src/murmur3.bc hashlib/src/pgsql84.bc hashlib/src/city.bc hashlib/src/spooky.bc hashlib/src/md5.bc hashlib/src/siphash.bc
vagrant@vagrant:~/pghashlib$ systemctl start postgresql.service 

```

# Homestead Packages
Packages to install via Homestead helper scripts.

These packages are driven by [Homestead.yaml](..%2Flaravel-homestead%2Fresources%2FHomestead.yaml)

| Name           | Notes                               |
|----------------|-------------------------------------|
| golang         |                                     |
| mailpit        |                                     |
| minio          |                                     |
| python         | remove some pip packages afterwards |
| rabbitmq.sh    |                                     |
| rustc.sh       |                                     |
| timescaledb.sh | dev only                            |
| webdriver.sh   | dev only                            |

# Differences

| Item      | CentOS-7 11.5 | Ubuntu-20 13 | Version | Notes |
|-----------|---------------|--------------|---------|-------|
| blackfire | disabled      |              |         |

