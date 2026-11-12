#!/bin/bash
#
#  Copyright 2026 Giuseppe Rocco
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
#
#  Builds the emulator payload of the QEMU backend:
#
#      Third-Party/QEMU/lib/libqemu-<target>-softmmu.dylib
#      Third-Party/QEMU/share/qemu/<firmware, option ROMs, keymaps>
#
#  which the helper service target embeds through
#  QEMUSupport/embed-qemu-payload.sh.
#
#  The emulator is UTM's QEMU fork, the only one that builds as a shared
#  library. Its dependencies (pcre2, libffi, glib, pixman, libslirp) are built
#  as static libraries into a private prefix and linked into the emulator
#  libraries, which therefore depend on nothing outside of macOS.
#
#  Requirements: Xcode command line tools, meson, ninja, pkg-config, python3.
#  Apple silicon host. Run from anywhere:
#
#      Third-Party/setup-dependencies.sh [--clean]
#
#  Environment: JOBS (parallel jobs, default: number of cores).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# shellcheck source=functions.sh
. "${SCRIPT_DIR}/functions.sh"

# Versions and SHA-256 digests. Update both together.
PCRE2_URL="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.bz2"
PCRE2_SHA256="d34f02e113cf7193a1ebf2770d3ac527088d485d4e047ed10e5d217c6ef5de96"

LIBFFI_URL="https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz"
LIBFFI_SHA256="b0dea9df23c863a7a50e825440f3ebffabd65df1497108e5d437747843895a4e"

GLIB_URL="https://download.gnome.org/sources/glib/2.82/glib-2.82.4.tar.xz"
GLIB_SHA256="37dd0877fe964cd15e9a2710b044a1830fb1bd93652a6d0cb6b8b2dff187c709"

PIXMAN_URL="https://cairographics.org/releases/pixman-0.44.2.tar.gz"
PIXMAN_SHA256="6349061ce1a338ab6952b92194d1b0377472244208d47ff25bef86fc71973466"

# A generated archive: its digest can change if the forge regenerates it.
SLIRP_URL="https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.8.0/libslirp-v4.8.0.tar.gz"
SLIRP_SHA256="2a98852e65666db313481943e7a1997abff0183bd9bea80caec1b5da89fda28c"

QEMU_URL="https://github.com/utmapp/qemu/releases/download/v10.0.12-utm/qemu-10.0.12-utm.tar.xz"
QEMU_SHA256="7c9605290b34152debb842e965a55d2e4fbba4793e536ab677b4027e5dc0ba1a"

QEMU_TARGETS="aarch64-softmmu,x86_64-softmmu"

# Layout.
DOWNLOADS="${SCRIPT_DIR}/downloads"
BUILD="${SCRIPT_DIR}/build"
DEPS_PREFIX="${SCRIPT_DIR}/deps"
OUTPUT="${SCRIPT_DIR}/QEMU"

HOST_TRIPLE="aarch64-apple-darwin"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

export DEPS_PREFIX HOST_TRIPLE JOBS
export MACOSX_DEPLOYMENT_TARGET=14.0
export CFLAGS="-arch arm64 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -O2"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="-arch arm64 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
export PKG_CONFIG_PATH="${DEPS_PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"
export PATH="${BUILD}/tools:${DEPS_PREFIX}/bin:${PATH}"

if [ "${1:-}" = "--clean" ]; then
    log "Removing previous build products"
    rm -rf "${BUILD}" "${DEPS_PREFIX}" "${OUTPUT}"
fi

[ "$(uname -s)" = "Darwin" ] || die "this script runs on macOS only"
[ "$(uname -m)" = "arm64" ] || die "this script runs on Apple silicon only"

require_tool xcrun "install the Xcode command line tools"
require_tool curl "part of macOS"
require_tool shasum "part of macOS"
require_tool meson "brew install meson"
require_tool ninja "brew install ninja"
require_tool pkg-config "brew install pkg-config"
require_tool python3 "install the Xcode command line tools"

mkdir -p "${DOWNLOADS}" "${BUILD}" "${DEPS_PREFIX}"
make_static_pkg_config "${BUILD}/tools"

fetch "${PCRE2_URL}" "${DOWNLOADS}/pcre2.tar.bz2" "${PCRE2_SHA256}"
fetch "${LIBFFI_URL}" "${DOWNLOADS}/libffi.tar.gz" "${LIBFFI_SHA256}"
fetch "${GLIB_URL}" "${DOWNLOADS}/glib.tar.xz" "${GLIB_SHA256}"
fetch "${PIXMAN_URL}" "${DOWNLOADS}/pixman.tar.gz" "${PIXMAN_SHA256}"
fetch "${SLIRP_URL}" "${DOWNLOADS}/libslirp.tar.gz" "${SLIRP_SHA256}"
fetch "${QEMU_URL}" "${DOWNLOADS}/qemu.tar.xz" "${QEMU_SHA256}"

log "Building pcre2"
unpack "${DOWNLOADS}/pcre2.tar.bz2" "${BUILD}/pcre2"
build_autotools "${BUILD}/pcre2" --enable-pcre2-8 --disable-pcre2-16 --disable-pcre2-32 --enable-jit

log "Building libffi"
unpack "${DOWNLOADS}/libffi.tar.gz" "${BUILD}/libffi"
build_autotools "${BUILD}/libffi" --disable-docs --disable-multi-os-directory

log "Building glib"
unpack "${DOWNLOADS}/glib.tar.xz" "${BUILD}/glib"

# libintl is not part of macOS. With translations disabled glib falls back to
# its proxy-libintl subproject, which meson fetches with git.
build_meson "${BUILD}/glib" \
    -Dtests=false \
    -Dnls=disabled \
    -Dintrospection=disabled \
    -Ddocumentation=false \
    -Dman-pages=disabled \
    -Dsysprof=disabled \
    -Dlibelf=disabled \
    -Ddtrace=disabled \
    -Dsystemtap=disabled \
    -Dglib_debug=disabled \
    -Dxattr=false \
    -Dselinux=disabled \
    -Dlibmount=disabled

log "Building pixman"
unpack "${DOWNLOADS}/pixman.tar.gz" "${BUILD}/pixman"
build_meson "${BUILD}/pixman" -Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dlibpng=disabled

log "Building libslirp"
unpack "${DOWNLOADS}/libslirp.tar.gz" "${BUILD}/libslirp"
build_meson "${BUILD}/libslirp"

log "Building QEMU (${QEMU_TARGETS})"
unpack "${DOWNLOADS}/qemu.tar.xz" "${BUILD}/qemu"
rm -rf "${OUTPUT}"

(
    mkdir -p "${BUILD}/qemu/build"
    cd "${BUILD}/qemu/build"

    ../configure \
        --prefix="${OUTPUT}" \
        --cpu=aarch64 \
        --target-list="${QEMU_TARGETS}" \
        --enable-shared-lib \
        --disable-cocoa \
        --disable-sdl \
        --disable-gtk \
        --disable-docs \
        --enable-hvf \
        --enable-slirp \
        --enable-vnc \
        --enable-coreaudio \
        --extra-cflags="-I${DEPS_PREFIX}/include" \
        --extra-ldflags="-L${DEPS_PREFIX}/lib"

    make -j "${JOBS}"
    make install
)

log "Fixing install names"
for LIBRARY in "${OUTPUT}"/lib/libqemu-*-softmmu.dylib; do
    [ -f "${LIBRARY}" ] || die "the emulator libraries were not installed"

    # Loaded by path from the service's Contents/Frameworks; the install name
    # only has to be relocatable.
    install_name_tool -id "@rpath/$(basename "${LIBRARY}")" "${LIBRARY}"
    check_system_dependencies_only "${LIBRARY}"
done

[ -d "${OUTPUT}/share/qemu" ] || die "the emulator data files were not installed"

log "Done: ${OUTPUT}"
