#!/usr/bin/env bash
# Example on Apple Silicon: bin/register-local-box.sh ../bento/builds/ubuntu-24.04-aarch64.vmware.box 17.0.4 arm64

homestead_name="laravel/homestead"
homestead_box="${1:-builds/ubuntu-24.04-x86_64.vmware.box}"
homestead_version="${2:-17.0.4}"
homestead_arch="${3:-$(uname -m)}" # either amd64|arm64 

if [ ! -e $homestead_box ]; then
    echo "✋ Cannot find source box $homestead_box"
    exit 1
fi

echo -e "Vagrant boxes registered\n=======================\n$(vagrant box list | grep $homestead_name)\n"

read -p "register    $homestead_name as version [ $homestead_version ] ? " ver
homestead_version="${ver:-$homestead_version}"
echo -e "registering $homestead_name : $homestead_version"

vagrant box add --force --name $homestead_name --architecture $homestead_arch $homestead_box
# this will always result in a 'box version 0' being registered.

box_base_dir="$HOME/.vagrant.d/boxes/$(echo $homestead_name | sed 's/\//-VAGRANTSLASH-/')"

# manually move box version 0 to a specified versioned box
#src_box="$box_base_dir/0/vmware_desktop"
src_box=$(find "$box_base_dir/0" -path '*/vmware_desktop' | grep $(uname -m))
ver_box="$box_base_dir/$homestead_version/$homestead_arch/"

if [ -e "$src_box" ]; then
    mkdir -p $ver_box &>/dev/null
    mv "$src_box" "$ver_box"
    echo "📦 Registered $homestead_name ($homestead_version) to $ver_box"
else
    echo "✋ Cannot find source folder $src_box"
    exit 1
fi
