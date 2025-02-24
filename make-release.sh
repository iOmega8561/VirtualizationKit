#!/bin/bash
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

# Variables
FRAMEWORK_NAME="VirtualizationKit"
APPLE_ID="giusepperocco38@gmail.com"
TEAM_ID="T8HX5554JX"
KEYCHAIN_PROFILE="notarytool"
CERTIFICATE_NAME="Developer ID Application: GIUSEPPE ROCCO (${TEAM_ID})"

# Cleanup old builds
rm -rf ${ZIP_FILE}

# To store credentials in the system keychain
# This should be already done before running the script
# xcrun notarytool store-credentials "notarytool-profile" \
#     --apple-id "${APPLE_ID}" \
#     --team-id "${TEAM_ID}" \
#     --password "${APP_PASSWORD}"

echo "🛠️ Creating XCFramework..."
xcodebuild -create-xcframework \
    -archive "${ARCHIVE_PATH}" \
    -framework "${FRAMEWORK_NAME}.framework" \
    -output "./${FRAMEWORK_NAME}.xcframework"

echo "🔑 Signing XCFramework..."
codesign --force --deep --sign "$CERTIFICATE_NAME" "${FRAMEWORK_NAME}.xcframework"

echo "📦 Zipping XCFramework..."
zip -r "${FRAMEWORK_NAME}.zip" "${FRAMEWORK_NAME}.xcframework"
zip -j "${FRAMEWORK_NAME}.zip" "${SCRIPTPATH}/LICENSE"

echo "📤 Submitting for Notarization..."
xcrun notarytool submit "${FRAMEWORK_NAME}.zip" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "📎 Stapling Notarization..."
xcrun stapler staple "${FRAMEWORK_NAME}.zip"

rm "${FRAMEWORK_NAME}.xcframework"

echo "✅ Done! XCFramework is notarized and ready for distribution."
