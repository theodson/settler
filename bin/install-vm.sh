#!/usr/bin/env bash
#
# install-vm.sh
#
# Install one instance of a packaged .vmwarevm onto this Mac and open it in
# VMware Fusion. This is the script that ships inside the .dmg produced by
# bin/package-vmwarevm.sh, where it is named Install.command so that a
# double-click in Finder runs it.
#
# The fleet case it is built for
# ------------------------------
# One Mac mini hosts several VMs, added one at a time as customers come on.
# Copying the same bundle five times by hand goes wrong in three ways:
#
#   * all five keep the same displayName, so Fusion's library lists five
#     identically-named machines and nobody can tell them apart
#   * all five share a UUID and a MAC unless Fusion is answered correctly at
#     first boot, which collides on the LAN and confuses DHCP
#   * all five have the same hostname, machine-id and SSH host keys inside the
#     guest, so ssh warns about changed host keys and logs are unattributable
#
# This script handles the first two directly, and hands the third to the guest
# via a guestinfo key (see bin/vm-generalize.sh for the in-guest side).
#
# Usage
# -----
#   ./install-vm.sh                     # ask for an instance name
#   ./install-vm.sh acme-corp           # name it directly
#   ./install-vm.sh --source X.vmwarevm --name acme --yes
#
# Options
# -------
#   -s, --source PATH   the .vmwarevm to install
#                       (default: the one sitting next to this script)
#   -n, --name NAME     instance name - becomes the folder name, the name in
#                       Fusion's library, and the guest hostname
#   -t, --target DIR    where to install (default: ~/Virtual Machines.localized)
#   -m, --memory MB     override guest RAM for this instance
#   -c, --cpus N        override vCPUs for this instance
#       --net MODE      nat | bridged | hostonly
#   -y, --yes           do not prompt, do not open Fusion afterwards
#       --no-open       install but do not launch Fusion
#   -h, --help          this text
#
set -euo pipefail

FUSION_APP="${FUSION_APP:-/Applications/VMware Fusion.app}"
TARGET_DIR="${TARGET_DIR:-$HOME/Virtual Machines.localized}"
SOURCE_BUNDLE=""
INSTANCE_NAME=""
VM_MEMORY=""
VM_CPUS=""
VM_NET=""
ASSUME_YES=0
DO_OPEN=1

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '3,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
    -s | --source) SOURCE_BUNDLE="$2"; shift ;;
    -n | --name)   INSTANCE_NAME="$2"; shift ;;
    -t | --target) TARGET_DIR="$2"; shift ;;
    -m | --memory) VM_MEMORY="$2"; shift ;;
    -c | --cpus)   VM_CPUS="$2"; shift ;;
    --net)         VM_NET="$2"; shift ;;
    -y | --yes)    ASSUME_YES=1; DO_OPEN=0 ;;
    --no-open)     DO_OPEN=0 ;;
    -h | --help)   usage; exit 0 ;;
    -*) echo "✋ unknown option: $1" >&2; exit 1 ;;
    *)  INSTANCE_NAME="$1" ;;
    esac
    shift
done

#
# preflight
#
if [ ! -d "$FUSION_APP" ]; then
    echo "✋ VMware Fusion is not installed at $FUSION_APP"
    echo "   Install Fusion first, then run this again."
    exit 1
fi

if [ -z "$SOURCE_BUNDLE" ]; then
    SOURCE_BUNDLE="$(find "$script_dir" -maxdepth 1 -name '*.vmwarevm' | head -1)"
fi

if [ -z "$SOURCE_BUNDLE" ] || [ ! -d "$SOURCE_BUNDLE" ]; then
    echo "✋ no .vmwarevm found next to this script."
    echo "   Pass one explicitly:  $(basename "$0") --source /path/to/vm.vmwarevm"
    exit 1
fi

src_vmx="$(find "$SOURCE_BUNDLE" -maxdepth 1 -name '*.vmx' | head -1)"
[ -n "$src_vmx" ] || { echo "✋ $SOURCE_BUNDLE has no .vmx inside it"; exit 1; }
src_base="$(basename "$src_vmx" .vmx)"

echo "📦 $(basename "$SOURCE_BUNDLE")"
echo "   $(du -sh "$SOURCE_BUNDLE" | awk '{print $1}') to copy"
echo

#
# name this instance
#
if [ -z "$INSTANCE_NAME" ]; then
    if [ "$ASSUME_YES" = 1 ]; then
        echo "✋ --yes needs --name"
        exit 1
    fi
    echo "Name this VM. Use the customer or project it belongs to, so it is"
    echo "identifiable in Fusion's library alongside the others on this Mac."
    echo
    read -r -p "  instance name [$src_base] : " INSTANCE_NAME
    INSTANCE_NAME="${INSTANCE_NAME:-$src_base}"
fi

# Keep it filesystem- and hostname-safe: a Linux hostname may not contain
# spaces or underscores, and we reuse this name as the guest hostname.
INSTANCE_NAME="$(printf '%s' "$INSTANCE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9.-')"
INSTANCE_NAME="$(printf '%s' "$INSTANCE_NAME" | sed 's/^-*//; s/-*$//')"
[ -n "$INSTANCE_NAME" ] || { echo "✋ that name has no usable characters in it"; exit 1; }

dest="$TARGET_DIR/$INSTANCE_NAME.vmwarevm"

if [ -e "$dest" ]; then
    echo
    echo "✋ $dest already exists."
    echo "   Pick a different name, or remove the existing VM from Fusion first."
    exit 1
fi

#
# check there is room - a half-copied multi-GB VM is a miserable failure mode
#
need_kb="$(du -sk "$SOURCE_BUNDLE" | awk '{print $1}')"
mkdir -p "$TARGET_DIR"
free_kb="$(df -k "$TARGET_DIR" | awk 'NR==2 {print $4}')"
if [ "$free_kb" -lt "$need_kb" ]; then
    echo "✋ not enough free space on the target volume."
    echo "   need $((need_kb / 1048576)) GiB, have $((free_kb / 1048576)) GiB"
    exit 1
fi

echo
echo "⚡️ installing as '$INSTANCE_NAME'"
echo "   -> $dest"
echo

#
# copy
#
# cp -c asks APFS to clone: instant and free when source and destination are
# on the same volume, which is the case when re-installing from a local copy.
# From a mounted .dmg it is a different volume, so this falls back to a real
# copy and takes as long as the disk allows.
#
cleanup_failed() { [ -d "$dest" ] && rm -rf "$dest"; }
trap cleanup_failed ERR INT TERM

cp -Rc "$SOURCE_BUNDLE" "$dest" 2>/dev/null || cp -R "$SOURCE_BUNDLE" "$dest"

# Anything that arrived via a download or a disk image carries a quarantine
# xattr. Fusion refuses to power on a quarantined VM without a prompt per file.
xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true

# Never inherit a stale lock from however the source was made.
find "$dest" -name '*.lck' -prune -exec rm -rf {} + 2>/dev/null || true
rm -f "$dest"/vmware*.log "$dest"/*.scoreboard "$dest"/.DS_Store 2>/dev/null || true

#
# rename the inner files to match the instance
#
if [ "$src_base" != "$INSTANCE_NAME" ]; then
    for ext in vmx vmxf vmsd nvram; do
        [ -e "$dest/$src_base.$ext" ] && mv "$dest/$src_base.$ext" "$dest/$INSTANCE_NAME.$ext"
    done
    [ -e "$dest/$INSTANCE_NAME.vmxf" ] &&
        sed -i '' "s/${src_base}/${INSTANCE_NAME}/g" "$dest/$INSTANCE_NAME.vmxf" 2>/dev/null || true
fi

vmx="$dest/$INSTANCE_NAME.vmx"
[ -e "$vmx" ] || { echo "✋ expected $vmx after rename"; exit 1; }

#
# per-instance .vmx settings
#
vmx_del() {
    local file="$1"; shift
    local pattern tmp
    tmp="$(mktemp)"
    for pattern in "$@"; do
        grep -viE "^[[:space:]]*${pattern}[[:space:]]*=" "$file" >"$tmp" || true
        cat "$tmp" >"$file"
    done
    rm -f "$tmp"
}

vmx_set() {
    local file="$1" key="$2" value="$3" escaped
    escaped="$(printf '%s' "$key" | sed 's/[][^$.*\\\/]/\\&/g')"
    vmx_del "$file" "$escaped"
    printf '%s = "%s"\n' "$key" "$value" >>"$file"
}

vmx_set "$vmx" "displayName"        "$INSTANCE_NAME"
vmx_set "$vmx" "nvram"              "$INSTANCE_NAME.nvram"
vmx_set "$vmx" "extendedConfigFile" "$INSTANCE_NAME.vmxf"

# Belt and braces. package-vmwarevm.sh already sets these, but this script also
# has to cope with bundles copied by hand or produced before it existed.
vmx_set "$vmx" "uuid.action"    "create"
vmx_set "$vmx" "msg.autoAnswer" "TRUE"
vmx_del "$vmx" 'uuid\.bios' 'uuid\.location' 'vc\.uuid' \
    'ethernet[0-9]+\.generatedAddress.*' 'ethernet[0-9]+\.address' \
    'ethernet[0-9]+\.pciSlotNumber' 'vmci0\.id' 'nvme0\.subnqnuuid'
vmx_set "$vmx" "ethernet0.addressType" "generated"

[ -n "$VM_MEMORY" ] && vmx_set "$vmx" "memsize" "$VM_MEMORY"
[ -n "$VM_CPUS" ] && {
    vmx_set "$vmx" "numvcpus" "$VM_CPUS"
    vmx_set "$vmx" "cpuid.coresPerSocket" "$VM_CPUS"
}
[ -n "$VM_NET" ] && vmx_set "$vmx" "ethernet0.connectionType" "$VM_NET"

# Handed to the guest so it can name itself on first boot. Read it inside the
# VM with:  vmware-rpctool "info-get guestinfo.settler.instance"
vmx_set "$vmx" "guestinfo.settler.instance"  "$INSTANCE_NAME"
vmx_set "$vmx" "guestinfo.settler.installed" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

trap - ERR INT TERM

echo "✅ installed"
echo "   $dest"
echo "   $(grep -icE '^' "$vmx") settings, displayName '$INSTANCE_NAME'"
echo
echo "   Fusion will mint a fresh UUID and MAC when it first powers on,"
echo "   so this copy will not clash with the others on this Mac."

#
# hand it to Fusion
#
if [ "$DO_OPEN" = 1 ]; then
    echo
    echo "⚡️ opening in Fusion"
    open -a "$FUSION_APP" "$vmx"
    echo
    echo "   The VM is now in Window > Virtual Machine Library (⇧⌘L)."
else
    echo
    echo "   To start it:  open -a \"$FUSION_APP\" \"$vmx\""
fi

# When run by double-clicking Install.command, Terminal closes on exit and the
# output vanishes. Hold the window open so whoever ran it can read the result.
case "$0" in
*Install.command)
    echo
    read -r -n1 -p "Press any key to close this window. " _ || true
    echo
    ;;
esac
