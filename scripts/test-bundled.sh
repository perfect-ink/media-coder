#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-engine.sh
app="$PWD/build/BundledIntegration.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.perfectink.mediacoder.BundledIntegration</string>
<key>CFBundleExecutable</key><string>BundledIntegration</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
# Homebrew generates a fixture only; the signed test app uses its embedded engine.
/opt/homebrew/bin/ffmpeg -v error -y -f lavfi -i testsrc2=size=160x120:rate=25 \
    -f lavfi -i sine=frequency=440 -t 0.3 -c:v mpeg4 -c:a pcm_s16le "$app/Contents/Resources/fixture.avi"
swiftc -parse-as-library Sources/MediaCoder/ConversionEngine.swift Sources/MediaCoder/CodecSupport.swift \
    Tests/BundledIntegration.swift -o "$app/Contents/MacOS/BundledIntegration"
cp build/engine/universal/ffmpeg "$app/Contents/Helpers/ffmpeg"
codesign --force --sign - --identifier org.perfectink.mediacoder.BundledIntegration.ffmpeg \
    --options runtime --entitlements Configuration/Engine.entitlements "$app/Contents/Helpers/ffmpeg"
codesign --force --sign - --options runtime --entitlements Configuration/MediaCoder.entitlements "$app"
codesign --verify --deep --strict "$app"
"$app/Contents/MacOS/BundledIntegration"
