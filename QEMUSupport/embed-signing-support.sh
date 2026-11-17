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
#
#  Build phase of the framework.
#
#  Ships resign-embedded-helper.sh and the entitlements it applies inside the
#  framework, in Resources/QEMUSupport. A host application then runs the copy
#  embedded in its own bundle, wherever the framework came from: a project
#  dependency, a release, or a checkout somewhere else on the disk.

set -eu

DESTINATION="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/QEMUSupport"
mkdir -p "${DESTINATION}"

for FILE in resign-embedded-helper.sh QEMUHelper.entitlements QEMULauncher.entitlements QEMUTPM.entitlements; do
    cp -f "${SRCROOT}/QEMUSupport/${FILE}" "${DESTINATION}/${FILE}"
done

chmod 755 "${DESTINATION}/resign-embedded-helper.sh"
