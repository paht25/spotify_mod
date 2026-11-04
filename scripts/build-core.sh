#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v xcrun >/dev/null 2>&1 || { printf '%s\n' 'Build blocked: Xcode with an iPhoneOS SDK is required.' >&2; exit 1; }
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
if (( ${SDK_VERSION%%.*} < 27 )); then
  printf '%s\n' 'Build blocked: this target configuration requires iPhoneOS SDK 27 or newer.' >&2
  exit 1
fi
BUILD_DIR="$PROJECT_DIR/build/core-ios"
mkdir -p "$BUILD_DIR"
for SOURCE_NAME in USHookRegistry USPreferences; do
  xcrun --sdk iphoneos clang -target arm64-apple-ios27.0 -isysroot "$SDK_PATH" \
    -fobjc-arc -O2 -Wall -Wextra -Werror -I"$PROJECT_DIR/Sources/Core" \
    -c "$PROJECT_DIR/Sources/Core/$SOURCE_NAME.m" -o "$BUILD_DIR/$SOURCE_NAME.o"
done
xcrun --sdk iphoneos ar rcs "$BUILD_DIR/libUnifiedSpotifyCore.a" \
  "$BUILD_DIR/USHookRegistry.o" "$BUILD_DIR/USPreferences.o"
printf '%s\n' "Built $BUILD_DIR/libUnifiedSpotifyCore.a (core library only; Spotify modules are not integrated)."
