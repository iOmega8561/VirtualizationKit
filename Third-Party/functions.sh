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

# Stops if a library links against anything outside of the operating system.
#   $1  the library
check_system_dependencies_only() {
    local library="$1" foreign

    foreign=$(otool -L "${library}" | tail -n +2 | awk '{print $1}' \
        | grep -v -e '^/usr/lib/' -e '^/System/Library/' -e '^@rpath/libqemu-' || true)

    [ -z "${foreign}" ] || die "$(basename "${library}") links non-system libraries: ${foreign}"
}
