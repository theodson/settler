#!/usr/bin/env bash
#
# download.sh - fetch a packaged VM image from prov-repo, verify it, and start
# its installer. Published next to the .dmg files it downloads; see README.md.
#
#   bash <(curl -fsSL http://prov-repo.blueglue.com.au:9000/boxes/settler-homestead-17.0.4/download.sh)
#
# Steps:
#   1. pick the image: newest hs-nss-template-*-<this Mac's arch>.dmg, or --image
#   2. download it (resumes a partial download) and its .sha256 if published
#   3. verify the SHA-256 - a mismatch stops here and nothing is mounted
#   4. clear com.apple.quarantine so the mounted volume and Install.command are
#      not blocked by Gatekeeper
#   5. mount the .dmg, show it in Finder, and open Install.command in Terminal
#
# Runs under macOS's stock bash 3.2. Nothing is installed until Install.command
# asks for an instance name.

set -euo pipefail

BASE_URL="${BASE_URL:-http://prov-repo.blueglue.com.au:9000/boxes/settler-homestead-17.0.4}"
PREFIX="${PREFIX:-hs-nss-template}"
DEST_DIR="${DEST_DIR:-$HOME/Downloads/vm-images}"
IMAGE=""
INSTANCE_NAME=""
LIST_ONLY=0
NO_INSTALL=0
ANY_ARCH=0
KEEP_ON_MISMATCH=0

usage() {
    cat <<USAGE
download.sh - download, verify and install a VM image from prov-repo

Usage:
  bash <(curl -fsSL $BASE_URL/download.sh) [options]

Options:
  -i, --image NAME    the .dmg to fetch (default: newest $PREFIX-*-<arch>.dmg)
  -p, --prefix NAME   image family when --image is not given (default: $PREFIX)
  -n, --name NAME     instance name; runs the installer here instead of
                      opening it in a new Terminal window
  -d, --dir DIR       download directory (default: $DEST_DIR)
  -l, --list          list the images available for this Mac and exit
      --no-install    download, verify and mount only
      --any-arch      allow an image built for the other CPU architecture
      --keep-on-mismatch
                      if the SHA-256 does not match, keep the .dmg, warn and
                      stop (default: delete it so a re-run downloads afresh)
  -h, --help          this text

Environment: BASE_URL, PREFIX, DEST_DIR override the defaults above.
USAGE
}

say()  { printf '%s\n' "$*"; }
fail() { printf '✋ %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
    -i | --image) IMAGE="${2:?--image needs a name}"; shift 2 ;;
    -p | --prefix) PREFIX="${2:?--prefix needs a name}"; shift 2 ;;
    -n | --name) INSTANCE_NAME="${2:?--name needs a name}"; shift 2 ;;
    -d | --dir) DEST_DIR="${2:?--dir needs a path}"; shift 2 ;;
    -l | --list) LIST_ONLY=1; shift ;;
    --no-install) NO_INSTALL=1; shift ;;
    --any-arch) ANY_ARCH=1; shift ;;
    --keep-on-mismatch) KEEP_ON_MISMATCH=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; fail "unknown option: $1" ;;
    esac
done

[ "$(uname -s)" = Darwin ] || fail "this installer is for macOS"

# The image names carry the guest architecture; a guest only runs on a Mac of
# the same CPU family (Fusion does not emulate across them).
case "$(uname -m)" in
arm64) ARCH=aarch64 ;;
x86_64) ARCH=x86_64 ;;
*) fail "unsupported Mac architecture: $(uname -m)" ;;
esac

# Every .dmg in the directory listing, oldest to newest by version-ish sort.
available() {
    curl -fsSL --max-time 30 "$BASE_URL/" |
        grep -oE 'href="[^"]+\.dmg"' | sed -e 's/^href="//' -e 's/"$//' -e 's|.*/||' |
        sort -u | sort -t- -k1,1 -V
}

if [ "$LIST_ONLY" = 1 ]; then
    say "Images on $BASE_URL (this Mac: $ARCH):"
    available | while read -r name; do
        case "$name" in *"-$ARCH.dmg") say "  $name" ;; *) say "  $name   (other architecture)" ;; esac
    done
    exit 0
fi

if [ -z "$IMAGE" ]; then
    IMAGE="$(available | grep -E "^${PREFIX}-.*-${ARCH}\.dmg$" | tail -1 || true)"
    [ -n "$IMAGE" ] || fail "no $PREFIX-*-$ARCH.dmg found on $BASE_URL (try --list)"
fi
case "$IMAGE" in *.dmg) ;; *) IMAGE="$IMAGE.dmg" ;; esac
case "$IMAGE" in
*"-$ARCH.dmg") ;;
*) [ "$ANY_ARCH" = 1 ] || fail "$IMAGE is not built for this Mac ($ARCH); use --any-arch to fetch it anyway" ;;
esac

if [ "$NO_INSTALL" = 0 ] && [ ! -d "/Applications/VMware Fusion.app" ]; then
    fail "VMware Fusion is not installed in /Applications - install it first, or use --no-install"
fi

name="${IMAGE%.dmg}"
dmg="$DEST_DIR/$IMAGE"
sums="$DEST_DIR/$name.sha256"
mkdir -p "$DEST_DIR"

say "📦 $IMAGE"
say "   from : $BASE_URL"
say "   to   : $DEST_DIR"

# Free space: the download, plus room for Install.command's copy of the VM.
size="$(curl -fsSI --max-time 30 "$BASE_URL/$IMAGE" | tr -d '\r' | awk 'tolower($1)=="content-length:" {print $2}' | tail -1)"
[ -n "$size" ] || fail "cannot read $BASE_URL/$IMAGE - check the name and that this Mac can reach prov-repo"
free_kb="$(df -k "$DEST_DIR" | awk 'NR==2 {print $4}')"
need_kb=$(( size * 4 / 1024 ))
if [ "$free_kb" -lt "$need_kb" ]; then
    fail "not enough free disk space: need about $(( need_kb / 1024 / 1024 )) GB, have $(( free_kb / 1024 / 1024 )) GB"
fi

# Checksum first, so a finished download can be verified before deciding to
# fetch again. A missing .sha256 is reported, not fatal.
have_sums=0
if curl -fsSL --max-time 30 -o "$sums.part" "$BASE_URL/$name.sha256"; then
    mv "$sums.part" "$sums"
    have_sums=1
else
    rm -f "$sums.part"
    say "⚠️  no $name.sha256 published - the download cannot be verified"
fi

verify() {
    [ "$have_sums" = 1 ] || return 0
    (cd "$DEST_DIR" && grep -F " $IMAGE" "$(basename "$sums")" | shasum -a 256 -c -) >/dev/null 2>&1
}

# A failed check either removes the file (default) so a re-run starts clean,
# or, with --keep-on-mismatch, leaves it for inspection. Either way nothing
# is mounted.
mismatch() {
    if [ "$KEEP_ON_MISMATCH" = 1 ]; then
        printf '⚠️  SHA-256 mismatch for %s\n' "$dmg" >&2
        printf '   expected: %s\n' "$(awk -v f="$IMAGE" '$2 == f {print $1}' "$sums")" >&2
        printf '   actual  : %s\n' "$(shasum -a 256 "$dmg" | awk '{print $1}')" >&2
        fail "kept the .dmg for inspection and stopped; delete it and re-run to download again"
    fi
    rm -f "$dmg"
    fail "SHA-256 mismatch - the download was removed; re-run to fetch it again"
}

# A full-size file already here that fails verification cannot be resumed.
if [ -f "$dmg" ] && [ "$(stat -f %z "$dmg")" = "$size" ] && [ "$have_sums" = 1 ] && ! verify; then
    if [ "$KEEP_ON_MISMATCH" = 1 ]; then
        mismatch
    fi
    say "⚠️  the existing $IMAGE fails verification - downloading it again"
    rm -f "$dmg"
fi

if [ -f "$dmg" ] && [ "$(stat -f %z "$dmg")" = "$size" ] && { [ "$have_sums" = 0 ] || verify; }; then
    say "✅ already downloaded$([ "$have_sums" = 1 ] && echo ' and verified')"
else
    say "⚡️ downloading $(( size / 1024 / 1024 )) MB (re-run to resume if interrupted)"
    curl -fL --retry 3 -C - -o "$dmg" "$BASE_URL/$IMAGE"
    [ "$(stat -f %z "$dmg")" = "$size" ] || fail "download is incomplete - re-run to resume"
    if [ "$have_sums" = 1 ]; then
        say "⚡️ verifying SHA-256"
        verify || mismatch
        say "✅ SHA-256 verified"
    fi
fi

# curl does not set the quarantine flag, but a copy that arrived through a
# browser, AirDrop or Messages does. Clearing it on the .dmg keeps the mounted
# volume - and Install.command on it - out of Gatekeeper's way.
xattr -dr com.apple.quarantine "$dmg" 2>/dev/null || true

say "⚡️ mounting"
mount_point="$(hdiutil attach "$dmg" | awk -F'\t' '$NF ~ /^\/Volumes\// {print $NF}' | tail -1)"
[ -n "$mount_point" ] && [ -d "$mount_point" ] || fail "could not mount $dmg"
say "   mounted at $mount_point"
open "$mount_point"

if [ "$NO_INSTALL" = 1 ]; then
    say "✅ done - run Install.command from $mount_point when ready"
    exit 0
fi

[ -f "$mount_point/Install.command" ] || fail "no Install.command on $mount_point - install from the .vmwarevm by hand (see README.txt there)"

if [ -n "$INSTANCE_NAME" ]; then
    say "⚡️ installing as '$INSTANCE_NAME'"
    # Interactive prompts must read the terminal, not this script's stdin.
    bash "$mount_point/Install.command" --name "$INSTANCE_NAME" </dev/tty
else
    say "⚡️ opening Install.command in Terminal - enter an instance name there (e.g. the customer)"
    open -a Terminal "$mount_point/Install.command"
fi
say "   When the install has finished, eject the disk image: hdiutil detach \"$mount_point\""
