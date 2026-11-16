#!/bin/bash
set -euo pipefail
cd "${SRCROOT:?}"
./scripts/build-engine.sh
helper="${TARGET_BUILD_DIR:?}/${CONTENTS_FOLDER_PATH:?}/Helpers/ffmpeg"
notices="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}/FFmpeg"
mkdir -p "$(dirname "$helper")" "$notices"
cp build/engine/universal/ffmpeg "$helper"
chmod 755 "$helper"
cp build/engine/licenses/* "$notices/"
# Keep the exact source archive and recipe beside the shipped LGPL executable.
cp build/engine/ffmpeg-8.1.2.tar.xz "$notices/"
cp scripts/build-engine.sh "$notices/"
identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
[[ -n "$identity" ]] || identity=-
codesign --force --sign "$identity" --identifier "${PRODUCT_BUNDLE_IDENTIFIER:?}.ffmpeg" --options runtime --entitlements Configuration/Engine.entitlements "$helper"
./scripts/verify-engine.sh "$helper"
