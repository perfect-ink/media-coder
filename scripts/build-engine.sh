#!/bin/bash
# Rebuildable LGPL-only FFmpeg; no Homebrew libraries or runtime downloads.
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
version=8.1.2
checksum=464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c
work="$root/build/engine"
archive="$work/ffmpeg-$version.tar.xz"
source_dir="$work/ffmpeg-$version"
recipe=$(shasum -a 256 "$0" | cut -d ' ' -f 1)
if [[ -x "$work/universal/ffmpeg" && -f "$work/recipe" && "$(cat "$work/recipe")" == "$recipe" ]]; then exit 0; fi
mkdir -p "$work"
if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 --connect-timeout 15 --max-time 300 "https://ffmpeg.org/releases/ffmpeg-$version.tar.xz" -o "$archive.partial"
    mv "$archive.partial" "$archive"
fi
printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
if [[ ! -d "$source_dir" ]]; then tar -xf "$archive" -C "$work"; fi
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --find clang)
for architecture in arm64 x86_64; do
    mkdir -p "$work/$architecture"
    (
        cd "$work/$architecture"
        "$source_dir/configure" --prefix="$work/$architecture/install" \
            --cc="$compiler" --arch="$architecture" --target-os=darwin --enable-cross-compile \
            --sysroot="$sdk" --extra-cflags="-arch $architecture -mmacosx-version-min=14.0" \
            --extra-ldflags="-arch $architecture -mmacosx-version-min=14.0" \
            --disable-autodetect --disable-gpl --disable-nonfree --disable-version3 \
            --disable-shared --enable-static --disable-x86asm --disable-debug --disable-doc \
            --disable-ffplay --disable-ffprobe --disable-devices --disable-network \
            --disable-protocols --enable-protocol=file,pipe --enable-videotoolbox --enable-audiotoolbox
        make -j "$(sysctl -n hw.activecpu)" ffmpeg
    )
done
mkdir -p "$work/universal" "$work/licenses"
xcrun lipo -create "$work/arm64/ffmpeg" "$work/x86_64/ffmpeg" -output "$work/universal/ffmpeg"
cp "$source_dir/COPYING.LGPLv2.1" "$work/licenses/"
cp "$source_dir/LICENSE.md" "$work/licenses/"
cp "$work/arm64/ffbuild/config.log" "$work/licenses/config-arm64.log"
cp "$work/x86_64/ffbuild/config.log" "$work/licenses/config-x86_64.log"
printf 'FFmpeg %s\nSource: https://ffmpeg.org/releases/ffmpeg-%s.tar.xz\nSHA-256: %s\nBuilt without GPL, nonfree, or external libraries.\n' "$version" "$version" "$checksum" > "$work/licenses/NOTICE.txt"
printf '%s\n' "$recipe" > "$work/recipe"
echo "Built universal engine: $work/universal/ffmpeg"
