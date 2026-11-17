#!/bin/bash
set -euo pipefail
engine="${1:?Usage: verify-engine.sh /path/to/ffmpeg}"
for architecture in arm64 x86_64; do
    xcrun lipo "$engine" -verify_arch "$architecture"
done
# Reject accidental dependencies on the build machine or unsigned bundled dylibs.
if otool -arch all -L "$engine" | awk '/^[[:space:]]/ {print $1}' | grep -Ev '^(/usr/lib/|/System/Library/)' ; then
    echo 'Engine has a non-system dynamic dependency.' >&2; exit 1
fi
# Inspect embedded configuration strings without launching an inheritance-only helper
# outside its sandboxed parent. Runtime capability checks live in test-bundled.sh.
configuration=$(strings -a "$engine" | grep -- '--disable-autodetect')
if grep -Eq -- '--enable-(gpl|nonfree|version3)' <<< "$configuration"; then
    echo 'Engine enables GPL/nonfree/version3 components.' >&2; exit 1
fi
codesign --verify --strict "$engine"
echo 'PASS universal, self-contained, signed LGPL engine'
