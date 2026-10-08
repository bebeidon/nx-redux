#!/bin/bash
#
# Build the ffplay that ships in SYSTEM/shared/bin (video player backend).
#
# Shared across platforms, so it is built once with the tg5040 toolchain
# (gcc 8 / older glibc, runs on both devices); any other PLATFORM is refused.
# The real recipe is workspace/all/mediaplayer/include/ffplay/build.sh
# (FFmpeg 6.1 + fribidi, libxml2, libass static; freetype/fontconfig/SDL2/
# expat/png linked against the device copies in its syslibs/; our patched
# ffplay.c). Every download there is sha256-pinned. LGPL build: no
# --enable-gpl/--enable-nonfree.
#
# Runs INSIDE the toolchain container:
#   docker run --rm -v "$PWD/workspace":/root/workspace \
#     ghcr.io/loveretro/tg5040-toolchain:latest /bin/bash -c \
#     '. ~/.bashrc && cd /root/workspace && PLATFORM=tg5040 bash all/prebuilts/ffplay.sh'
#
# Output: all/prebuilts/output/tg5040/SYSTEM/shared/bin/ffplay (stripped).
# Scratch lives in /tmp/ffplay-build inside the container.
#
set -e

if [ "$PLATFORM" != "tg5040" ]; then
    echo "ffplay is shared: build it with PLATFORM=tg5040 (got '${PLATFORM}')" >&2
    exit 1
fi

PREBUILTS_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$PREBUILTS_DIR/output/$PLATFORM/SYSTEM/shared/bin/ffplay"

FFPLAY_OUT="$OUT" bash "$PREBUILTS_DIR/../mediaplayer/include/ffplay/build.sh"

# No extra strip: FFmpeg's `make ffplay` strips it (ffplay_g is the debug copy)
echo "ffplay -> $OUT"
