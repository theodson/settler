# Laravel/Homestead on VMWare 
How the build a Larvel/Homestead VM for for VMWare + Extend features.

- The target virtualisation platform is VMWare.
- Discover how best to extend build whilst maintaining vagrant/homestead compatibility.

## TLDR
To generate a new VM see the [Build the VM](#build-the-vm) section below.

Or clone this repo and run
```
bash bin/build 
```
or specify versions (_for display purposes only_)
``` 
SETTLER_VERSION=13.0.1 HOMESTEAD_VERSION=14.5.1 bash bin/build
```

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
  - 💡 _this deviates from standard settler build_
  - Clone [laravel/homestead](https://github.com/laravel/homestead) at same dir level (_directory siblings_) as the settler project.
- `adhoc provision scripts`
  - 💡 _this deviates from standard settler build_ - allows for any custom scripts to be packaged in the box
  - `mkdir settler-provision-scripts` at same dir level (_directory siblings_) as the settler project.


``` 
mkdir vmbuild && vmbuild && \
git clone https://github.com/theodson/settler -b ubuntu-vmware && \ 
git clone https://github.com/chef/bento -b bento_old_json_templates && \
git clone https://github.com/theodson/homestead -b support/14 && \

export vmbuild="$(pwd)"
```

Copy or clone any additional scripts that should be copied into VM's `/home/vagrant/.provision-scripts` for later use.
```
mkdir -p settler-provision-scripts/features

# or clone your custom repo
git clone https://github.com/yourscripts settler-provision-scripts
```

Expected directory structure of `$vmbuild`

```
├── bento
├── homestead
├── settler
└── settler-provision-scripts  
```

```
# on macOs fix sed
pushd "$vmbuild/settler" && source bin/macos-sed-fix 
```

Link Laravel settler files to the bento project. 
```
pushd "$vmbuild/settler" && bin/link-to-bento.sh 
```

These linked files are pivotal and control how the VM is built
- packer_templates/ubuntu/scripts/homestead.sh
- packer_templates/ubuntu/ubuntu-20.04-amd64.json
- packer_templates/ubuntu/http/preseed.cfg

## Optional Features inclusion

### _using Homestead Features_
This non standard "features" build process uses the feature scripts of the Laravel/Homestead project.
To use the features in the base VM build run use the following command.

```
pushd "$vmbuild/settler" && bin/use-homestead-features.sh
```

Work from bento project for the remainder of tasks.  
Follow normal [Packer](https://www.packer.io/) practice of building `ubuntu/ubuntu-20.04-amd64.json`

```
pushd "$vmbuild/bento/packer_templates/ubuntu" 
packer build -only=vmware-iso ubuntu-20.04-amd64.json

```
The generated VM will be placed in the builds directory, `builds/ubuntu-20.04.vmware.box`

## Locally register the generated VM as a vagrant box
This is to allow Homestead build testing using the generated VM.

```
bash "$vmbuild/settler/bin/register-local-box.sh" "$vmbuild/bento/builds/ubuntu-20.04.vmware.box" 13.0.3
    
vagrant box list    
```

## Use vagrant box to create OVA

> ... continuing on from Locally register the vagrant box.

We can create a useful OVA file for use outside of Vagrant by following these steps.
Your mileage may vary...  💨 🍃

### vagrant up
Create a VM with your recently locally built and registered box. 
Create a project that uses Homestead, you may need to specify version and provider in your `Homestead.yaml`, e.g. 

```yaml
box: laravel/homestead
version: 13.0.3
SpeakFriendAndEnter: true # allows custom vagrant box usage easily - see vendor/laravel/homestead/scripts/homestead.rb:21
provider: vmware_fusion
```

and run 
```bash
vagrant up
```

### prepare the VM

shutdown the os from within the VM

```bash
sudo shutdown -h now
```

then, form within the VMWare Fusion tool 
- remove all of the network devices - this will remove any MAC address references 
- add a new network device (note don't generate a mac address... leave it blank) 

> the VM mush be shutdown for this step.

### export the VM as a single file OVA 
via the VMWare Fusion menu `File > Export to OVF`.

### extract and tidy meta info ( the .ovf file ).
This step attempts to tidy and remove any redundant VM configuration.

> terminal with access to the export OVA file.
```bash
mkdir homestead-14.5
tar -xvf  homestead-14.5.ova -C homestead-14.5
cd homestead-14.5
```

edit the `homestead-14.5.ovf` file
```bash
vim homestead-14.5.ovf
```
- remove any refrences to ethernet1 or above, there should only be ethernet0
- remove any references to local filepath/shared folder config

> As the OVA contains checksums to ensure no corruptions exist when being imported 
> the checksum list in the `homestead-14.5.mf` file should be updated with a new/correct sha256 checksum
> for the edited .ovf file.

```bash
# note the checksum output of this command for use in the .mf file.
sha256sum homestead-14.5.ovf
```
edit the `homestead-14.5.mf` file and update the checksum as generated above.
```bash
vim homestead-14.5.mf
```

### re-package the OVA
The OVA is a tar archive and can be created with the tar command.

> in this example we create a new named OVA - homestead-14.5.new.ova
```bash
tar -cvf homestead-14.5.new.ova homestead-14.5.ovf homestead-14.5.mf homestead-14.5-disk1.vmdk
```

This OVA can now be shared and used directly in VMWare products.


# Extension points
A requirement for building a VM is to maintain vagrant/homestead compatibility.
- Any extension mechanism should honour this requirement.
- Any extention script should follow chosen compatible conventions where possible.

## 1 - `bento build` process
This is the earliest point at which to customize the generated VM.


1 - Add scripts to the existing, and already overridden, `packer_templates/ubuntu/scripts/homestead.sh` file. 
> Adding any new scripting should be done during and before the tidy section. These lines (see below) 
mark the start of the _tidy up_ section of the script, we should capitalize on that cleanup also.

The ⚡️ [use-homestead-features.sh](bin/use-homestead-features.sh) script performs the feature updates.
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

> ⚡️ The [use-homestead-features.sh](bin/use-homestead-features.sh) script pulls in the contents
> of some feature scripts during the build process. This approach allows the Vagrant Homestead
> features to be used as expected by Laravel (see `homestead.rb` / `Homestead.yaml` ). 

## 3 - Vagrant Homestead `after.sh` or `user-customizations.sh` scripts
This is an existing Homestead convention of running the `after.sh` or `user-customizations.sh` script when the VM starts.

> 💡 This is a good way to test scripts during development of the required VM.
> These scripts could be refined and used in the `bento build` process as described above.


# Ubuntu

## Network
References
- [A declarative approach to Linux networking with Netplan](https://ubuntu.com/blog/a-declarative-approach-to-linux-networking-with-netplan)
- [Netplan - The network configuration abstraction renderer](https://netplan.io/)
- [Netplan configuration Tutorial](https://linuxconfig.org/netplan-network-configuration-tutorial-for-beginners)
- [Ubuntu-Core : NetworkManager and Netplan](https://ubuntu.com/core/docs/networkmanager/networkmanager-and-netplan)
### Networking with `Netplan`

`Netplan` is an utility developed by Canonical, the company behind Ubuntu. 

It provides a network configuration abstraction over the currently supported two “backend” systems, (or “renderer” in Netplan terminology): [**networkd**](https://manpages.ubuntu.com/manpages/bionic/man5/systemd.network.5.html) and [**NetworkManager**](https://help.ubuntu.com/community/NetworkManager?_ga=2.26244542.2094251110.1707949859-1548780367.1706577989).   
Using Netplan, both physical and virtual network interfaces are configured via yaml files which are translated to configurations compatible with the selected backend.  
On Ubuntu 20.04 Netplan replaces the traditional method of configuring network interfaces using the `/etc/network/interfaces` file; it aims to make things easier and more centralized.

> The old way of configuring interfaces can still be used: check the article "How to switch back networking to /etc/network/interfaces" on Ubuntu 20.04 Focal Fossa Linux). 

![netplan_design_overview.svg](netplan_design_overview.svg))
#### Netplan configuration files

There are three locations in which Netplan configuration files can be placed; in order of priority they are:

- /run/netplan
- /etc/netplan
- /lib/netplan

### Prefer NetworkManager to configure network using `nmcli` and `nmtui`  

To allow the use of `nmtui` the network-manager package should be installed.
> Although `netplan` generates backend configuration for networkd or NetworkManager this process
appears to be a 1-way conversion from the netplan yaml files to the appropriate backend configuration.
This means using tools like nmtui can make the network configuration fall out of sync.
  
 


### via `snap install network-manager` 
> 👍 This is the **preferred way to use network-manager** as changes made in either netplan or nmcli or nmtui are synchronsous/2-way.

https://ubuntu.com/core/docs/networkmanager/networkmanager-and-netplan

From Ubuntu core20 onwards, network-manager been modified to use a YAML backend that’s based on libnetplan functionality.

The YAML backend replaces the keyfile format used by Network Manager with /etc/Netplan/*.yaml.
On boot the Netplan.io generator processes all of the YAML files and renders them into the corresponding a Network Manager configuration in /run/NetworkManager/system-connections.
The usual Netplan generate/try/apply can be used to re-generate this configuration after the YAML was modified.

If a connection profile is modified or created from within Network Manager, such as updating a WiFi password with nmcli, Network Manager will create an ephemeral keyfile that will be immediately converted to Netplan YAML and stored in /etc/Netplan.  
Network Manager automatically calls Netplan generate to re-process the current YAML configuration to render Network Manager connection profiles in /run/NetworkManager/system-connections.

```bash
sudo apt remove network-manager
sudo apt install snapd -y
sudo snap install network-manager
```

```bash
sudo tar -cvzf /tmp/netplan.pre_snap.tgz /etc/netplan/*
rm -f /etc/netplan/* || true
sudo rm -f /run/NetworkManager/system-connections/* || true

sudo apt remove network-manager || true
sudo apt install snapd -y || true
sudo snap install network-manager 

sudo truncate -s 0 /etc/machine-id;
sudo rm -f /root/.wget-hsts /home/vagrant/.wget-hsts /home/vagrant/.bash_history /root/.bash_history;
export HISTSIZE=0;
sudo shutdown -h now;
export HISTSIZE=0
```


### via `apt install network-manager` 
> ✋ Using network-manager tools installed via apt means that changes made by nmtui or nmcli are not reflected back into netplan! It can be considered a 1 way relationship.
> As such this is **not the preferred way to install and use network-manager**.

- https://osnote.com/how-to-install-and-use-networkmanager-nmcli-on-ubuntu/
- https://computingforgeeks.com/install-and-use-networkmanager-nmcli-on-ubuntu-debian/?expand_article=1
- https://www.nixcraft.com/t/ubuntu-error-connection-activation-failed-connection-is-not-available-on-device-because-device-is-strictly-unmanaged/4533/2

```
sudo apt install -y network-manager
sudo systemctl start NetworkManager


# Allow NetworkManager to manage the eth0 device

# 1. add except:type:ethernet
vim /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf

sudo sed -i '/^\[keyfile\]/ a unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma,except:type:ethernet' /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf

# 2. find and add device to manager
network='192.168.4'
ethid=$(ip route show | grep 'default' | grep "$network" | cut -d' ' -f5)

nmcli dev set $ethid managed yes

# 3. restart network
sudo systemctl restart NetworkManager

# check settings
ip link show
```

### DNS when remote dev
Assuming the VM is running on a host (macOs) that is VPN connected to work network (10.20.1.x).

> Assuming VM is started with Vagrant and has multiple interfaces we ping external DNS server
> and if there is a response discover what route is taken.
> See https://notes.enovision.net/linux/changing-dns-with-resolve 

```
dnsip=10.20.1.26
yourdomain=yourcompany.com
yourserver=repo.yourcompany.com

ip route
ping $dnsip  

# discover which interface to ipaddress 
traceroute $dnsip

# route taken appears to use eth0 so set DNS for this device 
sudo systemd-resolve --interface eth0 --set-dns $dnsip --set-domain $yourdomain
# NOTE: not sure if this is persistent.

service systemd-resolved restart
sudo service systemd-resolved restart
systemd-resolve --status
ping $yourserver

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

