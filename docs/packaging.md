# Packaging and distributing ARM64 VMs for the Apple Silicon fleet

How we get a built Ubuntu 24.04 aarch64 VM from the build Mac onto twenty
Apple Silicon Mac minis, five VMs per mini, one at a time as customers engage.

- **Target**: VMware Fusion on Apple Silicon.
- **Requirement**: installing a VM must be about as hard as double-clicking it.
- **Constraint**: OVA, the format the old Intel fleet used, does not work here.

## TLDR

Two commands on the build Mac:

```bash
SETTLER_VERSION=16.0.0 HOMESTEAD_VERSION=17.0.4 bash bin/build   # build the VM
bash bin/package                                                 # ship it
```

`bin/package` finds the box `bin/build` just wrote, generalizes the guest,
seals the image and writes to `dist/`:

```
settler-homestead-17.0.4.vmwarevm      double-click to run in Fusion
settler-homestead-17.0.4.dmg           what you hand to the fleet
settler-homestead-17.0.4.sha256        integrity check
settler-homestead-17.0.4.manifest.txt  what is in it and where it came from
```

On each Mac mini, per customer:

```
open the .dmg  ->  double-click Install.command  ->  type the customer name
```

The VM is copied, named, given a fresh UUID and MAC, registered in Fusion's
library, and powered on.

---

## Why the OVA route is a dead end here

The [Unofficial Fusion for Apple Silicon Companion Guide][guide] puts it
plainly:

> Virtual appliances packaged as Open Virtualization Format (.ova or .ovf)
> files won't work on Apple Silicon Macs either. Fusion on Apple Silicon
> doesn't support the import Open Virtualization Format virtual machines.

The underlying reason is that `ovftool` was never updated for Arm workflows.
Both directions are affected, so this is not a matter of exporting on Intel and
importing on Apple Silicon:

- exporting an Arm VM to OVA produces a descriptor with
  `vmw:osType="otherGuest"` and a hardware layout the Arm importer rejects
- importing any OVA on an Apple Silicon Fusion host is simply not implemented

The old `docs/build.md` OVA recipe - export with `ovftool`, hand-edit
the `.ovf`, recompute the `.mf` checksum, repack the tar in descriptor-first
order - was a lot of careful work to produce a file the target Macs cannot
open. It is kept there for the historical Intel fleet only.

[guide]: https://community.broadcom.com/vmware-cloud-foundation/viewdocument/the-unofficial-fusion-for-apple-sil?CommunityKey=0c3a2021-5113-4ad1-af9e-018f5da40bc0&tab=librarydocuments

## The thing that makes this easy

An OVA was never needed. Look at what a Vagrant `*.vmware.box` actually is:

```console
$ tar tzvf ubuntu-24.04-aarch64.vmware.box
ubuntu-24.04-aarch64.vmx        <- the VM definition
ubuntu-24.04-aarch64.nvram      <- UEFI variable store
ubuntu-24.04-aarch64.vmxf       <- extended config
ubuntu-24.04-aarch64.vmsd       <- snapshot metadata
disk.vmdk                       <- descriptor
disk-s001.vmdk ... disk-s032.vmdk   <- 2GB split sparse extents
Vagrantfile, metadata.json      <- Vagrant's, not VMware's
```

That is a complete, ready-to-run VMware virtual machine directory. It is a
gzipped tar of one, nothing more.

A `.vmwarevm` is *the same directory with a different extension*. Fusion
registers `.vmwarevm` as a macOS package type, so Finder shows the directory as
a single file with a VM icon, and double-clicking it opens it in Fusion.

So the conversion is: untar, drop Vagrant's two files, fix up the `.vmx`,
rename. No `ovftool`, no OVF descriptor, no manifest checksums, no
stream-optimised disk conversion, no lossy round-trip. It is also much faster
than an OVA export, because nothing is recompressed.

## What the `.vmx` rewrite fixes

A packer-built box is **not** shippable as-is. `bin/package-vmwarevm.sh`
rewrites the `.vmx` to deal with the following, all of which we hit:

| Problem in the raw box                                                                                      | Why it matters                                                                                                                                         | Fix applied                                             |
|-------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| No `ethernet0` at all                                                                                       | packer strips the NIC; a plain copy boots with no network. This is why the old OVA notes said to remove and re-add network devices by hand in the GUI. | adds a full `ethernet0` block                           |
| `ethernet0.virtualDev = e1000e` (when Vagrant adds one)                                                     | e1000e is an x86 emulated device. On Arm it can fail with *No PCIe slot available for Ethernet0*.                                                      | `vmxnet3`, the adapter Broadcom endorses for Arm guests |
| `uuid.bios` / `uuid.location` from the build host                                                           | every deployed copy claims the same identity and the same MAC                                                                                          | removed, and `uuid.action = "create"` set               |
| `ehci.present = TRUE`, `usb.present = TRUE`                                                                 | EHCI and UHCI are both unsupported for Arm guests                                                                                                      | set `FALSE`; XHCI kept                                  |
| packer's `remotedisplay.vnc.*` block                                                                        | leaves a VNC listener configured in a shipped image                                                                                                    | removed                                                 |
| `numa.autosize.cookie`, `vmci0.id`, `nvme0.subnqnuuid`, `vmxstats.filename`, `vm.lastpowerrequesttimestamp` | build-host and build-run state                                                                                                                         | removed                                                 |
| `sharedFolder*`                                                                                             | absolute paths into the build machine's home directory                                                                                                 | removed                                                 |
| `.vmx.lck` directories, `vmware.log`, `*.scoreboard`                                                        | a stale lock makes Fusion refuse to power the VM on. This is the single most common reason a hand-copied VM "doesn't work on the other Mac".           | deleted                                                 |
| `sata0:0` as `cdrom-raw` + `clientDevice`                                                                   | points at a physical drive the Mac minis do not have                                                                                                   | replaced with a disconnected `atapi-cdrom`              |

Virtual hardware follows Broadcom's [Arm guest OS compatibility guidance][kb]:
vmxnet3 NIC, NVMe disk, UEFI firmware, XHCI USB, and no EHCI, UHCI, floppy or
IDE.

[kb]: https://knowledge.broadcom.com/external/article/315602

### `uuid.action = "create"` is the load-bearing setting

Without it, the first power-on of every copied VM shows Fusion's *"This virtual
machine might have been moved or copied"* dialog. If whoever is installing
clicks **I moved it**, the VM keeps the build host's UUID and MAC — and the
moment a second VM on the same mini does the same, you have two machines
fighting over one MAC address on the LAN.

With `uuid.action = "create"` plus `msg.autoAnswer = "TRUE"`, Fusion silently
mints a new UUID and a new MAC on first boot, every time, with nothing to click.
That is what makes five copies on one Mac mini safe.

## Guest-side identity

The host-side scripts give each copy unique *virtual hardware*. They cannot
reach inside the guest, where five clones would still share:

- `/etc/machine-id` — systemd's identity. Ubuntu derives the DHCP DUID from it,
  so all five VMs request the same lease and take turns losing it.
- `/etc/ssh/ssh_host_*_key` — every VM presents the same host key fingerprint,
  which defeats the point of host keys and triggers
  `REMOTE HOST IDENTIFICATION HAS CHANGED` as admins move between them.
- `/etc/hostname` — no log line or shell prompt tells you which VM you are on.

This is handled in two places, and you never copy a script into a VM by hand.

### At build time — the service is baked into the image

`bin/build` runs `bin/inject-firstboot.sh`, which lifts the first-boot service
out of `bin/vm-generalize.sh` — the block between its
`SETTLER_FIRSTBOOT_BEGIN` / `END` markers — and splices it verbatim into
`scripts/arm.sh` and `scripts/amd64.sh`, the final packer provisioner. So a box
comes off the build line with `/usr/local/sbin/settler-firstboot` and its
systemd unit already installed and enabled.

The definition lives in exactly one file. `bin/inject-firstboot.sh --check`
fails if the two have drifted, and `--remove` strips the injected block back
out. Injection is idempotent — re-running replaces rather than stacks.

This follows the existing settler convention: `bin/use-homestead-features.sh`
already splices feature scripts into `scripts/*.sh`, and `bin/build` resets
those files with `git checkout` before each run. **`scripts/*.sh` are pristine
in git** — the injected block only exists during a build.

One thing is deliberately *not* baked in: removing the guest's SSH host keys.
That happens in packer's final provisioner, and packer still has to run its
`shutdown_command` over ssh afterwards. An established session survives the key
files being deleted, but a reconnect would not — a 40-minute build failing at
the last step. `SETTLER_STRIP_SSH_KEYS=1` injects it too, once you have a
successful build to confirm it is safe on your packer version.

### At package time — the identity is stripped

`bin/package` (via `package-vmwarevm.sh --generalize`) boots the staged VM,
pushes `bin/vm-generalize.sh` over the VMware Tools channel, runs it, and shuts
the guest back down:

```
vmrun copyFileFromHostToGuest  <vmx> bin/vm-generalize.sh /tmp/vm-generalize.sh
vmrun runScriptInGuest         <vmx> /bin/bash 'sudo bash /tmp/vm-generalize.sh'
```

The Tools channel is used rather than ssh deliberately. It needs no network, no
credentials on the wire and no host-key handling — and it keeps working right
through the point where the script deletes the guest's SSH host keys and sshd
stops accepting connections, which is exactly when an ssh-based approach would
lose its own connection.

Ordering matters, and the script gets it right: the `.vmx` is rewritten *first*
so the VM boots with a working NIC, and the identity strip is repeated
*afterwards*, because that boot necessarily mints a fresh `uuid.bios` and MAC
and leaves a lock directory and a log behind.

The guest's own output is saved next to the artifacts as
`dist/<name>.generalize.log`.

To run it by hand instead — on a VM you have customised interactively — shut
the guest down straight afterwards and repackage without `--generalize`:

```bash
sudo bash vm-generalize.sh && sudo shutdown -h now
```

The script strips the guest's identity and installs a
`settler-firstboot.service` that regenerates it on first power-on. The service
reads the instance name that `bin/install-vm.sh` wrote into the `.vmx`:

```bash
vmware-rpctool "info-get guestinfo.settler.instance"
```

and uses it as the hostname. If the VM was installed by hand with no name set,
it falls back to the existing hostname plus a random suffix, so clones stay
distinct either way. Then it disables itself.

It also reclaims free space with `fstrim`, which keeps the shipped image small
without ever inflating it. Do **not** reach for the traditional zero-fill trick
here: this box has a 512GB thin disk with ~12GB used, so writing zeros over the
free space would grow the `.vmdk` by up to 464GB. `--zerofill` exists for small
disks and is capped by `ZEROFILL_MAX_MB`.

> **Do not boot the VM again after generalizing.** A single boot re-creates the
> machine-id and the SSH host keys and undoes the work. Generalize, shut down,
> package.

## The two install paths

Both are in the `.dmg`, described in its `README.txt`.

**Drag and double-click** — for a single VM on a Mac:

1. Drag `<name>.vmwarevm` out of the disk image onto the internal disk.
2. Double-click it. Fusion opens and powers it on.

Do not run it from the mounted disk image — that is read-only, and the VM needs
to write to its own disk.

**`Install.command`** — for several VMs on one Mac, which is the fleet case:

1. Double-click `Install.command`.
2. Type a name when asked, e.g. the customer.

It copies the bundle to `~/Virtual Machines.localized/<name>.vmwarevm`, renames
the files inside, sets `displayName` so Fusion's library shows something
meaningful, strips the quarantine attribute, passes the name to the guest, and
opens it in Fusion. It refuses to overwrite an existing VM and checks free space
before starting a multi-gigabyte copy.

Non-interactively, for scripted rollout:

```bash
bin/install-vm.sh --source /Volumes/settler-homestead-17.0.4/settler-homestead-17.0.4.vmwarevm \
                  --name acme-corp --memory 8192 --cpus 6 --yes
```

### Gatekeeper

A `.dmg` that arrives by download or AirDrop is quarantined, and macOS will
refuse to run `Install.command` from an unidentified developer. Either:

- right-click `Install.command` → **Open** → **Open** (once per Mac), or
- sign and notarize the `.dmg` with your Developer ID, or
- distribute over an internal file share rather than a browser download, which
  does not set the quarantine attribute.

The installer clears the quarantine attribute from the VM files it copies, so
this only ever affects the installer script itself, never the VM.

## Distribution

The `.dmg` is a single ~3GB file, so anything that moves large files works.
In rough order of how well they suit twenty machines:

- **Internal file share (SMB/NFS)** — mount, run `Install.command` straight from
  the share. No download, no quarantine, no per-machine copy of the installer.
- **Internal HTTPS / S3 / MinIO** — good when the minis are not on one LAN.
  Publish the `.sha256` next to it and verify before installing.
- **USB SSD** — fine for a physical rollout day, and the fastest per-machine.
- **AirDrop** — works, but quarantines the installer.

Whatever the transport, verify before installing:

```bash
shasum -a 256 -c settler-homestead-17.0.4.sha256
```

Keep the `.manifest.txt` — it records the settler commit, the source box, the
guest OS, virtual hardware version and packaging date, which is what you will
want when a VM built eight months ago starts behaving oddly.

## Alternatives considered

The question behind this document was whether there are community tools or
mechanisms that solve VM packaging and reuse on Apple Silicon better than what
we have. There are, and the honest summary is: **if staying on VMware Fusion is
a requirement, `.vmwarevm` + `.dmg` is the right answer**, but two of the
alternatives are genuinely better at fleet distribution and worth knowing about.

### Staying with VMware Fusion

| Approach                                               | Verdict                                                                                                                                                                                                                                                                                                                                                                            |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **`.vmwarevm` bundle + `.dmg`** (what we do)           | Native double-click, no conversion, no extra tooling, works offline. Whole-image transfer every time — no deduplication between versions.                                                                                                                                                                                                                                          |
| **OVA / OVF via `ovftool`**                            | Does not work on Apple Silicon in either direction. Dead end.                                                                                                                                                                                                                                                                                                                      |
| **Fusion's built-in full clone**                       | Fine for one VM on one Mac via the GUI. Not a distribution mechanism — there is no artifact to hand anyone.                                                                                                                                                                                                                                                                        |
| **Vagrant box + `vagrant-vmware-desktop`**             | What we build today, and the right tool for developers who want `vagrant up`. Wrong tool for the fleet: it needs Vagrant, a paid-tier plugin, the `vagrant-vmware-utility` daemon and a `Vagrantfile` on every mini, and it hides VMs in `.vagrant/` where Fusion cannot see them (see `bin/register-fusion-vm.sh` for the workaround). Far more moving parts than a double-click. |
| **Fusion mass deployment package** ([KB 344190][mass]) | Broadcom's own answer for shipping Fusion *and* VMs together via Apple Remote Desktop or Jamf. Worth adopting if the minis are already MDM-managed — it can install Fusion, the licence key and the VM in one push. Its `.vmx` preparation guidance is the same as ours.                                                                                                           |

[mass]: https://knowledge.broadcom.com/external/article/344190/creating-a-vmware-fusion-mass-deployment.html

### Leaving VMware Fusion

| Tool                                       | What it offers                                                                                                                                                                                                                                                                                                                                                                                                                                        | Cost of switching                                                                               |
|--------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| **[Tart](https://tart.run)** (Cirrus Labs) | The best fit for this problem if Fusion is not mandatory. VMs are stored and distributed as **OCI images** in any container registry: `tart clone ghcr.io/org/homestead:17.0.4 acme`. That gives versioned, tagged, deduplicated, incrementally-pulled images — pulling v17.0.5 after v17.0.4 transfers only changed layers, not another 3GB. Uses Apple's native Virtualization.framework, so it is fast on Apple Silicon. There is a Packer plugin. | Not Fusion. CLI-first, no VM library GUI. Rebuild the packer pipeline against the Tart builder. |
| **[UTM](https://mac.getutm.app)**          | Free and open source. `.utm` bundles are double-clickable exactly like `.vmwarevm`, so the install story is identical to ours. Apple Virtualization.framework or QEMU.                                                                                                                                                                                                                                                                                | Not Fusion. Weaker CLI automation.                                                              |
| **Parallels Desktop**                      | `.pvm` bundles are double-clickable, `prlctl` is a good CLI, and there is a mature `vagrant-parallels` plugin. Note bento already supports `parallels-iso` on aarch64 — the readme's ARM build instructions use it. Migration would be the least disruptive of the "leave Fusion" options.                                                                                                                                                            | Per-seat licensing across 20 machines.                                                          |
| **[Lima](https://lima-vm.io)** / Colima    | YAML-declared Linux VMs, excellent for headless dev and containers.                                                                                                                                                                                                                                                                                                                                                                                   | No GUI, no bundle to hand anyone, wrong shape for a per-customer desktop VM.                    |
| **[Anka](https://veertu.com)** (Veertu)    | Commercial fleet VM management with registry-based distribution, built for exactly this scale.                                                                                                                                                                                                                                                                                                                                                        | Commercial licensing; aimed at CI fleets.                                                       |

If the fleet ever outgrows whole-image copies — twenty machines × 3GB per
release is 60GB over the wire each time — **Tart's OCI-registry model is the
upgrade path**, and it is worth prototyping before the next major rebuild. The
same registry-artifact idea can be applied without leaving Fusion by pushing the
`.vmwarevm` as an OCI artifact with [ORAS](https://oras.land), though you lose
the layer-level deduplication that makes Tart compelling.

## Verified end to end

Packaged `ubuntu-24.04-aarch64.vmware.box`, installed the result with
`bin/install-vm.sh`, and powered it on under **Fusion 26.0.0 on Apple Silicon**:

| Check               | Result                                                                        |
|---------------------|-------------------------------------------------------------------------------|
| Power-on            | clean, no *moved or copied* dialog, no prompts                                |
| Guest OS            | `Linux 6.8.0-138-generic aarch64`                                             |
| NIC driver in guest | `eth0: vmxnet3` — the driver is in-tree on Ubuntu 24.04, no extra work needed |
| DHCP lease          | `172.16.195.140/24`                                                           |
| Outbound            | `https://github.com -> HTTP 200 in 0.23s`                                     |
| Stack intact        | PHP 8.5.9, nginx 1.24.0, MySQL 8.0.46 (aarch64), node v22.23.2                |
| Services            | nginx active, mysql active, open-vm-tools active                              |
| Disk                | all 32 `.vmdk` extents present and referenced                                 |

**Identity regeneration confirmed.** The packaged `.vmx` ships with no
`uuid.bios`, no `uuid.location` and no `ethernet0.generatedAddress`. After the
first power-on Fusion had created all three, and they differ from another VM
running on the same host at the same time:

```
packaged VM   uuid.bios 56 4d f3 21 ... 25 59 56 85   MAC 00:0c:29:59:56:85
existing VM   uuid.bios 56 4d dc f3 8f ... 01 28 3d 1e  MAC 00:0c:29:28:3d:1e
```

Both ran concurrently with working networking, which is the five-VMs-per-mini
case in miniature. Fusion also assigned `ethernet0.pciSlotNumber = 160` itself,
confirming it is right to leave that out of the shipped `.vmx`.

**One caveat that first test surfaced:** the booted guest's hostname was
`vagrant`, the box default, because that VM was packaged without running
`bin/vm-generalize.sh` first. That is exactly the gap the generalize step
closes — package without it and every mini ends up with five hosts all called
`vagrant`, sharing a machine-id and a set of SSH host keys.

### Generalize round-trip, verified

The full loop was then run end to end: package → boot → `vm-generalize.sh` →
shut down → repackage → install under a new name → boot.

Baseline in the guest before generalizing, and after installing the repackaged
image as `beta-corp`:

|              | before             | after              |
|--------------|--------------------|--------------------|
| hostname     | `vagrant`          | `beta-corp`        |
| machine-id   | `8d6d7ca0…82de1`   | `b1fbef13…1db02`   |
| SSH host key | `SHA256:JvpX06aq…` | `SHA256:c1Fi3nsX…` |

`guestinfo.settler.instance` came through as `beta-corp`, `/etc/hosts` was
rewritten to match, the service disabled itself, and the guest came up with
0 failed units, nginx and mysql active, and working egress. First boot took
36 seconds, with the identity work finishing in about one second:

```
21:47:55 acme-corp  Starting settler-firstboot.service...
21:47:55 beta-corp  hostname acme-corp -> beta-corp
21:47:55 beta-corp  regenerated ssh host keys
21:47:56 beta-corp  done
```

The log prefix changing mid-sequence is the new hostname taking effect live.

Repackaging from a `.vmwarevm` that had been booted was also confirmed to strip
the `uuid.bios`, `uuid.location` and `generatedAddress` that Fusion wrote during
that boot, along with the `.lck`, `vmware.log` and `.scoreboard` runtime files.

### `bin/package` verified end to end

The whole two-command flow was then run with no manual steps at all —
`bin/package` on the box, then `Install.command` from the resulting `.dmg`:

```
⚡️ generalizing the guest (boots the VM, this takes a few minutes)
   waiting for VMware Tools
   pushing vm-generalize.sh to the guest
   running it
   shutting the guest down
   re-stripping the identity created by that boot
✅ guest generalized
```

Installed from that `.dmg` as `kandu-prod` and booted. First boot took 65
seconds and came up as:

|                     |                                            |
|---------------------|--------------------------------------------|
| hostname            | `kandu-prod` — taken from the install name |
| machine-id          | `8754fa63…03ff` (fresh)                    |
| SSH host key        | `SHA256:hpYK9tVK…` (fresh)                 |
| `settler-firstboot` | `disabled` (self-disabled after running)   |
| failed units        | 0                                          |
| NIC / egress        | `vmxnet3`, HTTP 200                        |

The sealed `.vmx` carried no `uuid.bios`, no `uuid.location`, no
`generatedAddress` and no `ethernet0.pciSlotNumber` — confirming the
re-strip after the generalize boot does its job.

### The baked-in service, verified through a real build

A full `bash bin/build` was run with the injection in place — 28 minutes,
exit 0 — and the resulting box packaged with `--no-generalize` deliberately, so
nothing but the build itself could have installed the service. Installed as
`baked-corp` and booted:

|                                     |                                       |
|-------------------------------------|---------------------------------------|
| `/usr/local/sbin/settler-firstboot` | present                               |
| unit file                           | present                               |
| `systemctl is-enabled` after boot   | `disabled` (ran, then self-disabled)  |
| hostname                            | `baked-corp` — from the install name  |
| machine-id                          | regenerated                           |
| failed units                        | 0                                     |
| stack                               | PHP 8.5.9, nginx active, mysql active |

```
15:07:59 vagrant     Starting settler-firstboot.service...
15:07:59 baked-corp  hostname vagrant -> baked-corp
15:07:59 baked-corp  done
```

The SSH host key was inherited from the build rather than regenerated, and the
journal has no "regenerated ssh host keys" line — exactly as intended, since key
removal is deliberately left to `bin/package`. Everything else came from the
image alone.

So a box straight off the build line already gives per-instance hostnames and
machine-ids, even if it is packaged without generalizing.

The hard link matters here: `bin/link-to-bento.sh` links `scripts/arm.sh` to
bento's `homestead_arm.sh`, so `bin/inject-firstboot.sh` must rewrite the file
**in place** (`cat >`, never `mv`) or the injection would land on a fresh inode
and never reach packer. Confirmed during the build — both paths shared one
inode and the block was present in the file packer uploaded.

### Two bugs the full build caught

**1. `bin/package` could not find a freshly built box.** Packer's vagrant
post-processor writes to `builds/build_complete/`, not `builds/`. Both
`bin/package` and `bin/build`'s closing message searched with `-maxdepth 1` and
came up empty, so the first thing anyone would do after a successful build —
run `bin/package` — would have failed with "no builds directory". Both now
recurse. (The `.box` files sitting directly in `builds/` on this machine are
older artifacts that had been moved up by hand, which is what disguised it.)

**2. `bin/build`'s closing message printed a version string as an argument.**
`bin/build` overwrites `HOMESTEAD_VERSION` with a display string
(`Homestead v17.0.4 ( support/17 ) 7475a26`) before the message used it, so the
suggested `register-local-box.sh` command was unusable. The bare values are now
captured as `*_VERSION_RAW` before they are wrapped.

### Two bugs earlier testing caught

Both were found by running the scripts rather than reading them, and both are
fixed:

**1. `dd if=/dev/zero` would have inflated the image toward 512GB.** The first
version of `vm-generalize.sh` zero-filled free space, which is the traditional
trick for shrinking an image. The settler box has a 512GB thin-provisioned
disk with ~12GB used — the guest reported **464GB free**, so the zero-fill
would have written 464GB into a sparse `.vmdk` and very nearly filled the build
host's disk. Free space is now reclaimed with `fstrim`, which takes seconds and
cannot inflate the image; `--zerofill` remains for small disks and refuses to
run above `ZEROFILL_MAX_MB`.

**2. `hostnamectl` stalled the first boot indefinitely.** `settler-firstboot`
runs early, with `DefaultDependencies=no`, before dbus and
`systemd-hostnamed` exist. `hostnamectl` blocks waiting for the system bus, so
the service hung after logging the hostname change and never finished — the VM
booted far enough to run, but never got a network address. The journal made it
plain: the first boot logged `hostname vagrant -> acme-corp` and stopped, while
a later boot (which skipped that branch, the hostname already being set) ran to
`done`.

The fix is to avoid anything needing a bus at that stage:

- write `/etc/hostname` and call `hostname` directly instead of `hostnamectl`
- drop `systemctl restart ssh` — the unit is ordered `Before=ssh.service`, so
  sshd picks up the new keys when it starts, and calling `systemctl` on a unit
  you are ordered before risks deadlocking the boot
- log to stdout and let systemd journal it, rather than piping to `systemd-cat`
- add `TimeoutStartSec=60`, so a future mistake degrades to a wrong hostname
  rather than a VM that never finishes booting

## Troubleshooting

**Fusion says the VM is in use / cannot power on**
A `.lck` directory survived the copy. Both scripts delete these, but if the
bundle was copied by hand: `rm -rf <vm>.vmwarevm/*.lck`.

**No network in the guest**
Check the NIC is vmxnet3, not e1000e:
`grep ethernet0 <vm>.vmwarevm/*.vmx`. If the guest sees the adapter but has no
address, a stale udev rule may have pinned the interface name to the old MAC —
`bin/vm-generalize.sh` removes those; on an already-deployed VM,
`rm /etc/udev/rules.d/70-persistent-net.rules` and reboot.

**Two VMs got the same IP**
`uuid.action = "create"` is missing from one of them, or the guest was never
generalized so both share a machine-id and therefore a DHCP DUID. Check
`grep uuid <vm>.vmwarevm/*.vmx` and `cat /etc/machine-id` in each guest.

**"This virtual machine might have been moved or copied" dialog appears**
`uuid.action` is not set. Answer **I copied it** — never *I moved it* — then fix
the `.vmx`.

**The `.dmg` is much larger than expected**
The guest was not generalized, so freed disk blocks still hold old data. Run
`bin/vm-generalize.sh` in the guest and repackage.

**`Install.command` will not run**
Gatekeeper quarantine — right-click → Open, see above.

**`bin/package` says "VMware Tools never came up, or the guest credentials are wrong"**
The generalize step signs into the guest as `vagrant`/`vagrant` over the Tools
channel. If the box uses different credentials, pass them:

```bash
bin/package --guest-user myuser --guest-pass mypass
```

If Tools genuinely is not running in the guest, package without generalizing
and do it by hand later:

```bash
bin/package --no-generalize
```

**`bin/package` says "no builds directory"**
It looks for `../bento/builds` relative to the settler checkout, matching the
layout `bin/build` expects. Point it somewhere else with `--box /path/to.box`
or `BUILDS_DIR=/path/to/builds`.

## Scripts

| Script                      | Runs on          | Purpose                                                                                                                                                                                                        |
|-----------------------------|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `bin/package`               | build Mac        | **the command after `bin/build`.** Finds the newest box, generalizes it, and writes the shippable `.dmg` to `dist/`                                                                                            |
| `bin/package-vmwarevm.sh`   | build Mac        | the engine underneath: box / `.vmx` / `.vmwarevm` → sanitised bundle + `.dmg` / `.zip` + checksums + manifest. Use directly for non-default names, sizes or sources                                            |
| `bin/install-vm.sh`         | each Mac mini    | install one named instance and open it in Fusion. Ships in the `.dmg` as `Install.command`.                                                                                                                    |
| `bin/vm-generalize.sh`      | inside the guest | strip guest identity, install the first-boot regeneration service, trim free space. Pushed in automatically by `bin/package` — not copied by hand. Also the single source of the first-boot service definition |
| `bin/inject-firstboot.sh`   | build Mac        | splice that service definition into `scripts/{arm,amd64}.sh` so packer bakes it into the image. Run by `bin/build`; `--check` guards against drift                                                             |
| `bin/register-local-box.sh` | build Mac        | register a built box with Vagrant (developer workflow, unchanged)                                                                                                                                              |
| `bin/register-fusion-vm.sh` | build Mac        | make a Vagrant-managed VM visible in Fusion's library (developer workflow, unchanged)                                                                                                                          |

Run any of them with `--help` for full options.
