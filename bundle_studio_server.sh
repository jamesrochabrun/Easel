#!/bin/bash

# Bundle EaselMCPServer into the app.
# Called during the Xcode build phase, after "Bundle ApprovalMCPServer".
# Unlike bundle_server.sh this builds a *local* package (Packages/EaselMCPServer),
# so there is no SourcePackages checkout hunt — but the package has a path
# dependency on ../EaselStudio, so both are copied into TARGET_TEMP_DIR
# preserving that relative layout before building (keeps the repo's .build
# untouched and survives archive builds with a custom -derivedDataPath).

set -e

echo "Starting to bundle EaselMCPServer..."

PRODUCT_NAME_IN_PACKAGE="EaselMCPServer"
SERVER_NAME="EaselMCPServer"
BUILD_DIR="${BUILT_PRODUCTS_DIR}"
APP_CONTENTS="${BUILD_DIR}/${PRODUCT_NAME}.app/Contents"
RESOURCES_DIR="${APP_CONTENTS}/Resources"
SERVER_DEST="${RESOURCES_DIR}/${SERVER_NAME}"

mkdir -p "${RESOURCES_DIR}"

SERVER_PACKAGE_DIR="${SRCROOT}/Packages/EaselMCPServer"
STUDIO_PACKAGE_DIR="${SRCROOT}/Packages/EaselStudio"

for dir in "${SERVER_PACKAGE_DIR}" "${STUDIO_PACKAGE_DIR}"; do
  if [ ! -d "${dir}" ]; then
    echo "Error: expected package at ${dir}"
    exit 1
  fi
done

BUILD_ROOT_DIR="${TARGET_TEMP_DIR}/StudioServerBuild"
rm -rf "${BUILD_ROOT_DIR}"
mkdir -p "${BUILD_ROOT_DIR}"
rsync -a --exclude .build "${SERVER_PACKAGE_DIR}/" "${BUILD_ROOT_DIR}/EaselMCPServer/"
rsync -a --exclude .build "${STUDIO_PACKAGE_DIR}/" "${BUILD_ROOT_DIR}/EaselStudio/"

cd "${BUILD_ROOT_DIR}/EaselMCPServer"
swift build -c release --product "${PRODUCT_NAME_IN_PACKAGE}"

SERVER_SOURCE="${BUILD_ROOT_DIR}/EaselMCPServer/.build/release/${PRODUCT_NAME_IN_PACKAGE}"

if [ ! -f "${SERVER_SOURCE}" ]; then
    echo "Error: Failed to build EaselMCPServer"
    exit 1
fi

echo "Found server at: ${SERVER_SOURCE}"

cp "${SERVER_SOURCE}" "${SERVER_DEST}"
chmod +x "${SERVER_DEST}"

# Sign with hardened runtime and entitlements (if signing identity exists)
if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" ] && [ "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]; then
    echo "Signing ${SERVER_NAME} with hardened runtime..."
    ENTITLEMENTS_PATH="${SRCROOT}/Easel/Easel.entitlements"
    if [ -f "${ENTITLEMENTS_PATH}" ]; then
        codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
          --options runtime \
          --entitlements "${ENTITLEMENTS_PATH}" \
          --timestamp \
          "${SERVER_DEST}"
    else
        codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
          --options runtime \
          --timestamp \
          "${SERVER_DEST}"
    fi
    echo "Successfully signed ${SERVER_NAME}"
else
    echo "Skipping signing (no code sign identity)"
fi

echo "Successfully bundled EaselMCPServer to ${SERVER_DEST}"

if [ -f "${SERVER_DEST}" ]; then
    echo "Verification: Server successfully copied to app bundle"
    ls -la "${SERVER_DEST}"
else
    echo "Error: Failed to copy server to app bundle"
    exit 1
fi

exit 0
