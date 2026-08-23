#!/usr/bin/env bash
#
# vm-generalize.sh
#
# Run this INSIDE the guest, as root, immediately before shutting it down for
# packaging. It removes the identity the build gave the VM and installs a
# first-boot service that mints a new one.
#
#     sudo bash vm-generalize.sh
#     sudo shutdown -h now
#
# Why the host-side scripts are not enough
# ----------------------------------------
# bin/package-vmwarevm.sh and bin/install-vm.sh give every deployed copy a
# unique *virtual hardware* identity - new UUID, new MAC, its own name in
# Fusion's library. None of that reaches inside the guest. Five clones of one
# image running on one Mac mini will still share:
#
#   /etc/machine-id           systemd's identity. DHCP clients on Ubuntu derive
#                             their DUID from it, so all five ask the DHCP
#                             server for the same lease and take turns losing.
#   /etc/ssh/ssh_host_*_key   the SSH host keys. Every VM presents the same
#                             fingerprint, which defeats the check that host
#                             keys exist to perform, and trips
#                             REMOTE HOST IDENTIFICATION HAS CHANGED on the
#                             admin's machine as they move between VMs.
#   /etc/hostname             all five call themselves the same thing, so no
#                             log line or shell prompt says which one you are on.
#
# What the first-boot service does
# --------------------------------
# On first power-on the VM reads the instance name that bin/install-vm.sh wrote
# into the .vmx (guestinfo.settler.instance) and uses it to set its hostname.
# It regenerates the machine-id and the SSH host keys whether or not that key
# is present, then disables itself. If no name was supplied it falls back to
# the existing hostname plus a short random suffix, so clones stay distinct
# even when the VM is installed by hand rather than by the script.
#
# Options
# -------
#   --zerofill      overwrite free space with zeros instead of trimming it.
#                   Only for small disks - see the warning in section 4. Capped
#                   by ZEROFILL_MAX_MB (default 32768) to avoid inflating a
#                   thin .vmdk until the build host runs out of room.
#   --no-reclaim    do not reclaim free space at all
#   --no-firstboot  strip identity but do not install the regeneration service
#   -h, --help      this text
#
set -euo pipefail

RECLAIM="fstrim"          # fstrim | zerofill | none
ZEROFILL_MAX_MB="${ZEROFILL_MAX_MB:-32768}"
DO_FIRSTBOOT=1

usage() { sed -n '3,48p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
    --zerofill)     RECLAIM="zerofill" ;;
    --no-reclaim)   RECLAIM="none" ;;
    --no-zerofree)  RECLAIM="none" ;;  # previous name, kept working
    --no-firstboot) DO_FIRSTBOOT=0 ;;
    -h | --help)    usage; exit 0 ;;
    *) echo "✋ unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ "$(id -u)" != "0" ]; then
    echo "✋ run this as root:  sudo bash $(basename "$0")"
    exit 1
fi

if [ ! -e /etc/debian_version ]; then
    echo "⚠️  this expects a Debian/Ubuntu guest - continuing anyway"
fi

echo "⚡️ generalizing $(hostname)"

#
# 1 - the first-boot service, installed before we strip anything
#
if [ "$DO_FIRSTBOOT" = 1 ]; then
    echo "   installing settler-firstboot.service"

# The block between these two markers is the single source of truth for the
# first-boot service. bin/inject-firstboot.sh lifts it out verbatim and splices
# it into scripts/arm.sh and scripts/amd64.sh, so a packer-built box ships with
# the service already installed and nothing has to be copied in later.
#
# Keep it self-contained: it has to run both here (inside a booted guest, with
# $DO_FIRSTBOOT in scope) and there (inside the packer provisioner, where it
# does not). Nothing in it may depend on the rest of this script.
# >>> SETTLER_FIRSTBOOT_BEGIN
    cat >/usr/local/sbin/settler-firstboot <<'FIRSTBOOT'
#!/bin/bash
# Regenerate this VM's identity on first power-on after cloning.
# Installed by settler bin/vm-generalize.sh. Disables itself when done.
#
# This runs very early - before dbus, before the network, before sshd - so it
# must not call anything that needs a system bus. In particular it uses
# `hostname` and a direct write to /etc/hostname rather than `hostnamectl`,
# which blocks indefinitely waiting for systemd-hostnamed at this stage of
# boot and will stall the whole boot if used here.
set -uo pipefail

# systemd captures stdout into the journal for us; no systemd-cat needed
# (piping to it this early both duplicates the line and risks blocking).
log() { echo "settler-firstboot: $*"; }

# The instance name comes from the .vmx, written by bin/install-vm.sh.
# vmware-rpctool ships with open-vm-tools; guard in case it is absent.
instance=""
if command -v vmware-rpctool >/dev/null 2>&1; then
    instance="$(vmware-rpctool 'info-get guestinfo.settler.instance' 2>/dev/null || true)"
fi

if [ -z "$instance" ]; then
    # Installed by hand rather than by install-vm.sh. Keep the base name but
    # make it unique, otherwise every clone answers to the same hostname.
    instance="$(hostname -s)-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    log "no guestinfo.settler.instance set, using $instance"
fi

# hostname - no hostnamectl, see the note at the top of this script
old="$(hostname -s)"
if [ "$instance" != "$old" ]; then
    echo "$instance" >/etc/hostname
    hostname "$instance" 2>/dev/null || true
    # keep /etc/hosts consistent so sudo does not stall on name lookup
    sed -i "s/\b${old}\b/${instance}/g" /etc/hosts 2>/dev/null || true
    grep -qE "^127\.0\.1\.1[[:space:]]" /etc/hosts ||
        echo "127.0.1.1	${instance}" >>/etc/hosts
    log "hostname $old -> $instance"
fi

# machine-id - systemd regenerates it when the file is empty
if [ ! -s /etc/machine-id ]; then
    systemd-machine-id-setup >/dev/null 2>&1 || true
    log "machine-id $(cat /etc/machine-id 2>/dev/null)"
fi

# ssh host keys
#
# No `systemctl restart ssh` here. This unit is ordered Before=ssh.service, so
# sshd has not started yet and will pick the new keys up on its own - and
# calling systemctl on a unit we are ordered before can deadlock the boot.
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
    ssh-keygen -A >/dev/null 2>&1 || dpkg-reconfigure -f noninteractive openssh-server >/dev/null 2>&1
    log "regenerated ssh host keys"
fi

systemctl disable settler-firstboot.service >/dev/null 2>&1 || true
log "done"
FIRSTBOOT
    chmod +x /usr/local/sbin/settler-firstboot

    cat >/etc/systemd/system/settler-firstboot.service <<'UNIT'
[Unit]
Description=Regenerate VM identity on first boot after cloning
# Must settle the hostname and machine-id before anything that depends on
# them: DHCP derives its DUID from machine-id, sshd needs its host keys.
After=local-fs.target
Before=network-pre.target ssh.service systemd-networkd.service NetworkManager.service
Wants=network-pre.target
DefaultDependencies=no

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/settler-firstboot
# Never let identity regeneration hold the boot hostage. If something in here
# blocks, systemd kills it and carries on: a VM that boots with the wrong
# hostname is recoverable, one that never finishes booting is not.
TimeoutStartSec=60
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=sysinit.target
UNIT

    chmod 644 /etc/systemd/system/settler-firstboot.service
    systemctl enable settler-firstboot.service >/dev/null 2>&1 ||
        echo "⚠️  could not enable settler-firstboot.service"
# <<< SETTLER_FIRSTBOOT_END
fi

#
# 2 - strip the identity this build picked up
#
echo "   clearing machine-id"
: >/etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

echo "   removing ssh host keys"
rm -f /etc/ssh/ssh_host_*

echo "   clearing dhcp leases"
rm -f /var/lib/dhcp/* /var/lib/dhcpcd/* 2>/dev/null || true
rm -rf /var/lib/NetworkManager/*.lease 2>/dev/null || true

# udev pins interface names to the MAC it first saw. Every clone gets a new
# MAC, so a stale rule leaves the NIC renamed and unconfigured.
echo "   removing persistent net rules"
rm -f /etc/udev/rules.d/70-persistent-net.rules \
      /etc/udev/rules.d/75-persistent-net-generator.rules 2>/dev/null || true

if [ -d /etc/cloud ]; then
    echo "   resetting cloud-init"
    cloud-init clean --logs 2>/dev/null || rm -rf /var/lib/cloud/* 2>/dev/null || true
fi

#
# 3 - tidy, so the image ships smaller and carries no build history
#
echo "   cleaning package cache and logs"
apt-get clean >/dev/null 2>&1 || true
rm -rf /var/lib/apt/lists/* 2>/dev/null || true
journalctl --rotate >/dev/null 2>&1 || true
journalctl --vacuum-time=1s >/dev/null 2>&1 || true
find /var/log -type f -name '*.gz' -delete 2>/dev/null || true
find /var/log -type f -name '*.[0-9]' -delete 2>/dev/null || true
: >/var/log/wtmp 2>/dev/null || true
: >/var/log/btmp 2>/dev/null || true
: >/var/log/lastlog 2>/dev/null || true

echo "   clearing shell history"
rm -f /root/.bash_history
for home in /home/*; do
    [ -d "$home" ] && rm -f "$home/.bash_history"
done
history -c 2>/dev/null || true

#
# 4 - reclaim free space
#
# The .vmdk is thin-provisioned - it only ever grows, and blocks freed by the
# cleanup above still hold their old contents. There are two ways to deal with
# that, and only one of them is safe on this image.
#
# fstrim is the right one. It tells the hypervisor which blocks are no longer
# in use so it can release them, it finishes in seconds, and it can never make
# the image bigger.
#
# Writing zeros over the free space is the traditional trick and it is actively
# dangerous here. The settler box has a 512GB virtual disk (disk_size = 524288)
# with roughly 10GB used, so `dd if=/dev/zero` would write ~500GB before
# hitting ENOSPC - inflating the sparse .vmdk toward 512GB and quite possibly
# filling the build host's disk on the way. It is kept behind --zerofill for
# the rare small-disk case, and it refuses to run when there is too much free
# space to be plausible.
#
case "$RECLAIM" in
fstrim)
    if command -v fstrim >/dev/null 2>&1; then
        echo "   trimming free space"
        fstrim -av 2>/dev/null || echo "   ⚠️  fstrim reported nothing - the disk may not support discard"
    else
        echo "   ⚠️  fstrim not available, skipping free space reclaim"
        echo "      install util-linux, or re-run with --zerofill on a small disk"
    fi
    ;;
zerofill)
    free_mb="$(df -m --output=avail / | tail -1 | tr -d ' ')"
    if [ "${free_mb:-0}" -gt "${ZEROFILL_MAX_MB}" ]; then
        echo "✋ refusing to zero-fill ${free_mb}MB of free space."
        echo "   That would inflate the thin .vmdk by up to that much and can"
        echo "   fill the build host's disk. Use the default (fstrim) instead,"
        echo "   or raise the cap with ZEROFILL_MAX_MB=<mb> if you are certain."
        exit 1
    fi
    echo "   zeroing ${free_mb}MB of free space (slow)"
    dd if=/dev/zero of=/.zerofill bs=1M status=none 2>/dev/null || true
    sync
    rm -f /.zerofill
    sync
    ;;
none)
    echo "   skipping free space reclaim"
    ;;
esac

# Swap holds recoverable memory pages from the build and never compresses.
# Cycling it discards the contents without touching the swap file's size.
if [ "$RECLAIM" != "none" ]; then
    swapoff -a 2>/dev/null || true
    swapon -a 2>/dev/null || true
    sync
fi

echo
echo "✅ generalized. hostname is now '$(hostname -s)', identity cleared."
echo
echo "   Shut down now and do not boot this VM again before packaging -"
echo "   a single boot re-creates the machine-id and ssh host keys and"
echo "   undoes the work above."
echo
echo "       sudo shutdown -h now"
echo
echo "   Then, on the host:"
echo "       bin/package-vmwarevm.sh <box-or-vmwarevm>"
