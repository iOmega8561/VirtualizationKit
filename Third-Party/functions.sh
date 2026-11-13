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
#  Helpers sourced by setup-dependencies.sh. Not meant to be run directly.

# Prints a progress line.
log() {
    printf '==> %s\n' "$*"
}

# Prints an error and stops.
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

# Stops unless a command is available.
#   $1  the command
#   $2  a hint on how to obtain it
require_tool() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required ($2)"
}

# Downloads a file once and verifies its SHA-256 digest.
#   $1  URL
#   $2  destination file
#   $3  expected digest
fetch() {
    local url="$1" file="$2" digest="$3"

    if [ -f "${file}" ] && echo "${digest}  ${file}" | shasum -a 256 -c - >/dev/null 2>&1; then
        return 0
    fi

    log "Downloading $(basename "${file}")"
    rm -f "${file}.partial"
    curl --fail --location --retry 3 --output "${file}.partial" "${url}"

    if ! echo "${digest}  ${file}.partial" | shasum -a 256 -c - >/dev/null 2>&1; then
        rm -f "${file}.partial"
        die "checksum mismatch for ${url}"
    fi

    mv "${file}.partial" "${file}"
}

# Unpacks an archive into an empty directory, dropping its top-level folder.
#   $1  archive
#   $2  destination directory
unpack() {
    local archive="$1" destination="$2"

    rm -rf "${destination}"
    mkdir -p "${destination}"
    tar -xf "${archive}" -C "${destination}" --strip-components 1
}

# Builds and installs a static autotools package.
#   $1  source directory
#   $@  extra configure arguments
build_autotools() {
    local source="$1"
    shift

    (
        cd "${source}" || exit 1
        ./configure \
            --prefix="${DEPS_PREFIX}" \
            --host="${HOST_TRIPLE}" \
            --enable-static \
            --disable-shared \
            "$@"
        make -j "${JOBS}"
        make install
    )
}

# Builds and installs a static meson package.
#   $1  source directory
#   $@  extra meson arguments
build_meson() {
    local source="$1"
    shift

    meson setup "${source}/build" "${source}" \
        --prefix="${DEPS_PREFIX}" \
        --libdir=lib \
        --buildtype=release \
        --default-library=static \
        --wipe \
        "$@"
    meson compile -C "${source}/build"
    meson install -C "${source}/build"
}

# Writes a pkg-config wrapper that always asks for static link flags.
#
# The dependencies are only available as static libraries, so their private
# dependencies (frameworks, iconv, ...) have to be linked as well. QEMU's
# build system has no switch for that; the wrapper supplies it.
#   $1  directory to write the wrapper to
make_static_pkg_config() {
    local directory="$1"

    mkdir -p "${directory}"
    cat > "${directory}/pkg-config" <<WRAPPER
#!/bin/sh
exec "$(command -v pkg-config)" --static "\$@"
WRAPPER
    chmod +x "${directory}/pkg-config"
}

# Makes the libffi that ships with macOS visible to pkg-config.
#
# Building libffi from source is fragile: its hand-written arm64 assembly
# carries call-frame directives that newer Xcode assemblers reject ("invalid
# CFI advance_loc expression"). macOS has a libffi of its own, with headers in
# the SDK, which is also what package managers build glib against. It only
# lacks a pkg-config file, which is written here. The emulator libraries then
# link /usr/lib/libffi.dylib, a system library.
use_system_libffi() {
    local sdk header_dir

    sdk=$(xcrun --sdk macosx --show-sdk-path) || die "no macOS SDK found"
    header_dir="${sdk}/usr/include/ffi"

    [ -f "${header_dir}/ffi.h" ] || die "the macOS SDK has no libffi headers at ${header_dir}"

    mkdir -p "${DEPS_PREFIX}/lib/pkgconfig"
    cat > "${DEPS_PREFIX}/lib/pkgconfig/libffi.pc" <<PC
# libffi of the macOS SDK. The SDK states no version; glib needs 3.0 or later.
Name: libffi
Description: Foreign function interface library (macOS system copy)
Version: 3.0.0
Cflags: -I${header_dir}
Libs: -lffi
PC
}

# Regenerates the build system of a source tree that ships without one, as the
# archives of git tags do. Needs autoconf, automake and libtool; on macOS
# Homebrew installs libtoolize as glibtoolize.
#   $1  source directory
autoreconf_source() {
    (
        cd "$1" || exit 1

        if command -v glibtoolize >/dev/null 2>&1; then
            export LIBTOOLIZE=glibtoolize
        fi

        autoreconf --force --install
    )
}

# Builds the software TPM and what it needs, all static, into DEPS_PREFIX:
# libcrypto (OpenSSL), libtpms, libtasn1, json-glib and swtpm itself. glib must
# already be there.
#   $1  OpenSSL configuration target (darwin64-arm64-cc on Apple silicon)
#   $2  directory holding the downloaded archives
build_tpm_stack() {
    local openssl_target="$1" downloads="$2"

    log "Building OpenSSL (libcrypto only)"
    unpack "${downloads}/openssl.tar.gz" "${BUILD}/openssl"
    (
        cd "${BUILD}/openssl" || exit 1
        ./Configure "${openssl_target}" no-shared no-tests no-docs \
            --prefix="${DEPS_PREFIX}" --libdir=lib
        make -j "${JOBS}" build_libs
        make install_dev
    )

    # The packages below find libcrypto through the compiler, not pkg-config.
    local CPPFLAGS="-I${DEPS_PREFIX}/include"
    local LDFLAGS="${LDFLAGS:-} -L${DEPS_PREFIX}/lib"
    export CPPFLAGS LDFLAGS

    log "Building libtpms"
    unpack "${downloads}/libtpms.tar.gz" "${BUILD}/libtpms"
    autoreconf_source "${BUILD}/libtpms"
    build_autotools "${BUILD}/libtpms" --with-openssl --with-tpm2 --disable-hardening

    log "Building libtasn1"
    unpack "${downloads}/libtasn1.tar.gz" "${BUILD}/libtasn1"
    build_autotools "${BUILD}/libtasn1" --disable-doc

    log "Building json-glib"
    unpack "${downloads}/json-glib.tar.xz" "${BUILD}/json-glib"
    build_meson "${BUILD}/json-glib" \
        -Dintrospection=disabled -Ddocumentation=disabled -Dgtk_doc=disabled \
        -Dman=false -Dtests=false -Dconformance=false -Dnls=disabled -Dinstalled_tests=false

    log "Building swtpm"
    unpack "${downloads}/swtpm.tar.gz" "${BUILD}/swtpm"
    autoreconf_source "${BUILD}/swtpm"
    # Only the TPM itself is needed; the provisioning tools next to it pull in
    # further libraries (GMP, GnuTLS) for nothing.
    (
        cd "${BUILD}/swtpm" || exit 1
        ./configure \
            --prefix="${DEPS_PREFIX}" \
            --host="${HOST_TRIPLE}" \
            --enable-static \
            --disable-shared \
            --with-openssl --without-gnutls --without-seccomp --without-cuse \
            --disable-tests --disable-hardening
        make -j "${JOBS}" -C src/utils
        make -j "${JOBS}" -C src/swtpm
        make -C src/swtpm install
    )

    [ -x "${DEPS_PREFIX}/bin/swtpm" ] || die "swtpm was not installed"
}

# Stops if a library links against anything outside of the operating system.
#   $1  the library
check_system_dependencies_only() {
    local library="$1" foreign

    foreign=$(otool -L "${library}" | tail -n +2 | awk '{print $1}' \
        | grep -v -e '^/usr/lib/' -e '^/System/Library/' -e '^@rpath/libqemu-' || true)

    [ -z "${foreign}" ] || die "$(basename "${library}") links non-system libraries: ${foreign}"
}
