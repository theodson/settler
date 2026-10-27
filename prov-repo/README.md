# VM images for VMware Fusion

Packaged Ubuntu 24.04 VMs for the Mac mini fleet. Each `.dmg` contains a ready-to-run
`.vmwarevm`, an `Install.command` that installs one named copy, and a `README.txt`.
A `.sha256` and a `.manifest.txt` sit beside each `.dmg`.

> **Internal use only.** These images contain shared infrastructure credentials. Do not copy
> them outside the company network or to personal or cloud storage.

## Which image

| File | What it is |
|---|---|
| `hs-nss-template-<version>-aarch64.dmg` | NSS template for **Apple Silicon** Macs (M1 and later) |
| `hs-nss-template-<version>-x86_64.dmg` | NSS template for **Intel** Macs |
| `settler-homestead-<version>-<arch>.dmg` | The plain Homestead base the templates are built from |

Pick the architecture that matches the Mac: Apple menu → About This Mac → *Chip* (Apple M…) means
`aarch64`; *Processor* (Intel) means `x86_64`. A VM does not run on the other kind of Mac.

## Before you start

- **VMware Fusion** installed in `/Applications`.
- **Disk space:** about 4 × the `.dmg` size free (the download, plus the installed VM).
- **Network:** this Mac must reach `prov-repo.blueglue.com.au`.

## Quick install (recommended)

Open **Terminal** and paste:

```bash
bash <(curl -fsSL http://prov-repo.blueglue.com.au:9000/boxes/settler-homestead-17.0.4/download.sh)
```

[`download.sh`](download.sh) will:

1. pick the newest `hs-nss-template` image for this Mac's architecture;
2. download it to `~/Downloads/vm-images` (re-run it to resume an interrupted download);
3. verify it against the published `.sha256`. On a mismatch it deletes the file and stops, or with
   `--keep-on-mismatch` keeps it, warns and stops;
4. clear the macOS quarantine flag (`xattr -dr com.apple.quarantine`);
5. mount the `.dmg`, show it in Finder and open **Install.command** in a new Terminal window.

In that window, type a name for this VM when asked, for example the customer or site. The installer
copies the VM, gives it a new identity (UUID, MAC address, hostname, SSH keys) and opens it in
Fusion. Several VMs on one Mac are fine, as long as each has its own name.

Useful options (add after the command above, e.g. `… download.sh) --list`):

| Option | Effect |
|---|---|
| `--list` | Show the images available and which match this Mac |
| `--image hs-nss-template-17.0.4-20261026-aarch64.dmg` | Fetch a specific image instead of the newest |
| `--name acme-site` | Install with this name in the current Terminal, with no extra window |
| `--no-install` | Download, verify and mount only |
| `--dir PATH` | Download somewhere other than `~/Downloads/vm-images` |
| `--keep-on-mismatch` | If the SHA-256 check fails, keep the `.dmg`, print expected and actual checksums, and stop (default: delete it) |

> Use `bash <(curl …)` as shown, not `curl … | bash`: the installer needs the keyboard to ask for
> the VM's name. To read the script first: `curl -fsSLO …/download.sh`, review it, then
> `bash download.sh`.

## Manual install

1. Download the `.dmg` and its `.sha256` from this page into the same folder.
2. Verify the download (from that folder):

   ```bash
   shasum -a 256 -c hs-nss-template-17.0.4-20261026-aarch64.sha256
   ```

   It must print `…dmg: OK`. If it does not, download the `.dmg` again.
3. Clear the quarantine flag that the browser added, so the disk image and its installer are not
   blocked:

   ```bash
   xattr -dr com.apple.quarantine ~/Downloads/hs-nss-template-17.0.4-20261026-aarch64.dmg
   ```

4. Double-click the `.dmg` to mount it.
5. Double-click **Install.command** and enter a name when asked.

To install a single VM without the installer instead, drag the `.vmwarevm` from the disk image to
`~/Virtual Machines.localized/` and double-click it. Do not run it from the disk image itself; it
is read-only.

When the VM is running, eject the disk image (Finder sidebar ⏏, or `hdiutil detach /Volumes/<name>`).

## Troubleshooting

| Symptom | Fix |
|---|---|
| *"Install.command cannot be opened because it is from an unidentified developer"* | The quarantine flag is still set. Run the `xattr` command from step 3 on the `.dmg`, eject and remount it; or right-click Install.command → **Open** → **Open**. |
| `SHA-256 mismatch` or `shasum … FAILED` | The download is damaged or incomplete. `download.sh` deletes it, so re-run to fetch it again. To keep the file for investigation (for example, while an upload to prov-repo is still finishing), re-run with `--keep-on-mismatch`; it stops without mounting. |
| `download is incomplete` | The connection dropped. Re-run the same command; it resumes. |
| `not built for this Mac` | You chose the other architecture. Use `--list` and pick the one marked for this Mac. |
| Fusion asks *"Did you move it or copy it?"* | Answer **I Copied It**. Never *I Moved It*: two VMs would share a MAC address. |
| The VM has no network | Check Fusion → VM → Settings → Network Adapter. NAT ("Share with my Mac") works on any network; bridged needs the Mac's own LAN. |

## For maintainers

Images are built and packaged with the settler repository (`bin/package-vmwarevm.sh`, see
`docs/packaging.md`). Publish each `.dmg` with its `.sha256` and `.manifest.txt` in this folder; the
`.sha256` must keep the packager's format (`<sha256>  <file>.dmg`), which `download.sh` reads.
Upload the `.dmg` before its `.sha256`, so a half-copied image cannot be mistaken for a verified one.
