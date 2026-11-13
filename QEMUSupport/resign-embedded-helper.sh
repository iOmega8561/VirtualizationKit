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
#  Build phase for host applications that embed the framework.
#
#  The framework carries the QEMU helper service, which in turn carries the
#  launcher and the emulator libraries. When the framework is copied into an
#  application, that nested code keeps whatever signature it came with: a
#  foreign team, an ad hoc signature, or none. App Store validation and the
#  sandbox both reject that, and a plain re-sign of the framework (or a --deep
#  one) drops the entitlements the helper and the launcher depend on.
#
#  This script re-signs the nested code inside-out with the application's
#  identity, each component with its own entitlements:
#
#      1. the emulator libraries        (no entitlements)
#      2. the software TPM, if present   (QEMUTPM.entitlements)
#         and the launcher              (QEMULauncher.entitlements)
#      3. the helper service bundle     (QEMUHelper.entitlements)
#      4. the framework itself          (no entitlements, no --deep)
#
#  Add it as a "Run Script" phase of the application target, after the phase
#  that embeds the framework:
#
#      "${SRCROOT}/<path to the framework checkout>/QEMUSupport/resign-embedded-helper.sh"
#
#  The entitlements files are looked up next to this script. With user script
#  sandboxing enabled, declare the embedded framework as an input and output of
#  the phase, or disable sandboxing for it.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LAUNCHER_ENTITLEMENTS="${SCRIPT_DIR}/QEMULauncher.entitlements"
TPM_ENTITLEMENTS="${SCRIPT_DIR}/QEMUTPM.entitlements"
HELPER_ENTITLEMENTS="${SCRIPT_DIR}/QEMUHelper.entitlements"

if [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ]; then
    echo "note: code signing is disabled; nothing to re-sign"
    exit 0
fi

IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"

if [ -z "${IDENTITY}" ]; then
    # "Sign to Run Locally" leaves the expanded identity empty.
    IDENTITY="-"
fi

for FILE in "${LAUNCHER_ENTITLEMENTS}" "${HELPER_ENTITLEMENTS}" "${TPM_ENTITLEMENTS}"; do
    [ -f "${FILE}" ] || { echo "error: missing ${FILE}"; exit 1; }
done

# A secure timestamp only for archives with a real identity; it needs network
# access and is pointless for local builds.
if [ "${IDENTITY}" != "-" ] && [ "${ACTION:-build}" = "install" ]; then
    TIMESTAMP="--timestamp"
else
    TIMESTAMP="--timestamp=none"
fi

sign() {
    /usr/bin/codesign --force --options runtime "${TIMESTAMP}" --sign "${IDENTITY}" "$@"
}

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
FOUND=0

for FRAMEWORK in "${FRAMEWORKS_DIR}"/*.framework; do

    [ -d "${FRAMEWORK}" ] || continue

    HELPER="${FRAMEWORK}/Versions/Current/XPCServices/QEMUHelper.xpc"
    [ -d "${HELPER}" ] || HELPER="${FRAMEWORK}/XPCServices/QEMUHelper.xpc"
    [ -d "${HELPER}" ] || continue

    FOUND=1
    echo "Re-signing the QEMU helper of $(basename "${FRAMEWORK}") with ${IDENTITY}"

    if [ -d "${HELPER}/Contents/Frameworks" ]; then
        find "${HELPER}/Contents/Frameworks" -type f -name '*.dylib' -print0 \
            | while IFS= read -r -d '' LIBRARY; do
                sign "${LIBRARY}"
            done
    fi

    # The software TPM, present when the payload was built with it.
    TPM="${HELPER}/Contents/MacOS/QEMUTPM"

    if [ -f "${TPM}" ]; then
        sign --entitlements "${TPM_ENTITLEMENTS}" "${TPM}"
    fi

    LAUNCHER="${HELPER}/Contents/MacOS/QEMULauncher"

    if [ -f "${LAUNCHER}" ]; then
        sign --entitlements "${LAUNCHER_ENTITLEMENTS}" "${LAUNCHER}"
    else
        echo "warning: no launcher in ${HELPER}"
    fi

    sign --entitlements "${HELPER_ENTITLEMENTS}" "${HELPER}"

    # The framework's seal covers the helper, so it is signed last, and
    # without --deep, which would replace the entitlements set above.
    sign "${FRAMEWORK}"
done

# A host that runs this phase embeds the framework on purpose. Finding nothing
# means the phase ran before the framework was embedded, or user script
# sandboxing hid the build products from it; either way the application would
# be unusable, so the build fails here rather than at the first start.
if [ "${FOUND}" -eq 0 ]; then
    echo "error: no embedded framework with a QEMU helper in ${FRAMEWORKS_DIR}."
    echo "error: Run this phase after \"Embed Frameworks\" and set ENABLE_USER_SCRIPT_SANDBOXING = NO for the target."
    exit 1
fi
