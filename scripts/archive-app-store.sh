#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple Developer team ID}"
: "${PRODUCT_BUNDLE_IDENTIFIER:?Set PRODUCT_BUNDLE_IDENTIFIER to your registered bundle ID}"
xcodegen generate
xcodebuild -project MediaCoder.xcodeproj -scheme MediaCoder -configuration Release \
    -destination 'generic/platform=macOS' -archivePath build/MediaCoder.xcarchive \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" PRODUCT_BUNDLE_IDENTIFIER="$PRODUCT_BUNDLE_IDENTIFIER" \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO archive
codesign --verify --deep --strict build/MediaCoder.xcarchive/Products/Applications/MediaCoder.app
