#!/bin/bash
#
# Build the rsync that ships in SYSTEM/shared/bin. Device Sync
# (all/sync/sync.c) and the netplay wizard's save pull (all/netplay-wizard/
# wizard_sync.c) run it as a LAN daemon and as a client.
#
# Shared across platforms, so it is built once with the tg5040 toolchain; any
# other PLATFORM is refused. Linked dynamically against the device's glibc
# only: the toolchain's static glibc needs kernel >= 4.19 and aborts on the
# Brick's 4.9 ("FATAL: kernel too old"). zlib and popt are still built in.
#
# Feature set matches the binary it replaces (3.2.0dev): bundled zlib and
# popt, iconv on, no xxhash/zstd/lz4/openssl (md4/md5 checksums, zlib/zlibx
# compression), no ACLs, no xattrs. rsync negotiates the protocol, so this
# still talks to 3.2.x peers on older firmware.
#
# Runs INSIDE the toolchain container:
#   docker run --rm -v "$PWD/workspace":/root/workspace \
#     ghcr.io/loveretro/tg5040-toolchain:latest /bin/bash -c \
#     '. ~/.bashrc && cd /root/workspace && PLATFORM=tg5040 bash all/prebuilts/rsync.sh'
#
# Output: all/prebuilts/output/tg5040/SYSTEM/shared/bin/rsync (stripped).
# Scratch lives in /tmp/rsync-build inside the container.
#
set -e

RSYNC_VERSION=3.4.1
RSYNC_URL="https://download.samba.org/pub/rsync/src/rsync-${RSYNC_VERSION}.tar.gz"
# Same bytes as the GitHub release asset and Homebrew's rsync 3.4.1 formula
RSYNC_SHA256=2924bcb3a1ed8b551fc101f740b9f0fe0a202b115027647cf69850d65fd88c52

if [ "$PLATFORM" != "tg5040" ]; then
    echo "rsync is shared: build it with PLATFORM=tg5040 (got '${PLATFORM}')" >&2
    exit 1
fi
if [ -z "$CROSS_COMPILE" ]; then
    echo "CROSS_COMPILE is not set: run this inside the toolchain container" >&2
    exit 1
fi

PREBUILTS_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$PREBUILTS_DIR/output/$PLATFORM/SYSTEM/shared/bin/rsync"
BUILD_DIR=/tmp/rsync-build

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

wget -q "$RSYNC_URL" -O rsync.tar.gz
echo "$RSYNC_SHA256  rsync.tar.gz" | sha256sum -c --quiet -
tar xzf rsync.tar.gz
cd "rsync-${RSYNC_VERSION}"

./configure \
    --host=aarch64-linux-gnu \
    CC="${CROSS_COMPILE}gcc" \
    CFLAGS="-O2" \
    --disable-xxhash \
    --disable-zstd \
    --disable-lz4 \
    --disable-openssl \
    --disable-acl-support \
    --disable-xattr-support \
    --disable-md2man \
    --with-included-zlib \
    --with-included-popt

make -j"$(nproc)" rsync
"${CROSS_COMPILE}strip" rsync

mkdir -p "$(dirname "$OUT")"
cp rsync "$OUT"
echo "rsync -> $OUT"
