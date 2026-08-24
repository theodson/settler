# Laravel/Homestead on VMWare
<!-- TOC -->
* [Laravel/Homestead on VMWare](#laravelhomestead-on-vmware)
  * [TLDR](#tldr)
  * [Source Code Repositories Setup](#source-code-repositories-setup)
    * [Clone repositories](#clone-repositories)
  * [MacOs Setup](#macos-setup)
  * [Customise Features inclusion](#customise-features-inclusion)
    * [_using Homestead Features_](#_using-homestead-features_)
  * [Full Build Process](#full-build-process)
  * [Locally register the generated VM as a vagrant box](#locally-register-the-generated-vm-as-a-vagrant-box)
  * [Create OVA from a Vagrant box](#create-ova-from-a-vagrant-box)
    * [vagrant up](#vagrant-up)
    * [Prepare the VM](#prepare-the-vm)
    * [Modify the VM definition before OVA conversion](#modify-the-vm-definition-before-ova-conversion)
    * [Convert to OVA](#convert-to-ova)
    * [Modify the VM definition after OVA conversion](#modify-the-vm-definition-after-ova-conversion)
      * [1. Tidy meta information in the `.ovf` file.](#1-tidy-meta-information-in-the-ovf-file)
      * [2. Checksum update of the `.mf` file.](#2-checksum-update-of-the-mf-file)
      * [Repack the OVA - order is mandatory](#repack-the-ova---order-is-mandatory)
* [Apple Silicon Notes](#apple-silicon-notes)
* [`bento` Build Extension points](#bento-build-extension-points)
  * [1 - `bento build` process](#1---bento-build-process)
    * [1b - `settler-firstboot` service](#1b---settler-firstboot-service)
  * [2 - Vagrant Homestead `feature scripts`](#2---vagrant-homestead-feature-scripts)
  * [3 - Vagrant Homestead `after.sh` or `user-customizations.sh` scripts](#3---vagrant-homestead-aftersh-or-user-customizationssh-scripts)
<!-- TOC -->

How the build a Larvel/Homestead VM for for VMWare + Extend features.

- The target virtualisation platform is VMWare.
- Discover how best to extend build whilst maintaining vagrant/homestead compatibility.

## TLDR
> Targeting Apple Silicon VM running VMware Fusion on Ubuntu 24 and trying to satisfy requirements for Laravel Homestead

You must have cloned all repositories and be on the correct branches as defined below before running this TLDR quick start!!

``` 
SETTLER_VERSION=16.0.0 HOMESTEAD_VERSION=17.0.4 bash bin/build
```
or rely on default

```
bash bin/build 
```

Then package it for distribution to the Mac mini fleet:

```
bash bin/package
```

That finds the box the build just produced, generalizes the guest, and writes a
double-clickable `.vmwarevm` plus a `.dmg` to `dist/`. See
[packaging.md](packaging.md) for the whole story, including why the
OVA section further down this page no longer applies on Apple Silicon.


## Source Code Repositories Setup
**Mandatory Setup**: This is for Homestead 17 and Settler 16 - Ubuntu 24.

### Clone repositories
```bash
# setup source code repositories within parent build folder.
mkdir vmbuild && vmbuild && \
git clone https://github.com/theodson/settler -b ubuntu-vmware-16 && \ 
git clone https://github.com/theodson/bento -b settler-homestead && \
git clone https://github.com/theodson/homestead -b support/17 && \

export vmbuild="$(pwd)"
```

Expected directory structure of `$vmbuild`

```
├── bento
├── homestead
└── settler
```

- `laravel/settler`
    - Clone the forked [theodson/settler](https://github.com/theodson/settler) project.
    - Checkout branch for `ubuntu-vmware-16` (if no branch, find `16` tag with the most recent commit before the `v14` tag), see any notes in `readme.md`.
- `chef/bento`
    - Clone the forked [theodson/bento](https://github.com/theodson/bento) at same dir level (_directory siblings_) as the settler project.
    - Checkout branch `settler-homestead`
- `laravel/homestead`
    - 💡 _this deviates from standard settler build_
    - Clone [theodson/homestead](https://github.com/theodson/homestead.git) at same dir level (_directory siblings_) as the settler project.
- `adhoc provision scripts`
    - Checkout branch `support/17`
    - 💡 _this deviates from standard settler build_ - allows for any custom scripts to be packaged in the box

**Note**: Settler v14 homestead build as of 2023-12 is still in development.
It uses main line bento which has switched from `bento/ubuntu-20.04` to `bento/ubuntu-22.04`,
Since then (2025) the project has been retired by Laravel but github contributer `svpernova09` has continued active
development of both `setter` https://github.com/svpernova09/settler.git and  and `homestead` https://github.com/svpernova09/homestead.



## MacOs Setup

Install VMWare Fusion app, `packer`, `vagrant` and vagrant `vmware-utility` plugins

```bash
# packer and vagrant
brew tap hashicorp/tap
brew install hashicorp/tap/packer
brew install hashicorp/tap/hashicorp-vagrant
```

Install VMWare Fusion and `vagrant plugin`
```bash
# plugins
brew install --cask vagrant-vmware-utility
sudo vagrant plugin install vagrant-vmware-desktop
```

Note: If the vagrant vmware utility fails during builds try the following dmg file.
https://developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility

```bash
http --download https://releases.hashicorp.com/vagrant-vmware-utility/1.0.24/vagrant-vmware-utility_1.0.24_darwin_arm64.dmg
open vagrant-vmware-utility_1.0.24_darwin_arm64.dmg
```

Note: troubleshooting notes when issues occurred with the vagrant-vmware-utility tool.
```
# Notes from manual investigation, I think the DMG should do this automatically.

sudo mkdir -p /opt/vagrant-vmware-desktop/bin
open vagrant-vmware-utility_1.0.24_darwin_*.dmg

sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility certificate generate
sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility service install

sudo launchctl unload -w /Library/LaunchDaemons/com.vagrant.vagrant-vmware-utility.plist
sudo launchctl load -w /Library/LaunchDaemons/com.vagrant.vagrant-vmware-utility.plist

sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility service uninstall
sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility service install -port=9999
```

## Customise Features inclusion

> 📦 This is part of the `bin/build` script.

Prior to building a VM, scripts are included to allow for easier customization of features enabled for the VM build.

### _using Homestead Features_
This **non standard** "features" build process uses the feature scripts of the **Laravel/Homestead** project.  
To use the features in the base VM build run use the following command.

See the listed inclusions for both arm64 and amd64 in the `use-homestead-features.sh` file, lines that match
```bash
....
for feature in openjdk-17 openjdk-8 postgres-pghashlib
....
```

```
pushd "$vmbuild/settler" && bin/use-homestead-features.sh
```

Work from bento project for the remainder of tasks.  
Follow normal [Packer](https://www.packer.io/) practice of building `ubuntu/ubuntu-24.04-amd64.json`

```
pushd "$vmbuild/bento/packer_templates/ubuntu" 
packer build -only=vmware-iso ubuntu-24.04-amd64.json

```
The generated VM will be placed in the builds directory, `builds/ubuntu-24.04.vmware.box`



## Full Build Process

```bash
# set environment vars
SETTLER_VERSION="${SETTLER_VERSION:-16.0.0}"
HOMESTEAD_VERSION="${HOMESTEAD_VERSION:-17.0.4}"
export SETTLER_VERSION HOMESTEAD_VERSION
```

```bash
# build vm
bash bin/build
```

**Note:** To **debug** issues using packer builds you can use `export PACKER_LOG=1`

```bash
# DEBUG packer builds by exporting or prepending PACKER_LOG=1
PACKER_LOG=1 packer build -only=vmware-iso.vm \
    -var-file=os_pkrvars/ubuntu/ubuntu-24.04-x86_64.pkrvars.hcl \
    -var headless=false ./packer_templates
```

## Locally register the generated VM as a vagrant box
This is to allow Homestead build testing using the generated VM.

```bash
bash bin/register-local-box.sh ../bento/builds/ubuntu-24.04-aarch64.vmware.box 17.0.4
```
or
```
bash "$vmbuild/settler/bin/register-local-box.sh" "$vmbuild/bento/builds/ubuntu-24.04-x86_64.vmware.box" 17.0.4
```

check boxes registered:
```bash
vagrant box list    
```

## Create OVA from a Vagrant box

> ⛔️ **Superseded on Apple Silicon. Do not use this for the ARM64 fleet.**
>
> Fusion on Apple Silicon cannot import OVA/OVF, so an OVA produced by the
> steps below will not open on the Mac mini fleet - `ovftool` was never
> updated for Arm workflows and both import and export are affected.
>
> **Use [packaging.md](packaging.md) instead**, which packages the
> box directly as a double-clickable `.vmwarevm` bundle plus a `.dmg`:
>
> ```bash
> bin/package-vmwarevm.sh ../bento/builds/ubuntu-24.04-aarch64.vmware.box
> ```
>
> That is not just a workaround - it is strictly less work. A `*.vmware.box`
> is already a gzipped tar of a complete VMware VM directory, so no
> conversion, descriptor editing or checksum repacking is needed at all.
>
> The steps below are retained for the **x86_64 Intel fleet only**.

> Assuming the build VM has been locally registered.

We can create a useful OVA file for use outside of Vagrant by following these steps.
This process is evolving and active work in progress.

### vagrant up
Create a VM with your recently locally built and registered box.
Create a project that uses Homestead, you may need to specify version and provider in your `Homestead.yaml`, e.g.

```bash
# from the settler folder
mkdir -p scratch/homestead17
pushd scratch/homestead17
vagrant init --box-version 17.0.4 laravel/homestead
```

The `Homestead.yaml` would include this
```yaml
box: laravel/homestead
version: 17.0.4
SpeakFriendAndEnter: true # allows custom vagrant box usage easily - see vendor/laravel/homestead/scripts/homestead.rb:21
provider: vmware_fusion
```

and run
```bash
vagrant up
```

### Prepare the VM

Shutdown the vm

```bash
# within vm linux
sudo shutdown -h now
```

### Modify the VM definition before OVA conversion
Now the VM is shutdown, from within the VMWare Fusion tool we can modify its definition.

- remove all of the network devices - this will remove any MAC address references
- add a new network device (note don't generate a mac address... leave it blank)

### Convert to OVA
```bash
ovftool $HOME/.vagrant.d/boxes/laravel-VAGRANTSLASH-homestead/17.0.4/arm64/vmware_desktop/ubuntu-24.04-aarch64.vmx \
    $HOME/Downloads/homestead-arm.17.0.4.ova
```

### Modify the VM definition after OVA conversion


#### 1. Tidy meta information in the `.ovf` file.
This step follows a process of extracting the files within the .OVA (a tar file) in order to  
tidy the meta info ( within the associated .ovf file ) and remove any redundant VM configuration

```bash
# extract OVA in temporary directory
mkdir homestead-arm.17.0.4
tar -xvf $HOME/Downloads/homestead-arm.17.0.4.ova -C homestead-arm.17.0.4
cd homestead-arm.17.0.4
```

```bash
# remove any refrences to ethernet1 or above, there should only be ethernet0
# remove any references to local filepath/shared folder config
# edit the ovf file
vim homestead-arm.17.0.4.ovf
```

#### 2. Checksum update of the `.mf` file.
The OVA file contains checksums to ensure no corruptions exist when being imported.
The checksum list in the .mf file ( `homestead-arm.17.0.4.mf` ) should be updated with a corrected **sha256 checksum**
for the edited .ovf file.

```bash
# note the checksum output of this command for use in the .mf file.
sha256sum homestead-arm.17.0.4.ovf
```

```bash
# edit the `homestead-arm.17.0.4.mf` file and update the checksum as generated above.
vim homestead-arm.17.0.4.mf
```

#### Repack the OVA - order is mandatory
The OVA is a tar archive and can be created with the tar command.
The OVF must be the first entry, manifest second, disks after.
This is the one real gotcha: OVA is designed for streaming import, so a hypervisor reads the descriptor
before it's seen the disks. A tar with the files in alphabetical order will extract fine but fail to import.

```bash
tar -cvf homestead-arm.17.0.4.new.ova homestead-arm.17.0.4.ovf homestead-arm.17.0.4.mf homestead-arm.17.0.4-disk1.vmdk
```

```bash
tar -cvf homestead-arm.17.0.4.new.ova homestead-arm.*.ovf homestead-arm.*.mf *.vmdk
```

This OVA can now be shared and used directly in VMWare products.

----


# Apple Silicon Notes

This is the Broadcom Fusion guide for working with Apple Silicon. This may be useful if you need to:
- configure the VM from **outside** the packer template
- configure VMs from the packer templates
- configure the OS at all
  [Broadcom: The Unofficial Fusion for Apple Silicon Companion Guide](https://community.broadcom.com/vmware-cloud-foundation/viewdocument/the-unofficial-fusion-for-apple-sil?CommunityKey=0c3a2021-5113-4ad1-af9e-018f5da40bc0&tab=librarydocuments)

At the time of writing (2026) some limitations exist.
- "Networks with custom subnet/mask values are not supported"
    - https://github.com/clong/DetectionLab/issues/602,
    - https://github.com/hashicorp/vagrant/issues/13367
- Export OVA on Apple Silicon is NOT SUPPORTED - https://community.broadcom.com/communities/community-home/digestviewer/viewthread?GroupId=7165&MessageKey=9f6c5e41-a4b6-4de2-a82b-da45ac3dff77&CommunityKey=0c3a2021-5113-4ad1-af9e-018f5da40bc0


Note: the `arch` and `uname` command can be used to distinguish the platform, both on the Apple Silicon host and withing the guest arm based VM.

Apple silicon `arm64/arm`

```bash
# bash on Apple Silicon ARM

arch
arm64 

uname -p
arm

uname -m
arm64
```

Within VM Ubuntu on Apple Silicon `aarch64`

```bash
# bash on Ubuntu/Debian ARM based VM

arch
aarch64

uname -p
aarch64

uname -m
aarch64
```

Apple Intel OS (64bit)
```bash
arch
i386

uname -p
i386

uname -m
x86_64
```

Within VM Ubuntu on Apple Intel `x86_64`
```bash
# bash on Ubuntu/Debian Intel based VM
arch
x86_64

uname -p
x86_64

uname -m
x86_64
```


# `bento` Build Extension points

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

### 1b - `settler-firstboot` service

⚡️ [inject-firstboot.sh](bin/inject-firstboot.sh) uses the same mechanism to
splice the first-boot identity service into the tidy section of
`scripts/{arm,amd64}.sh`, so the built box ships with it installed.

The definition lives in [vm-generalize.sh](bin/vm-generalize.sh) between its
`SETTLER_FIRSTBOOT_BEGIN`/`END` markers and is copied in verbatim — run
`bin/inject-firstboot.sh --check` to confirm the two have not drifted.

`bin/build` runs this automatically, after the git reset and after
`use-homestead-features.sh`. `scripts/*.sh` stay pristine in git; the block
only exists during a build. See [packaging.md](packaging.md).

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
