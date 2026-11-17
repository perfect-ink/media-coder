# Media Coder

A small, native SwiftUI video converter for macOS 14 or later. Drop videos, choose a format and size, then click Convert. Everything runs locally using FFmpeg.

## Run

Run `make` (or `make all`) to run `make dev`, which calls `make open`: close the running app, set up the build tools, build Release, and launch it.

```sh
make            # setup + dev
make dev        # run make open
make build      # build optimized Release
make open       # close the app, build Release, and launch
make close      # stop this project's Debug and Release app instances
make clean      # remove all local build artifacts
make help       # grouped command reference
```

`make setup` checks for full Xcode and installs XcodeGen via Homebrew if it is missing. Install Xcode and Homebrew first. The first app build downloads pinned FFmpeg source and compiles a universal engine for Apple Silicon and Intel. Later builds reuse it. End users need no Homebrew, downloads, or separate engine installation.

The Release app lives at `build/Build/Products/Release/MediaCoder.app`. For a Debug build, run the project in Xcode. Xcode automatically updates existing build products, so `make dev` does not delete them first. `make clean` removes `build/`, `.build/`, and local `DerivedData/`; it preserves source files, the project, and preferences. Local builds are ad hoc signed and sandboxed; App Store distribution requires your Apple Developer signing identity.

`make close` sends a termination signal to native app processes whose executable path exactly matches this project’s Debug or Release app. It does not close other checkouts or installed copies. `make open` (and therefore `make dev`) runs it before building, so finish any conversions before restarting.

For development, you can also open `MediaCoder.xcodeproj` in Xcode or use `swift run`.

## Features

- Drop files anywhere in the main window to append them. Drop on the upper or lower half of a sidebar row to insert before or after it; a line shows the destination. Drag sidebar items to reorder the queue, including during conversion.
- Drop multiple videos or add them with the file picker (Command-O).
- Input formats include MPG/MPEG, AVI, MOV, MP4, MKV, WMV, WebM, and more; codec support depends on your FFmpeg build. Any readable file can be added, avoiding an extension whitelist that would block obscure formats. FFmpeg validates its contents during conversion.
- Video output presets: H.264 (MP4/MOV/MKV), HEVC and AV1 (MP4), ProRes (MOV), VP8/VP9 (WebM), FFV1 lossless encoding (MKV), MPEG-4 (AVI), MPEG-2 (MPG), Windows Media (WMV), Motion JPEG (MOV), HuffYUV (AVI), and Ut Video (AVI). AV1 automatically uses libaom or SVT-AV1 depending on the active engine. Only presets with the required encoders are shown. Resizing and pixel normalization can change pixels even when using a lossless encoder.
- Extract the first audio track as M4A (AAC), MP3, WAV (PCM), FLAC, Apple Lossless (M4A), Opus, WavPack, AIFF, or AC-3. AC-3 exports stereo at 48 kHz; Opus uses 48 kHz. Choose an option under **Extract audio** in the format menu, then click **Extract audio**. Video size does not apply. Files are named `movie-audio.m4a` (with numeric suffixes to avoid overwriting); videos without audio show an error. WAV and FLAC do not restore quality lost in the source.
- Keep original size or fit within 3840×2160 (4K UHD), 2560×1440 (2K/QHD), 1920×1080, 1280×720, or 854×480. Choose **Custom** to enter width and height bounds from 2 to 16384 pixels, preserving display aspect ratio without upscaling. Dimensions are rounded to even pixels for encoder compatibility. Anamorphic sources are normalized to square pixels.
- Choose **Smaller file**, **Balanced** (default), or **High quality** for destination video. Quality adjusts compression for the selected codec; higher quality generally produces larger files and cannot restore detail absent from the source. FFV1 uses fixed lossless encoding, and audio extraction is unaffected.
- **Hardware acceleration** for H.264 (MP4/MOV/MKV) and HEVC (MP4) uses Apple VideoToolbox when present in the engine. Hardware acceleration is enabled by default for supported formats and engines; you can turn it off to use software encoding. Hardware quality levels target 4, 8, or 16 Mbit/s; actual size and quality depend on the source. Hardware failures show a retry suggestion with acceleration disabled. This accelerates encoding; decoding and resizing retain the existing path.
- Source specs for the selected video: resolution, video codec, frame rate, duration, overall bitrate, first audio track details, and file size. Read locally using the active engine without converting the file.
- A selectable video sidebar, progress, cancel, retry, error details, and reveal output in Finder. Conversion pauses after each video; click **Next video** to start the next waiting item. Selecting a ready item lets you convert it first.
- Choose an output folder to grant sandbox write access. Outputs include the selected size, for example `movie-converted-720p.mp4` or `movie-converted-original.mp4`, with numeric suffixes when needed. The label describes the chosen size preset; smaller sources are never upscaled. Original files are preserved.

The app converts the first video stream and optional first audio stream. Subtitles and additional tracks are not included. It does not remove interlacing. Local development builds are not App Store submissions.

## Bundled transcoding engine

The app includes FFmpeg 8.1.2 in `Contents/Helpers/ffmpeg`. It never downloads executable code, chooses an external engine, or uses Homebrew when running as an app bundle. Missing engines are a build/install error. **Settings → Codecs** shows the actual bundled codecs. Media stays on the Mac and conversion works offline.

`scripts/build-engine.sh` downloads the official source archive, checks its pinned SHA-256, builds arm64 and x86_64, and combines them. It disables GPL/nonfree/version3 components, external library autodetection, networking, and capture devices. `scripts/verify-engine.sh` rejects non-system dynamic dependencies and GPL/nonfree/version3 build flags. Engine updates require changing the version and digest together, rebuilding, and testing.

H.264 and HEVC use Apple's VideoToolbox encoders. With hardware acceleration disabled, VideoToolbox requires Apple's software implementation; this can fail on Macs without a software encoder for the selected codec. This LGPL build does not include libx264, libx265, libvpx, libopus, libmp3lame, or AV1 encoders. Their presets are hidden when unavailable. Built-in ProRes, FFV1, MPEG-2, WMV, Motion JPEG, HuffYUV, Ut Video, AAC, PCM, FLAC, ALAC, WavPack, and AC-3 remain available. MPEG-4/AVI currently requires MP3 encoding and is hidden too.

The app bundles FFmpeg's license, notices, exact source archive, configure logs, and build recipe under `Contents/Resources/FFmpeg`. Review [FFmpeg's licensing guidance](https://ffmpeg.org/legal.html) for release obligations, including source access and distribution terms; this build configuration alone is not legal clearance or App Store approval. Source must remain available to recipients of each shipped version.

## App Store preparation

The app enables App Sandbox and user-selected read/write access. The engine is signed with only App Sandbox and sandbox inheritance entitlements. No network entitlement is requested. Source file security scopes stay open while queued; output requires a folder selected through the system picker. Access is session-only; queues and folder access are not persisted across launches.

Apple permits [embedded helper tools in sandboxed apps](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app) and requires [self-contained Mac App Store bundles](https://developer.apple.com/app-store/review/guidelines/#software-requirements). The engine is signed before Xcode signs the enclosing app.

To prepare an archive with your own registered identity:

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID \
PRODUCT_BUNDLE_IDENTIFIER=com.yourcompany.MediaCoder \
./scripts/archive-app-store.sh
```

Open `build/MediaCoder.xcarchive` in Xcode Organizer to validate and distribute to App Store Connect. Before submission, set your real bundle identifier, version/build number and signing team, complete App Store metadata/privacy and license review, and test the distribution-signed app on both architectures. Test file picker and Finder drops, source inspection, selected output folders, cancellation/retry, and offline conversions on a Mac without Homebrew. Ad hoc local builds cannot establish that provisioning or App Store review will succeed.

## Build and verify

Requires full Xcode. `make setup` checks the build tools and installs XcodeGen if needed.

```sh
make build
./scripts/test-engine.sh
./scripts/test-queue.sh
./scripts/test-bundled.sh # signed sandbox parent + embedded helper, all available presets
# Also exercise every available preset in the bundled engine:
BUNDLED_FFMPEG="$PWD/build/engine/universal/ffmpeg" ./scripts/test-engine.sh
```

The integration checks create temporary MPG and AVI fixtures and verify real conversions, resizing, silent video handling, malformed input cleanup, cancellation, and existing output protection. The integration test fixture generator and independent ffprobe checks currently expect Apple Silicon Homebrew paths; the shipped app does not.

## App icon

The header, sidebar, drop area, video details, settings, and macOS icon use the same rendered logo. `FilmIconArtwork.swift` contains the source drawing and the reusable image view. PNG assets are checked into `Sources/MediaCoder/Assets.xcassets/AppIcon.appiconset` and compiled into the app by Xcode. The generator also writes the identical 1024-pixel artwork into `AppLogo.imageset` for in-app branding; the app applies it to its Dock icon at launch. To regenerate them after changing the artwork:

```sh
swiftc -parse-as-library Sources/MediaCoder/FilmIconArtwork.swift scripts/generate-app-icon.swift -o /tmp/media-coder-generate-icon
/tmp/media-coder-generate-icon Sources/MediaCoder/Assets.xcassets/AppIcon.appiconset
```
