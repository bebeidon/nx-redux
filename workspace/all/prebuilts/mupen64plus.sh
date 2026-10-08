#!/bin/bash
# mupen64plus.sh: builds the standalone mupen64plus that ships in N64.pak (the
# core library, the ui-console frontend and the audio/input/rsp/Rice plugins)
# from pinned sources, for one platform. Output lands in
# output/$PLATFORM/SYSTEM/$PLATFORM/paks/Emus/N64.pak/ and replaces the
# binaries that used to be committed under skeleton/SYSTEM/$PLATFORM/paks/Emus/N64.pak/.
# The GLideN64 video plugin is built by gliden64.sh; m64p-server.elf is ours.
#
# Recipe and the reasons behind it: workspace/all/other/mupen64plus/README.md
# ("Build (TG5040)" and "TG5050 build differences"). In short:
# - core: NEON=1 PIE=1 USE_GLES=1 VULKAN=0 NETPLAY=1 -O3, with SDL2_net 2.2.0
#   built here static + PIC and linked into the .so by archive path (the tg5050
#   sysroot also has a shared libSDL2_net we must not pick up), so netplay adds
#   no runtime dependency. tg5050 links libpng16 using vendored 1.6.37 headers
#   (the sysroot's png.h points at a libpng16/ dir that isn't there).
# - ui-console, audio-sdl, video-rice: patched (workspace/all/other/mupen64plus/
#   *.patch). Rice compiles the in-game overlay from workspace/all/common, and on
#   tg5050 also needs the KHR/GLES3 headers its sysroot lacks (fetched from the
#   Khronos registries at the revisions the tg5040 sysroot ships).
# - input-sdl, rsp-hle: stock upstream 2.6.0 (the version the old binaries
#   reported); same Makefile conventions, -O3.
# Like the binaries they replace, the outputs are not stripped.
#
# Runs inside the toolchain container, from the workspace root:
#   docker run --rm -v "$PWD/workspace":/root/workspace \
#     ghcr.io/loveretro/tg5050-toolchain:latest /bin/bash -c \
#     '. ~/.bashrc && cd /root/workspace && PLATFORM=tg5050 bash all/prebuilts/mupen64plus.sh'
# (same with tg5040). Idempotent: sources are fetched/verified once into
# work/mupen64plus-$PLATFORM/ and rebuilt incrementally; a changed pin or patch
# re-clones that checkout. Delete the dir to force a clean rebuild.
set -e

# keep the MUPEN64PLUS_* pins in sync with workspace/<platform>/Makefile
MUPEN64PLUS_CORE_REPO=https://github.com/mupen64plus/mupen64plus-core.git
MUPEN64PLUS_CORE_COMMIT=d747ccee850799a8f30152cbbaa200639813a0de  # 2026-02-24
MUPEN64PLUS_UI_REPO=https://github.com/mupen64plus/mupen64plus-ui-console.git
MUPEN64PLUS_UI_COMMIT=927abd08a390325ee3712a99a5e11d94855ddaee  # 2026-02-19
MUPEN64PLUS_AUDIO_REPO=https://github.com/mupen64plus/mupen64plus-audio-sdl.git
MUPEN64PLUS_AUDIO_COMMIT=2ed23eda04f10f1285fdc1d26807b5c34f9f3faa  # 2026-02-19
MUPEN64PLUS_RICE_REPO=https://github.com/mupen64plus/mupen64plus-video-rice.git
MUPEN64PLUS_RICE_COMMIT=038882dd2e7cb660fd7512c0745032f17edd0bfa  # master, 2026-06-23
MUPEN64PLUS_INPUT_REPO=https://github.com/mupen64plus/mupen64plus-input-sdl.git
MUPEN64PLUS_INPUT_COMMIT=f2ca3839415d45a547f79d21177dfe15a0ce6d8c  # tag 2.6.0
MUPEN64PLUS_RSP_REPO=https://github.com/mupen64plus/mupen64plus-rsp-hle.git
MUPEN64PLUS_RSP_COMMIT=2798e65d6fc89d89aace0b0d779af6406809b940  # tag 2.6.0

SDL2_NET_VERSION=2.2.0
SDL2_NET_URL=https://github.com/libsdl-org/SDL_net/releases/download/release-$SDL2_NET_VERSION/SDL2_net-$SDL2_NET_VERSION.tar.gz
SDL2_NET_SHA256=4e4a891988316271974ff4e9585ed1ef729a123d22c08bd473129179dc857feb

# tg5050 only: libpng headers (the library itself comes from the sysroot)
LIBPNG_VERSION=1.6.37
LIBPNG_URL=https://github.com/glennrp/libpng/archive/refs/tags/v$LIBPNG_VERSION.tar.gz
LIBPNG_SHA256=ca74a0dace179a8422187671aee97dd3892b53e168627145271cad5b5ac81307

# tg5050 only: GLES3 + KHR headers for Rice ("<dest path> <url> <sha256>")
KHRONOS_HEADERS="
GLES3/gl3.h https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/4bec0553c4dd8c1c355491cb4d98b6a4e63dae79/api/GLES3/gl3.h 22c73bac11b2e69ce584fa20d9b3398fa8814bbd44470864a4e661239369050b
GLES3/gl32.h https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/f37a01b810c6b02dd22979352df995555b51ae50/api/GLES3/gl32.h a2cfd7d890f16f67665e01e6f514a7c75bfc702e50c8861a44d04536271fffd1
GLES3/gl3platform.h https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/f37a01b810c6b02dd22979352df995555b51ae50/api/GLES3/gl3platform.h b4595aafef1eb9b4705cf8a69e29aadb8eb8e3dd3baf8b34ab702c9174dcb549
KHR/khrplatform.h https://raw.githubusercontent.com/KhronosGroup/EGL-Registry/7fdf7d3a1ad50afa03968db889b68af211da6e27/api/KHR/khrplatform.h fe7725728dc40d46134d9838d29e3bbbc95a70e77a1182a2be9ded6470a2378d
"

case "$PLATFORM" in
	tg5040|tg5050) ;;
	*) echo "error: PLATFORM must be tg5040 or tg5050 (got '$PLATFORM')" >&2; exit 1 ;;
esac
: "${CROSS_COMPILE:?run inside the toolchain container after sourcing ~/.bashrc}"
: "${SYSROOT:?run inside the toolchain container after sourcing ~/.bashrc}"
export PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-$SYSROOT/usr/lib/pkgconfig}
export PKG_CONFIG_SYSROOT_DIR=${PKG_CONFIG_SYSROOT_DIR:-$SYSROOT}

HERE=$(cd "$(dirname "$0")" && pwd)
WORKSPACE=$(cd "$HERE/../.." && pwd)
PATCHES=$WORKSPACE/all/other/mupen64plus
WORK=$HERE/work/mupen64plus-$PLATFORM
OUT=$HERE/output/$PLATFORM/SYSTEM/$PLATFORM/paks/Emus/N64.pak
JOBS=$(nproc)
mkdir -p "$WORK" "$OUT"

# fetch <url> <sha256> <dest>: downloads once, fails on a checksum mismatch
fetch() {
	if [ ! -f "$3" ]; then
		mkdir -p "$(dirname "$3")"
		wget -q -O "$3.part" "$1"
		mv "$3.part" "$3"
	fi
	if ! echo "$2  $3" | sha256sum -c --quiet -; then
		echo "error: sha256 mismatch for $3 (from $1)" >&2
		rm -f "$3"
		exit 1
	fi
}

# checkout <dir> <repo> <commit> [patch]: a shallow checkout of <commit> with
# <patch> applied. The marker records the pin and the patch checksum, so a
# changed pin or patch re-clones instead of building stale sources.
checkout() {
	local dir=$1 repo=$2 commit=$3 patch=$4 want
	want=$commit
	if [ -n "$patch" ]; then want="$want $(cksum < "$patch" | cut -d' ' -f1-2)"; fi
	if [ -f "$dir/.nx-pinned" ] && [ "$(cat "$dir/.nx-pinned")" = "$want" ]; then
		return
	fi
	rm -rf "$dir"
	git init -q "$dir"
	git -C "$dir" fetch -q --depth 1 "$repo" "$commit"
	git -C "$dir" checkout -q FETCH_HEAD
	[ -z "$patch" ] || git -C "$dir" apply "$patch"
	echo "$want" > "$dir/.nx-pinned"
}

checkout "$WORK/mupen64plus-core" "$MUPEN64PLUS_CORE_REPO" "$MUPEN64PLUS_CORE_COMMIT"
checkout "$WORK/mupen64plus-ui-console" "$MUPEN64PLUS_UI_REPO" "$MUPEN64PLUS_UI_COMMIT" "$PATCHES/mupen64plus-ui-console.patch"
checkout "$WORK/mupen64plus-audio-sdl" "$MUPEN64PLUS_AUDIO_REPO" "$MUPEN64PLUS_AUDIO_COMMIT" "$PATCHES/mupen64plus-audio-sdl.patch"
checkout "$WORK/mupen64plus-video-rice" "$MUPEN64PLUS_RICE_REPO" "$MUPEN64PLUS_RICE_COMMIT" "$PATCHES/mupen64plus-video-rice.patch"
checkout "$WORK/mupen64plus-input-sdl" "$MUPEN64PLUS_INPUT_REPO" "$MUPEN64PLUS_INPUT_COMMIT"
checkout "$WORK/mupen64plus-rsp-hle" "$MUPEN64PLUS_RSP_REPO" "$MUPEN64PLUS_RSP_COMMIT"
APIDIR=$WORK/mupen64plus-core/src/api

# SDL2_net, static + PIC, installed into the work dir (not the sysroot). The
# debug prefix map keeps the build path out of the core (it was built in /tmp).
NET=$WORK/sdl2_net
fetch "$SDL2_NET_URL" "$SDL2_NET_SHA256" "$WORK/dl/SDL2_net-$SDL2_NET_VERSION.tar.gz"
if [ ! -f "$NET/lib/libSDL2_net.a" ]; then
	rm -rf "$WORK/SDL2_net-$SDL2_NET_VERSION" "$NET"
	tar -xzf "$WORK/dl/SDL2_net-$SDL2_NET_VERSION.tar.gz" -C "$WORK"
	(cd "$WORK/SDL2_net-$SDL2_NET_VERSION" &&
		./configure --host="${CROSS_COMPILE%-}" --prefix="$NET" \
			--disable-shared --enable-static --with-pic CC="${CROSS_COMPILE}gcc" \
			CFLAGS="-g -O2 -fdebug-prefix-map=$WORK=/tmp" &&
		make -j"$JOBS" && make install)
fi

# Common make variables. SDL_CFLAGS/SDL_LDLIBS on the command line bypass the
# Makefiles' own pkg-config probing (including the core's SDL2_net append).
SDL_C=$(pkg-config --cflags sdl2)
SDL_L=$(pkg-config --libs sdl2)
MK="CROSS_COMPILE=$CROSS_COMPILE HOST_CPU=aarch64 PKG_CONFIG=pkg-config"
PNG=""
GLES_CPPFLAGS=""
if [ "$PLATFORM" = tg5050 ]; then
	fetch "$LIBPNG_URL" "$LIBPNG_SHA256" "$WORK/dl/libpng-$LIBPNG_VERSION.tar.gz"
	PNG_HEADERS=$WORK/libpng-$LIBPNG_VERSION
	if [ ! -f "$PNG_HEADERS/pnglibconf.h" ]; then
		rm -rf "$PNG_HEADERS"
		tar -xzf "$WORK/dl/libpng-$LIBPNG_VERSION.tar.gz" -C "$WORK"
		cp "$PNG_HEADERS/scripts/pnglibconf.h.prebuilt" "$PNG_HEADERS/pnglibconf.h"
	fi
	PNG=1
	while read -r dest url sum; do
		if [ -n "$dest" ]; then fetch "$url" "$sum" "$WORK/gles-headers/$dest"; fi
	done <<< "$KHRONOS_HEADERS"
	GLES_CPPFLAGS="-I$WORK/gles-headers"
fi
# make_unix <dir> <args...>: make all in <dir>/projects/unix, with the tg5050 libpng override
make_unix() {
	local dir=$1; shift
	if [ -n "$PNG" ]; then
		make -C "$dir/projects/unix" -j"$JOBS" all $MK "$@" \
			LIBPNG_CFLAGS="-I$PNG_HEADERS" LIBPNG_LDLIBS="-lpng16 -lz"
	else
		make -C "$dir/projects/unix" -j"$JOBS" all $MK "$@"
	fi
}

# core (netplay). SDL2_net goes in by archive path so no libSDL2_net NEEDED
# appears, ahead of SDL2 as `pkg-config --libs sdl2 SDL2_net` orders it.
make_unix "$WORK/mupen64plus-core" \
	USE_GLES=1 NEON=1 PIE=1 VULKAN=0 NETPLAY=1 OPTFLAGS="-O3" \
	SDL_CFLAGS="-I$NET/include/SDL2 $SDL_C" SDL_LDLIBS="$NET/lib/libSDL2_net.a $SDL_L"

make_unix "$WORK/mupen64plus-ui-console" PIE=1 OPTFLAGS="-O3" \
	SDL_CFLAGS="$SDL_C" SDL_LDLIBS="$SDL_L" APIDIR="$APIDIR" COREDIR="./" PLUGINDIR="./"

make_unix "$WORK/mupen64plus-audio-sdl" PIE=1 OPTFLAGS="-O3" \
	SDL_CFLAGS="$SDL_C" SDL_LDLIBS="$SDL_L -lpthread" APIDIR="$APIDIR"

# Rice: the patch finds the overlay sources five levels above src/, which only
# holds for the old per-platform checkout; point OVERLAY_DIR at this workspace.
make_unix "$WORK/mupen64plus-video-rice" USE_GLES=1 PIC=1 OPTFLAGS="-O3" \
	SDL_CFLAGS="$SDL_C" SDL_LDLIBS="$SDL_L" APIDIR="$APIDIR" \
	OVERLAY_DIR="$WORKSPACE/all/common" CPPFLAGS="$GLES_CPPFLAGS"

make_unix "$WORK/mupen64plus-input-sdl" OPTFLAGS="-O3" \
	SDL_CFLAGS="$SDL_C" SDL_LDLIBS="$SDL_L" APIDIR="$APIDIR"

make_unix "$WORK/mupen64plus-rsp-hle" OPTFLAGS="-O3" APIDIR="$APIDIR"

# sanity: netplay compiled in and SDL2_net linked statically
CORE=$WORK/mupen64plus-core/projects/unix/libmupen64plus.so.2.0.0
if [ "$(strings "$CORE" | grep -c 'Netplay:')" -lt 5 ]; then
	echo "error: $CORE was built without netplay" >&2
	exit 1
fi
if ${CROSS_COMPILE}readelf -d "$CORE" | grep NEEDED | grep -q SDL2_net; then
	echo "error: $CORE links libSDL2_net dynamically" >&2
	exit 1
fi

cp "$CORE" "$OUT/libmupen64plus.so.2"
cp "$WORK/mupen64plus-ui-console/projects/unix/mupen64plus" "$OUT/mupen64plus"
cp "$WORK/mupen64plus-audio-sdl/projects/unix/mupen64plus-audio-sdl.so" "$OUT/"
cp "$WORK/mupen64plus-input-sdl/projects/unix/mupen64plus-input-sdl.so" "$OUT/"
cp "$WORK/mupen64plus-rsp-hle/projects/unix/mupen64plus-rsp-hle.so" "$OUT/"
cp "$WORK/mupen64plus-video-rice/projects/unix/mupen64plus-video-rice.so" "$OUT/"
echo "mupen64plus ($PLATFORM) -> $OUT"
