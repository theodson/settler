#!/usr/bin/env bash
#
# package-vmwarevm.sh
#
# Turn a built ARM64 VM into a distributable, double-clickable VMware Fusion
# bundle (.vmwarevm) plus an optional .dmg / .zip for handing to the fleet.
#
# Why this exists (and why we no longer produce an OVA)
# -----------------------------------------------------
# Fusion on Apple Silicon cannot import or export OVF/OVA - ovftool has never
# been updated for Arm workflows. The OVA route in docs/build.md is a
# dead end on the new Mac minis: an OVA exported from an Apple Silicon host
# will not import on another Apple Silicon host.
#
# An OVA was never necessary. A Vagrant `*.vmware.box` is just a gzipped tar
# of a complete VMware VM directory:
#
#     ubuntu-24.04-aarch64.vmx      <- the VM definition
#     ubuntu-24.04-aarch64.nvram    <- UEFI variable store
#     ubuntu-24.04-aarch64.vmxf     <- extended config
#     ubuntu-24.04-aarch64.vmsd     <- snapshot metadata
#     disk.vmdk + disk-sNNN.vmdk    <- the split sparse disk
#     Vagrantfile, metadata.json    <- Vagrant-only, dropped here
#
# A `.vmwarevm` is that same directory with a different extension. Fusion
# registers `.vmwarevm` as a package, so Finder shows it as a single file and
# a double-click opens it. No ovftool, no OVA, no conversion, no loss.
#
# What this script does
# ---------------------
#   1. unpacks the box (or copies an existing .vmx dir / .vmwarevm)
#   2. renames the VM files to the product name
#   3. rewrites the .vmx: strips every host-specific and run-specific value,
#      then writes a canonical Apple-Silicon-correct device set
#   4. emits <name>.vmwarevm, optionally wrapped in a .dmg or .zip
#   5. writes SHA-256 checksums and a manifest
#
# The .vmx rewrite is the part that matters. A packer-built box is NOT ready
# to ship as-is:
#
#   * it has no ethernet0 at all - packer strips the NIC, so a plain copy
#     boots with no network. This is why the old OVA notes said "remove all
#     network devices, then add a new one" by hand in the Fusion GUI.
#   * it carries uuid.bios / uuid.location from the build host, so every
#     deployed copy would claim the same identity and the same MAC
#   * it sets ehci.present and usb.present TRUE - EHCI and UHCI are both
#     unsupported for Arm guests on Apple Silicon
#   * it leaves packer's VNC block, the build host's NUMA cookie, VMCI id,
#     NVMe subsystem NQN, scoreboard path and last-power-on timestamp behind
#
# Virtual hardware is set per Broadcom's Arm guest OS compatibility guidance:
# vmxnet3 NIC, NVMe disk, UEFI firmware, XHCI USB, no EHCI/UHCI/floppy/IDE.
# https://knowledge.broadcom.com/external/article/315602
#
# Usage
# -----
#   bin/package-vmwarevm.sh [options] <source>
#
#   <source> is one of
#     ../bento/builds/ubuntu-24.04-aarch64.vmware.box   a packer/vagrant box
#     /path/to/some.vmx                                 a shut-down VM
#     /path/to/some.vmwarevm                            an existing bundle
#
# Options
# -------
#   -n, --name NAME       product name, drives filenames and displayName
#                         (default: settler-homestead)
#   -V, --version VER     version tag appended to the name
#                         (default: $HOMESTEAD_VERSION or 17.0.4)
#   -o, --output DIR      output directory (default: dist/)
#   -m, --memory MB       guest RAM (default: 4096)
#   -c, --cpus N          vCPUs (default: 2)
#       --net MODE        network mode: nat | bridged | hostonly (default: nat)
#   -a, --annotation TXT  free text shown in Fusion's VM notes
#   -f, --format LIST     comma list of: bundle,dmg,zip (default: bundle,dmg)
#       --dmg-format FMT  hdiutil format: UDZO | ULFO | ULMO (default: UDZO)
#   -g, --generalize      boot the VM and run bin/vm-generalize.sh inside it
#                         before sealing, so each deployed copy gets its own
#                         hostname, machine-id and SSH host keys. Adds a few
#                         minutes. This is what bin/package does for you.
#       --guest-user U    guest account for --generalize (default: vagrant)
#       --guest-pass P    its password (default: vagrant)
#       --keep-staging    do not delete the staging directory
#   -h, --help            this text
#
# Examples
# --------
#   # the normal case - box straight to a shippable dmg
#   bin/package-vmwarevm.sh ../bento/builds/ubuntu-24.04-aarch64.vmware.box
#
#   # the same, but generalized first (or just use bin/package)
#   bin/package-vmwarevm.sh --generalize ../bento/builds/ubuntu-24.04-aarch64.vmware.box
#
#   # name it for a release, 8GB of RAM, bridged onto the office LAN
#   bin/package-vmwarevm.sh -n acme-dev -V 2026.1 -m 8192 --net bridged \
#       ../bento/builds/ubuntu-24.04-aarch64.vmware.box
#
#   # repackage a VM you tweaked by hand in Fusion (shut it down first)
#   bin/package-vmwarevm.sh "$HOME/Virtual Machines.localized/golden.vmwarevm"
#
set -euo pipefail

PRODUCT_NAME="${PRODUCT_NAME:-settler-homestead}"
PRODUCT_VERSION="${HOMESTEAD_VERSION:-17.0.4}"
OUTPUT_DIR=""
VM_MEMORY="${VM_MEMORY:-4096}"
VM_CPUS="${VM_CPUS:-2}"
VM_NET="${VM_NET:-nat}"
ANNOTATION=""
FORMATS="bundle,dmg"
DMG_FORMAT="UDZO"
KEEP_STAGING=0
DO_GENERALIZE=0
GUEST_USER="${GUEST_USER:-vagrant}"
GUEST_PASS="${GUEST_PASS:-vagrant}"
FUSION_APP="${FUSION_APP:-/Applications/VMware Fusion.app}"
VMRUN="$FUSION_APP/Contents/Public/vmrun"

settler_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_path=""

usage() { sed -n '3,99p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
    -n | --name)       PRODUCT_NAME="$2"; shift ;;
    -V | --version)    PRODUCT_VERSION="$2"; shift ;;
    -o | --output)     OUTPUT_DIR="$2"; shift ;;
    -m | --memory)     VM_MEMORY="$2"; shift ;;
    -c | --cpus)       VM_CPUS="$2"; shift ;;
    --net)             VM_NET="$2"; shift ;;
    -a | --annotation) ANNOTATION="$2"; shift ;;
    -f | --format)     FORMATS="$2"; shift ;;
    --dmg-format)      DMG_FORMAT="$2"; shift ;;
    --keep-staging)    KEEP_STAGING=1 ;;
    -g | --generalize) DO_GENERALIZE=1 ;;
    --guest-user)      GUEST_USER="$2"; shift ;;
    --guest-pass)      GUEST_PASS="$2"; shift ;;
    -h | --help)       usage; exit 0 ;;
    -*) echo "✋ unknown option: $1" >&2; exit 1 ;;
    *)  source_path="$1" ;;
    esac
    shift
done

[ -n "$source_path" ] || { echo "✋ no source given"; echo; usage; exit 1; }
[ -e "$source_path" ] || { echo "✋ source does not exist: $source_path"; exit 1; }

case "$VM_NET" in
nat | bridged | hostonly) ;;
*) echo "✋ --net must be nat, bridged or hostonly (got '$VM_NET')"; exit 1 ;;
esac

# Read the arch out of the source name rather than assuming aarch64 - this
# script packages whatever box it is given, and bin/build produces x86_64
# boxes on Intel hosts. Folded into vm_name (below) so every artifact this
# script writes - the .vmwarevm, the .dmg, the .sha256, the manifest - carries
# the architecture in its filename. Two Mac minis of different architectures
# building the same product/version would otherwise produce identically named
# files that silently overwrite each other if ever copied to the same place.
case "$source_path" in
*aarch64* | *arm64*) source_arch="aarch64" ;;
*x86_64* | *amd64*)  source_arch="x86_64" ;;
*)                   source_arch="$(uname -m)" ;;
esac

vm_name="$PRODUCT_NAME"
[ -n "$PRODUCT_VERSION" ] && vm_name="$vm_name-$PRODUCT_VERSION"
vm_name="$vm_name-$source_arch"
OUTPUT_DIR="${OUTPUT_DIR:-$settler_root/dist}"

[ -n "$ANNOTATION" ] || ANNOTATION="$vm_name | Ubuntu 24.04 $source_arch | packaged $(date -u '+%Y-%m-%d')"

staging="$OUTPUT_DIR/.staging-$vm_name"
bundle="$OUTPUT_DIR/$vm_name.vmwarevm"

echo "📦 packaging"
echo "   source   : $source_path"
echo "   name     : $vm_name"
echo "   output   : $OUTPUT_DIR"
echo "   hardware : ${VM_CPUS} vCPU / ${VM_MEMORY}MB / vmxnet3 ($VM_NET)"
echo

#
# .vmx helpers
#
# Keys are matched case-insensitively: packer writes them lowercased, Fusion
# writes them camelCased, and both mean the same thing to the hypervisor.
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

# VMware keeps .encoding first and the rest sorted; match that so diffing two
# generated .vmx files is meaningful.
vmx_normalise() {
    local file="$1" tmp
    tmp="$(mktemp)"
    {
        grep -iE '^[[:space:]]*\.encoding[[:space:]]*=' "$file" || echo '.encoding = "UTF-8"'
        grep -viE '^[[:space:]]*\.encoding[[:space:]]*=' "$file" | grep -vE '^[[:space:]]*$' | sort -f
    } >"$tmp"
    mv "$tmp" "$file"
    # mktemp makes 0600 files and mv carries that over; Fusion expects a .vmx
    # the owner can read after the bundle changes hands.
    chmod 644 "$file"
}

#
# 1 - lay the VM files out in staging
#
rm -rf "$staging"
mkdir -p "$staging"

case "$source_path" in
*.box)
    echo "⚡️ unpacking box (this takes a minute - it is a few GB)"
    tar xzf "$source_path" -C "$staging"
    # Vagrant-only metadata, meaningless to Fusion
    rm -f "$staging/Vagrantfile" "$staging/metadata.json" "$staging/box.img"
    ;;
*.vmx)
    echo "⚡️ copying VM directory alongside $(basename "$source_path")"
    cp -R "$(dirname "$source_path")"/. "$staging"/
    ;;
*)
    if [ -d "$source_path" ]; then
        echo "⚡️ copying bundle $(basename "$source_path")"
        cp -R "$source_path"/. "$staging"/
    else
        echo "✋ unrecognised source (want .box, .vmx or a .vmwarevm directory)"
        exit 1
    fi
    ;;
esac

# Runtime debris. A lock directory left behind by an unclean shutdown makes
# Fusion refuse to power the VM on, and it is the single most common reason a
# hand-copied VM "does not work on the other Mac".
find "$staging" -name '*.lck' -prune -exec rm -rf {} + 2>/dev/null || true
rm -f "$staging"/vmware*.log \
      "$staging"/*.scoreboard \
      "$staging"/*.plist \
      "$staging"/*.vmss \
      "$staging"/*.vmem \
      "$staging"/source-vmx \
      "$staging"/source-snapshot \
      "$staging"/vagrant-vmx-warn-* \
      "$staging"/.DS_Store 2>/dev/null || true

src_vmx="$(find "$staging" -maxdepth 1 -name '*.vmx' | head -1)"
[ -n "$src_vmx" ] || { echo "✋ no .vmx found in the source"; exit 1; }

if grep -qiE '^[[:space:]]*(checkpoint\.vmstate[[:space:]]*=[[:space:]]*"[^"]+"|suspend)' "$src_vmx" 2>/dev/null; then
    echo "⚠️  the source VM looks suspended rather than powered off."
    echo "   Shut the guest down cleanly before packaging, or the deployed"
    echo "   copies inherit a saved memory image tied to this host's CPU."
fi

#
# 2 - rename the VM files to the product name
#
# Only the per-VM files are renamed. The disk keeps its `disk.vmdk` +
# `disk-sNNN.vmdk` names on purpose: those extent names are baked into the
# descriptor, and renaming them means rewriting it for no benefit.
#
old_base="$(basename "$src_vmx" .vmx)"
if [ "$old_base" != "$vm_name" ]; then
    echo "⚡️ renaming $old_base.* -> $vm_name.*"
    for ext in vmx vmxf vmsd nvram; do
        [ -e "$staging/$old_base.$ext" ] && mv "$staging/$old_base.$ext" "$staging/$vm_name.$ext"
    done
fi
vmx="$staging/$vm_name.vmx"
[ -e "$vmx" ] || { echo "✋ expected $vmx after rename"; exit 1; }

# The .vmxf carries the old display name inside XML; harmless but untidy.
if [ -e "$staging/$vm_name.vmxf" ]; then
    sed -i '' "s/${old_base}/${vm_name}/g" "$staging/$vm_name.vmxf" 2>/dev/null || true
fi

#
# Everything a power-on leaves behind: the identity Fusion mints, the files it
# writes alongside the .vmx. Needed twice - once now, and again after the
# optional generalize boot below, which necessarily creates a fresh set.
#
strip_runtime_identity() {
    local vmxfile="$1" dir
    dir="$(dirname "$vmxfile")"
    vmx_del "$vmxfile" \
        'uuid\.bios' \
        'uuid\.location' \
        'vc\.uuid' \
        'ethernet[0-9]+\.generatedAddress.*' \
        'ethernet[0-9]+\.address' \
        'ethernet[0-9]+\.pciSlotNumber' \
        'vmci0\.id' \
        'nvme0\.subnqnuuid' \
        'guestinfo\..*' \
        'vm\.lastpowerrequesttimestamp' \
        'vmxstats\..*' \
        'checkpoint\..*' \
        'cleanshutdown' \
        'softpoweroff' \
        'gui\.lastpoweredviewmode'
    find "$dir" -name '*.lck' -prune -exec rm -rf {} + 2>/dev/null || true
    rm -f "$dir"/vmware*.log "$dir"/*.scoreboard "$dir"/*.plist \
          "$dir"/*.vmss "$dir"/*.vmem "$dir"/.DS_Store 2>/dev/null || true
}

#
# 3 - rewrite the .vmx
#
echo "⚡️ rewriting $(basename "$vmx")"

# 3a - strip everything tied to the build host, this run, or this identity.
vmx_del "$vmx" \
    'uuid\.bios' \
    'uuid\.location' \
    'vc\.uuid' \
    'vm\.genid.*' \
    'ethernet[0-9]+\..*' \
    'sharedfolder.*' \
    'guestinfo\..*' \
    'remotedisplay\..*' \
    'vmotion\..*' \
    'replay\..*' \
    'migrate\..*' \
    'checkpoint\..*' \
    'suspend\..*' \
    'serial[0-9]+\..*' \
    'parallel[0-9]+\..*' \
    'floppy[0-9]+\..*' \
    'sata0:[0-9]+\..*' \
    'vmci0\.id' \
    'nvme0\.subnqnuuid' \
    'numa\.autosize\..*' \
    'vm\.lastpowerrequesttimestamp' \
    'vmxstats\..*' \
    'gui\.lastpoweredviewmode' \
    'toolsinstallmanager\..*' \
    'tools\.remindinstall' \
    'softpoweroff' \
    'cleanshutdown' \
    'monitor\.phys_bits_used' \
    'hpet0\..*' \
    'unity\..*' \
    'annotation' \
    'displayname' \
    'nvram' \
    'extendedconfigfile'

# 3b - identity: regenerate on first power-on rather than shipping ours.
#
# uuid.action = create is what makes this fleet-safe. Without it Fusion shows
# the "I moved it / I copied it" dialog on first boot and, if someone clicks
# "moved", the VM keeps the build host's UUID and MAC - so two VMs on the same
# subnet collide. With it, Fusion silently mints a new UUID and a new MAC.
vmx_set "$vmx" "uuid.action"   "create"
vmx_set "$vmx" "msg.autoAnswer" "TRUE"

# 3c - naming
vmx_set "$vmx" "displayName"        "$vm_name"
vmx_set "$vmx" "annotation"         "$ANNOTATION"
vmx_set "$vmx" "nvram"              "$vm_name.nvram"
vmx_set "$vmx" "extendedConfigFile" "$vm_name.vmxf"

# 3d - sizing
vmx_set "$vmx" "memsize"              "$VM_MEMORY"
vmx_set "$vmx" "numvcpus"             "$VM_CPUS"
vmx_set "$vmx" "cpuid.coresPerSocket" "$VM_CPUS"

# 3e - firmware. Arm guests are UEFI only; there is no BIOS path.
vmx_set "$vmx" "firmware" "efi"

# 3f - network. Packer leaves no NIC behind, so this is an add, not an edit.
# vmxnet3 is the adapter Broadcom endorses for Arm guests; e1000e is an x86
# emulated device and can fail with "No PCIe slot available for Ethernet0".
# Note what is deliberately absent: ethernet0.pciSlotNumber (let Fusion place
# it) and ethernet0.generatedAddress (let Fusion mint a MAC per install).
vmx_set "$vmx" "ethernet0.present"                     "TRUE"
vmx_set "$vmx" "ethernet0.virtualDev"                  "vmxnet3"
vmx_set "$vmx" "ethernet0.connectionType"              "$VM_NET"
vmx_set "$vmx" "ethernet0.addressType"                 "generated"
vmx_set "$vmx" "ethernet0.startConnected"              "TRUE"
vmx_set "$vmx" "ethernet0.allowGuestConnectionControl" "false"

# 3g - USB. XHCI is fully supported on Arm; EHCI and UHCI are not.
# Drop the slot reservations along with the controllers, so nothing holds a
# PCI slot for a device that is never going to appear.
vmx_del "$vmx" 'ehci\.pcislotnumber' 'usb\.pcislotnumber'
vmx_set "$vmx" "usb_xhci.present" "TRUE"
vmx_set "$vmx" "ehci.present"     "FALSE"
vmx_set "$vmx" "usb.present"      "FALSE"

# 3h - a disconnected optical drive, so an ISO can be attached later without
# the VM failing to power on when the host has no drive to autodetect.
vmx_set "$vmx" "sata0.present"          "TRUE"
vmx_set "$vmx" "sata0:0.present"        "TRUE"
vmx_set "$vmx" "sata0:0.deviceType"     "atapi-cdrom"
vmx_set "$vmx" "sata0:0.autodetect"     "TRUE"
vmx_set "$vmx" "sata0:0.startConnected" "FALSE"

# 3i - devices with no place on Apple Silicon
vmx_set "$vmx" "floppy0.present"  "FALSE"
vmx_set "$vmx" "serial0.present"  "FALSE"
vmx_set "$vmx" "parallel0.present" "FALSE"
vmx_set "$vmx" "sound.present"    "FALSE"

# 3j - keep the guest clock honest and let tools update themselves
vmx_set "$vmx" "tools.syncTime"        "TRUE"
vmx_set "$vmx" "tools.upgrade.policy"  "upgradeAtPowerCycle"

vmx_normalise "$vmx"

# Sanity: the disk the descriptor points at must actually be here.
disk_ref="$(grep -iE '^[[:space:]]*nvme0:0\.fileName' "$vmx" | sed 's/.*"\(.*\)"/\1/' || true)"
if [ -n "$disk_ref" ] && [ ! -e "$staging/$disk_ref" ]; then
    echo "✋ .vmx points at $disk_ref but it is not in the staging directory"
    exit 1
fi

#
# 3k - generalize the guest
#
# This is how bin/vm-generalize.sh gets into the VM: it is pushed over the
# VMware Tools channel and run there, with no ssh, no shared folder and no
# manual copy. The Tools channel is used rather than ssh on purpose - it needs
# no network, no credentials on the wire and no host key handling, and it keeps
# working right through the point where the script deletes the guest's SSH host
# keys and sshd stops accepting connections.
#
# The order matters. The .vmx has just been rewritten, so the VM boots with a
# working NIC; generalizing before that would leave it waiting on a network
# that does not exist. Booting also mints a fresh uuid.bios and MAC and drops a
# lock directory and a log, so the identity strip is repeated afterwards.
#
if [ "$DO_GENERALIZE" = 1 ]; then
    generalize_script="$settler_root/bin/vm-generalize.sh"
    [ -e "$generalize_script" ] || { echo "✋ cannot find $generalize_script"; exit 1; }
    [ -x "$VMRUN" ] || { echo "✋ vmrun not found at $VMRUN"; exit 1; }

    echo
    echo "⚡️ generalizing the guest (boots the VM, this takes a few minutes)"

    "$VMRUN" start "$vmx" nogui >/dev/null 2>&1 ||
        { echo "✋ could not power on the staged VM"; exit 1; }

    # Wait for Tools rather than for an IP: generalizing needs the Tools
    # channel, not networking, and this still works on a VM with no DHCP.
    echo "   waiting for VMware Tools"
    tools_up=0
    for _ in $(seq 1 60); do
        if "$VMRUN" -gu "$GUEST_USER" -gp "$GUEST_PASS" \
            runProgramInGuest "$vmx" /bin/true >/dev/null 2>&1; then
            tools_up=1
            break
        fi
        sleep 5
    done

    if [ "$tools_up" = 0 ]; then
        echo "✋ VMware Tools never came up, or the guest credentials are wrong."
        echo "   Tried user '$GUEST_USER'. Override with --guest-user/--guest-pass."
        "$VMRUN" stop "$vmx" hard >/dev/null 2>&1 || true
        exit 1
    fi

    echo "   pushing $(basename "$generalize_script") to the guest"
    "$VMRUN" -gu "$GUEST_USER" -gp "$GUEST_PASS" \
        copyFileFromHostToGuest "$vmx" "$generalize_script" /tmp/vm-generalize.sh ||
        { echo "✋ could not copy the generalize script into the guest"; exit 1; }

    echo "   running it"
    "$VMRUN" -gu "$GUEST_USER" -gp "$GUEST_PASS" \
        runScriptInGuest "$vmx" /bin/bash \
        'sudo bash /tmp/vm-generalize.sh > /tmp/vm-generalize.log 2>&1; rm -f /tmp/vm-generalize.sh' ||
        { echo "✋ the generalize script failed inside the guest"; exit 1; }

    # Keep the guest's own log next to the artifacts - it is the only record of
    # what was stripped, and the guest is about to be sealed.
    "$VMRUN" -gu "$GUEST_USER" -gp "$GUEST_PASS" \
        copyFileFromGuestToHost "$vmx" /tmp/vm-generalize.log \
        "$OUTPUT_DIR/$vm_name.generalize.log" >/dev/null 2>&1 || true

    echo "   shutting the guest down"
    "$VMRUN" stop "$vmx" soft >/dev/null 2>&1 || true

    powered_off=0
    for _ in $(seq 1 60); do
        if ! "$VMRUN" list 2>/dev/null | grep -qxF "$vmx"; then
            powered_off=1
            break
        fi
        sleep 5
    done
    if [ "$powered_off" = 0 ]; then
        echo "⚠️  guest did not shut down cleanly, forcing power off"
        "$VMRUN" stop "$vmx" hard >/dev/null 2>&1 || true
        sleep 5
    fi

    # That boot gave the VM a fresh identity and left runtime files behind.
    echo "   re-stripping the identity created by that boot"
    strip_runtime_identity "$vmx"
    vmx_set "$vmx" "uuid.action"    "create"
    vmx_set "$vmx" "msg.autoAnswer" "TRUE"
    vmx_set "$vmx" "ethernet0.addressType" "generated"
    vmx_normalise "$vmx"

    if [ -s "$OUTPUT_DIR/$vm_name.generalize.log" ]; then
        echo "   guest log: $OUTPUT_DIR/$vm_name.generalize.log"
    fi
    echo "✅ guest generalized"
fi

#
# 4 - assemble the bundle
#
mkdir -p "$OUTPUT_DIR"
rm -rf "$bundle"
mv "$staging" "$bundle"
staging=""
echo "📦 $bundle"

echo "   $(du -sh "$bundle" | awk '{print $1}') on disk"

#
# 5 - wrap for distribution
#
want() { case ",$FORMATS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

artifacts=("$bundle")

if want dmg; then
    dmg="$OUTPUT_DIR/$vm_name.dmg"
    dmg_stage="$OUTPUT_DIR/.dmg-$vm_name"
    echo
    echo "⚡️ building $(basename "$dmg") - compressing a few GB, expect several minutes"

    rm -rf "$dmg_stage" "$dmg"
    mkdir -p "$dmg_stage"
    # A bundle cannot be hard-linked into place, and copying it twice would
    # double the peak disk usage, so clone it (instant + no extra space on
    # APFS) and fall back to a plain copy on other filesystems.
    cp -Rc "$bundle" "$dmg_stage/" 2>/dev/null || cp -R "$bundle" "$dmg_stage/"

    if [ -x "$settler_root/bin/install-vm.sh" ]; then
        cp "$settler_root/bin/install-vm.sh" "$dmg_stage/Install.command"
        chmod +x "$dmg_stage/Install.command"
    fi

    cat >"$dmg_stage/README.txt" <<README
$vm_name
$(printf '%*s' "${#vm_name}" '' | tr ' ' '=')

Two ways to install. Both need VMware Fusion already installed.

  EASIEST - one VM on this Mac
    1. Drag $vm_name.vmwarevm to your "Virtual Machines" folder
       (or anywhere on the internal disk - do not run it from this disk image).
    2. Double-click it. Fusion opens it and powers it on.

  RECOMMENDED - several VMs on one Mac, one per customer
    1. Double-click Install.command.
    2. Type a name for this instance when asked, e.g. the customer name.
    It copies the VM, names it, and opens it in Fusion.

Each install gets a fresh UUID and a fresh MAC address automatically, so
running five copies of this VM on one Mac - or across the fleet - is safe.

If macOS says Install.command "cannot be opened because it is from an
unidentified developer", right-click it and choose Open, then Open again.
README

    hdiutil create \
        -volname "$vm_name" \
        -srcfolder "$dmg_stage" \
        -ov -format "$DMG_FORMAT" \
        "$dmg" >/dev/null
    rm -rf "$dmg_stage"
    echo "📦 $dmg"
    artifacts+=("$dmg")
fi

if want zip; then
    zip_out="$OUTPUT_DIR/$vm_name.zip"
    echo
    echo "⚡️ building $(basename "$zip_out")"
    rm -f "$zip_out"
    # ditto writes a PKZIP archive Finder can expand with a double-click and
    # keeps the bundle's package flag, which `zip -r` does not.
    ditto -c -k --sequesterRsrc --keepParent "$bundle" "$zip_out"
    echo "📦 $zip_out"
    artifacts+=("$zip_out")
fi

if ! want bundle; then
    rm -rf "$bundle"
    artifacts=("${artifacts[@]:1}")
fi

#
# 6 - checksums and manifest
#
echo
echo "⚡️ checksums"
sums="$OUTPUT_DIR/$vm_name.sha256"
: >"$sums"
for a in "${artifacts[@]}"; do
    case "$a" in
    *.vmwarevm) continue ;;  # a directory - the files inside are what matter
    esac
    (cd "$(dirname "$a")" && shasum -a 256 "$(basename "$a")") >>"$sums"
done
[ -s "$sums" ] && cat "$sums" || rm -f "$sums"

manifest="$OUTPUT_DIR/$vm_name.manifest.txt"
cat >"$manifest" <<MANIFEST
name            $vm_name
packaged        $(date -u '+%Y-%m-%dT%H:%M:%SZ')
packaged by     $(whoami)@$(hostname -s)
source          $source_path
guest           $(grep -iE '^guestOS' "$OUTPUT_DIR/$vm_name.vmwarevm/$vm_name.vmx" 2>/dev/null | sed 's/.*"\(.*\)"/\1/' || echo 'arm-ubuntu-64')
virtual hw      $(grep -iE '^virtualHW.version' "$OUTPUT_DIR/$vm_name.vmwarevm/$vm_name.vmx" 2>/dev/null | sed 's/.*"\(.*\)"/\1/' || echo '?')
cpus            $VM_CPUS
memory          ${VM_MEMORY} MB
nic             vmxnet3 ($VM_NET)
settler commit  $(git -C "$settler_root" rev-parse --short HEAD 2>/dev/null || echo 'n/a')
MANIFEST
echo
cat "$manifest"

if [ "$KEEP_STAGING" = 0 ] && [ -n "$staging" ] && [ -d "$staging" ]; then
    rm -rf "$staging"
fi

echo
echo "✅ done. Artifacts in $OUTPUT_DIR"
echo
echo "   Next: copy the .dmg to the target Mac, open it, and either drag the"
echo "   .vmwarevm out and double-click it, or run Install.command to name"
echo "   and register this instance."
