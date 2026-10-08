#!/bin/bash
# Builds the hooked SDL2 that DraStic loads from NDS.pak/libs
# (libSDL2-2.0.so.0) from pinned source, so the binary no longer has to be
# committed to skeleton/. Upstream is trngaje's SDL_drastic (zlib); we apply
# the shared hook patch, then the per-platform fix patch, and build with the
# one recipe in workspace/all/other/sdl2-drastic/build-sdl2-drastic-<plat>.sh
# (which pins its own header-only deps: json-c, EGL-Registry, libdrm, gbm.h).
#
# Runs inside the platform toolchain container, from /root/workspace:
#   docker run --rm -v "$PWD/workspace":/root/workspace \
#     ghcr.io/loveretro/<plat>-toolchain:latest /bin/bash -c \
#     '. ~/.bashrc && cd /root/workspace && PLATFORM=<plat> bash all/prebuilts/sdl2-drastic.sh'
#
# Work dir:  all/prebuilts/work/sdl2-drastic-$PLATFORM/ (wiped and recloned every run)
# Output:    all/prebuilts/output/$PLATFORM/SYSTEM/$PLATFORM/paks/Emus/NDS.pak/libs/libSDL2-2.0.so.0

set -e

SDL_DRASTIC_REPO=https://github.com/trngaje/SDL_drastic.git
SDL_DRASTIC_COMMIT=eb2e00f8b7459df90e273208f6cc49427c64267f   # knulli2.30.8
# What `git describe --tags --long` gives on a full clone; a shallow fetch has no
# tags, so feed it to SDL's showrev.sh via VERSION.txt to keep SDL_REVISION stable
SDL_DRASTIC_DESCRIBE=release-2.30.4-93-geb2e00f8b

# Source paths baked into the binary (debug info, __FILE__) are mapped to this
# prefix so the output does not depend on where the workspace is checked out
SOURCE_PREFIX_MAP="${SOURCE_PREFIX_MAP:-/sdl2-drastic}"

case "$PLATFORM" in
	tg5040|tg5050) ;;
	*) echo "sdl2-drastic: PLATFORM must be tg5040 or tg5050 (got '$PLATFORM')" >&2; exit 1 ;;
esac

PREBUILTS_DIR="$(cd "$(dirname "$0")" && pwd)"
RECIPE_DIR="$PREBUILTS_DIR/../other/sdl2-drastic"
WORK_DIR="$PREBUILTS_DIR/work/sdl2-drastic-$PLATFORM"
DEST_DIR="$PREBUILTS_DIR/output/$PLATFORM/SYSTEM/$PLATFORM/paks/Emus/NDS.pak/libs"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/SDL_drastic"

# Fetch exactly the pinned commit
SRC="$WORK_DIR/SDL_drastic"
git -C "$SRC" init -q
git -C "$SRC" fetch -q --depth 1 "$SDL_DRASTIC_REPO" "$SDL_DRASTIC_COMMIT"
git -C "$SRC" checkout -q FETCH_HEAD
if [ "$(git -C "$SRC" rev-parse HEAD)" != "$SDL_DRASTIC_COMMIT" ]; then
	echo "sdl2-drastic: checked-out commit does not match $SDL_DRASTIC_COMMIT" >&2
	exit 1
fi

# Same order as the platform Makefile clone rule; the leading "# license:" line
# of each patch is ignored by patch(1) as leading garbage
( cd "$SRC" && patch -p1 --forward --no-backup-if-mismatch < "$RECIPE_DIR/0006-add-hook-for-drastic.patch" )
( cd "$SRC" && patch -p1 --forward --no-backup-if-mismatch < "$RECIPE_DIR/fix-$PLATFORM.patch" )

echo "$SDL_DRASTIC_DESCRIBE" > "$SRC/VERSION.txt"

( cd "$WORK_DIR" && \
	SDL_SRC_DIR="$SRC" OUT_DIR="$WORK_DIR/output" EXTRA_PREFIX="$WORK_DIR/extra-deps" \
	EXTRA_CFLAGS="-ffile-prefix-map=$WORK_DIR=$SOURCE_PREFIX_MAP" \
	bash "$RECIPE_DIR/build-sdl2-drastic-$PLATFORM.sh" )

mkdir -p "$DEST_DIR"
cp "$WORK_DIR/output/libSDL2-2.0.so.0" "$DEST_DIR/libSDL2-2.0.so.0"
echo "sdl2-drastic: $DEST_DIR/libSDL2-2.0.so.0"
