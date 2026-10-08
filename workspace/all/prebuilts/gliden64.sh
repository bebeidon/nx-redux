#!/bin/bash
# gliden64.sh: builds the GLideN64 video plugin for standalone mupen64plus
# (mupen64plus-video-GLideN64.so) plus the libpng16.so.16 the tg5050 N64 pak
# links against, from pinned sources. Both land in
# output/$PLATFORM/BASE/Emus/shared/mupen64plus/ and replace what used to be
# committed under skeleton/BASE/Emus/shared/mupen64plus/.
#
# GLideN64 is shared across platforms and built once with the tg5040 toolchain
# (its glibc is the older one, so the result loads on tg5050 too); see
# workspace/all/other/mupen64plus/README.md, "GLideN64-standalone". The plugin
# links libpng 1.6.43 + zlib 1.3.1 statically (src/GLideNHQ/lib/*.a, recreated
# here: the patch only carries content-less placeholders for them) and FreeType +
# bzip2 statically from the sysroot (toolchain-aarch64.cmake in the patch).
#
# libpng16.so.16 is not needed by GLideN64 or by anything on tg5040 (those link
# libpng12); the tg5050 pak binaries (libmupen64plus.so.2, the input/rsp/rice
# plugins) NEED it and launch.sh puts this dir on LD_LIBRARY_PATH.
#
# Runs inside the toolchain container, from the workspace root:
#   docker run --rm -v "$PWD/workspace":/root/workspace \
#     ghcr.io/loveretro/tg5040-toolchain:latest /bin/bash -c \
#     '. ~/.bashrc && cd /root/workspace && PLATFORM=tg5040 bash all/prebuilts/gliden64.sh'
# Idempotent: sources are fetched/verified once into work/gliden64/; delete that
# dir to force a clean rebuild.
set -e

GLIDEN64_REPO=https://github.com/gonetz/GLideN64.git
GLIDEN64_COMMIT=c8ef81c7d9aede9f67f6ed3d3426c90541f9f13e  # keep in sync with workspace/tg5040/Makefile
LIBPNG_VERSION=1.6.43
LIBPNG_URL=https://download.sourceforge.net/libpng/libpng-$LIBPNG_VERSION.tar.gz
LIBPNG_SHA256=e804e465d4b109b5ad285a8fb71f0dd3f74f0068f91ce3cdfde618180c174925
ZLIB_VERSION=1.3.1
ZLIB_URL=https://github.com/madler/zlib/releases/download/v$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz
ZLIB_SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23

PLATFORM=${PLATFORM:-tg5040}
if [ "$PLATFORM" != tg5040 ]; then
	echo "error: GLideN64 is built once with the tg5040 toolchain (got PLATFORM=$PLATFORM)" >&2
	exit 1
fi
: "${CROSS_COMPILE:?run inside the toolchain container after sourcing ~/.bashrc}"
: "${SYSROOT:?run inside the toolchain container after sourcing ~/.bashrc}"

HERE=$(cd "$(dirname "$0")" && pwd)
WORKSPACE=$(cd "$HERE/../.." && pwd)
PATCH=$WORKSPACE/all/other/mupen64plus/GLideN64-standalone.patch
WORK=$HERE/work/gliden64
SRC=$WORK/GLideN64
OUT=$HERE/output/$PLATFORM/BASE/Emus/shared/mupen64plus
JOBS=$(nproc)
mkdir -p "$WORK" "$OUT"

# fetch <url> <sha256> <dest>: downloads once, fails on a checksum mismatch
fetch() {
	if [ ! -f "$3" ]; then
		wget -q -O "$3.part" "$1"
		mv "$3.part" "$3"
	fi
	if ! echo "$2  $3" | sha256sum -c --quiet -; then
		echo "error: sha256 mismatch for $3 (from $1)" >&2
		rm -f "$3"
		exit 1
	fi
}

# 1. zlib 1.3.1, static. The sysroot's static zlib predates 1.2.9 and lacks
#    adler32_z/crc32_z, which the plugin then fails to dlopen without.
fetch "$ZLIB_URL" "$ZLIB_SHA256" "$WORK/zlib-$ZLIB_VERSION.tar.gz"
if [ ! -f "$WORK/zlib-$ZLIB_VERSION/libz.a" ]; then
	rm -rf "$WORK/zlib-$ZLIB_VERSION"
	tar -xzf "$WORK/zlib-$ZLIB_VERSION.tar.gz" -C "$WORK"
	(cd "$WORK/zlib-$ZLIB_VERSION" &&
		CC=${CROSS_COMPILE}gcc CFLAGS="-O3 -fPIC" ./configure --static &&
		make -j"$JOBS" libz.a)
fi

# 2. libpng 1.6.43, static (for the plugin, matching the 1.6 headers in
#    src/GLideNHQ/inc; the sysroot only has 1.2) and shared (libpng16.so.16),
#    against the sysroot's zlib.
fetch "$LIBPNG_URL" "$LIBPNG_SHA256" "$WORK/libpng-$LIBPNG_VERSION.tar.gz"
if [ ! -f "$WORK/libpng-$LIBPNG_VERSION/.libs/libpng16.a" ] ||
	[ ! -f "$WORK/libpng-$LIBPNG_VERSION/.libs/libpng16.so.16" ]; then
	rm -rf "$WORK/libpng-$LIBPNG_VERSION"
	tar -xzf "$WORK/libpng-$LIBPNG_VERSION.tar.gz" -C "$WORK"
	(cd "$WORK/libpng-$LIBPNG_VERSION" &&
		./configure --host=${CROSS_COMPILE%-} --enable-shared --enable-static \
			CC=${CROSS_COMPILE}gcc CFLAGS="-O3 -fPIC --sysroot=$SYSROOT" \
			CPPFLAGS="--sysroot=$SYSROOT" LDFLAGS="--sysroot=$SYSROOT" &&
		make -j"$JOBS" libpng16.la)
fi

# 3. GLideN64 at the pin, with our patch (overlay menu, GLES/EGL toolchain file).
if [ ! -f "$SRC/.nx-patched" ]; then
	rm -rf "$SRC"
	git clone -q "$GLIDEN64_REPO" "$SRC"
	(cd "$SRC" &&
		git checkout -q "$GLIDEN64_COMMIT" &&
		git submodule update --init --recursive &&
		git apply --exclude='src/GLideNHQ/lib/*.a' "$PATCH")
	# The patch finds workspace/all/common five levels above src/, which only
	# holds for the old checkout location; point it at this workspace instead.
	grep -q '^set(OVERLAY_COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../all/common")$' "$SRC/src/CMakeLists.txt"
	sed -i 's|^set(OVERLAY_COMMON_DIR .*|set(OVERLAY_COMMON_DIR "'"$WORKSPACE"'/all/common")|' "$SRC/src/CMakeLists.txt"
	touch "$SRC/.nx-patched"
fi
cp "$WORK/zlib-$ZLIB_VERSION/libz.a" "$SRC/src/GLideNHQ/lib/libz.a"
cp "$WORK/libpng-$LIBPNG_VERSION/.libs/libpng16.a" "$SRC/src/GLideNHQ/lib/libpng.a"
cp "$SYSROOT/usr/lib/libzstd.a" "$SRC/src/GLideNHQ/lib/libzstd.a"

mkdir -p "$SRC/src/build"
(cd "$SRC/src/build" &&
	cmake -DCMAKE_TOOLCHAIN_FILE=../../toolchain-aarch64.cmake \
		-DMUPENPLUSAPI=ON -DEGL=ON -DMESA=ON \
		-DNEON_OPT=ON -DCRC_ARMV8=ON .. &&
	make -j"$JOBS" mupen64plus-video-GLideN64)

SO=$SRC/src/build/plugin/Release/mupen64plus-video-GLideN64.so
# A stale zlib would leave adler32_z/crc32_z undefined and break dlopen.
if ${CROSS_COMPILE}nm -D --undefined-only "$SO" | grep -E ' U (adler32|crc32)'; then
	echo "error: $SO has undefined zlib symbols" >&2
	exit 1
fi
cp "$SO" "$OUT/mupen64plus-video-GLideN64.so"
cp -L "$WORK/libpng-$LIBPNG_VERSION/.libs/libpng16.so.16" "$OUT/libpng16.so.16"
echo "gliden64: built $OUT/{mupen64plus-video-GLideN64.so,libpng16.so.16}"
