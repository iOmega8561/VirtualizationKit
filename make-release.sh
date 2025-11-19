#!/bin/bash
#
#  Copyright 2025 Giuseppe Rocco
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
# Absolute path to this script.
SCRIPT=$(readlink -f $0)
# Absolute path this script is in.
SCRIPTPATH=`dirname $SCRIPT`

# Exit on error
set -e

# Check if an archive path is provided
if [ "$#" -ne 1 ]; then
    echo "❌ Error: No archive path provided."
    echo "Usage: $0 <path-to-archive>"
    exit 1
fi

ARCHIVE_PATH="$1"

# Check if the given archive exists
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Error: The archive path '$ARCHIVE_PATH' does not exist."
    exit 1
fi

# Fetching environment variables
source "${SCRIPTPATH}/.env"

if [[ -z "${FRAMEWORK_NAME}" || \
      -z "${APPLE_ID}" || \
      -z "${TEAM_ID}"  || \
      -z "${DEV_NAME}" || \
      -z "${KEYCHAIN_PROFILE}" ]]; then
    echo "❌ Error: Some environment variables are not set."
    exit 1
fi

# To store credentials in the system keychain
# This should be already done before running the script
# xcrun notarytool store-credentials "notarytool-profile" \
#     --apple-id "${APPLE_ID}" \
#     --team-id "${TEAM_ID}" \
#     --password "${APP_PASSWORD}"

CERTIFICATE_NAME="Developer ID Application: ${DEV_NAME} (${TEAM_ID})"

# Cleanup old builds
rm -rf "${FRAMEWORK_NAME}.xcframework" \
    "${FRAMEWORK_NAME}.dmg" \
    DMG

echo "🛠 ️ Creating XCFramework..."
xcodebuild -create-xcframework \
    -archive "${ARCHIVE_PATH}" \
    -framework "${FRAMEWORK_NAME}.framework" \
    -output "./${FRAMEWORK_NAME}.xcframework"

echo "🔑 Signing XCFramework..."
find "${FRAMEWORK_NAME}.xcframework" -type f -perm +111 -exec \
codesign --force --strict --options runtime --timestamp \
--sign "$CERTIFICATE_NAME" {} \; > /dev/null 2>&1

codesign --force \
    --deep \
    --strict \
    --options runtime \
    --timestamp \
    --sign "$CERTIFICATE_NAME" \
    "${FRAMEWORK_NAME}.xcframework"

echo "📦 Packaging XCFramework..."
mkdir -p DMG
cp -R "${FRAMEWORK_NAME}.xcframework" DMG/
cp "${SCRIPTPATH}/LICENSE" DMG/

hdiutil create -volname "${FRAMEWORK_NAME}" \
  -srcfolder ./DMG \
  -format UDZO \
  -ov "./${FRAMEWORK_NAME}.dmg"

echo "🔑 Signing DMG Package..."
codesign \
    --force \
    --sign "$CERTIFICATE_NAME" \
    "${FRAMEWORK_NAME}.dmg"

echo "📤 Submitting for Notarization..."
xcrun notarytool submit "${FRAMEWORK_NAME}.dmg" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "📎 Stapling Notarization..."
xcrun stapler staple "${FRAMEWORK_NAME}.dmg"

rm -fr DMG
rm -fr "${FRAMEWORK_NAME}.xcframework"

echo "✅ Done! XCFramework is notarized and ready for distribution."
