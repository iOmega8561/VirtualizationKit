#!/bin/sh
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
#  Build phase of the helper service target.
#
#  Copies the emulator libraries and data files produced by
#  Third-Party/setup-dependencies.sh into the service bundle:
#
#      Contents/Frameworks/libqemu-<target>-softmmu.dylib
#      Contents/Resources/qemu/<firmware, option ROMs, keymaps>
#
#  The service still builds when the payload has not been produced yet, so the
#  rest of the project can be worked on without it. A machine created with the
#  QEMU backend then fails with a "component is missing" error.

set -e

PAYLOAD_DIR="${QEMU_PAYLOAD_DIR:-${SRCROOT}/Third-Party/QEMU}"
BUNDLE_DIR="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}"
LIBRARY_DIR="${BUNDLE_DIR}/Frameworks"
DATA_DIR="${BUNDLE_DIR}/Resources/qemu"

if [ ! -d "${PAYLOAD_DIR}/lib" ]; then
    echo "warning: no emulator payload at ${PAYLOAD_DIR}; run Third-Party/setup-dependencies.sh"
    exit 0
fi

mkdir -p "${LIBRARY_DIR}" "${DATA_DIR}"

for LIBRARY in "${PAYLOAD_DIR}"/lib/libqemu-*-softmmu.dylib; do

    [ -f "${LIBRARY}" ] || continue

    NAME=$(basename "${LIBRARY}")
    cp -f "${LIBRARY}" "${LIBRARY_DIR}/${NAME}"
    chmod u+w "${LIBRARY_DIR}/${NAME}"

    # Nested code is signed before the bundle that contains it. Without an
    # identity (the default of this project) signing is left to the embedder.
    if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" ]; then
        codesign --force --options runtime \
            --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
            "${LIBRARY_DIR}/${NAME}"
    fi
done

if [ -d "${PAYLOAD_DIR}/share/qemu" ]; then
    rsync -a --delete "${PAYLOAD_DIR}/share/qemu/" "${DATA_DIR}/"
fi

# The software TPM, started by the launcher next to the emulator. It lives in
# Contents/MacOS beside the launcher, which looks for it there. It needs its own
# entitlements (sandbox inheritance), which the embedder's re-sign phase applies.
if [ -x "${PAYLOAD_DIR}/bin/swtpm" ]; then
    TPM="${BUNDLE_DIR}/MacOS/QEMUTPM"
    mkdir -p "${BUNDLE_DIR}/MacOS"
    cp -f "${PAYLOAD_DIR}/bin/swtpm" "${TPM}"
    chmod u+w "${TPM}"

    if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" ]; then
        codesign --force --options runtime \
            --entitlements "${SRCROOT}/QEMUSupport/QEMUTPM.entitlements" \
            --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
            "${TPM}"
    fi
fi
