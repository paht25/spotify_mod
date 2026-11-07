#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
node "$PROJECT_DIR/tools/check-source-conflicts.mjs"
command -v xcrun >/dev/null 2>&1 || { printf '%s\n' 'Build blocked: Xcode with an iPhoneOS SDK is required.' >&2; exit 1; }
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
if (( ${SDK_VERSION%%.*} < 27 )); then
  printf '%s\n' 'Build blocked: this target configuration requires iPhoneOS SDK 27 or newer.' >&2
  exit 1
fi
BUILD_DIR="$PROJECT_DIR/build/core-ios"
mkdir -p "$BUILD_DIR"
bash "$PROJECT_DIR/scripts/build-protobuf.sh" iphoneos arm64-apple-ios27.0 "$BUILD_DIR/protobuf"
node "$PROJECT_DIR/tools/embed-configuration.mjs"
for SOURCE_NAME in USHookRegistry USPreferences USRuntimeState; do
  xcrun --sdk iphoneos clang -target arm64-apple-ios27.0 -isysroot "$SDK_PATH" \
    -fobjc-arc -O2 -Wall -Wextra -Werror -I"$PROJECT_DIR/Sources/Core" \
    -c "$PROJECT_DIR/Sources/Core/$SOURCE_NAME.m" -o "$BUILD_DIR/$SOURCE_NAME.o"
done
for SOURCE_FILE in "$PROJECT_DIR/Sources/Transport/USResponseTransaction.m" "$PROJECT_DIR/Sources/Chroma/Wire/Protobuf.m"; do
  OBJECT_NAME="$(basename "$SOURCE_FILE" .m)"
  xcrun --sdk iphoneos clang -target arm64-apple-ios27.0 -isysroot "$SDK_PATH" \
    -fobjc-arc -O2 -Wall -Wextra -Werror -c "$SOURCE_FILE" -o "$BUILD_DIR/$OBJECT_NAME.o"
done
xcrun --sdk iphoneos swiftc -target arm64-apple-ios27.0 -sdk "$SDK_PATH" \
  -O -emit-object -whole-module-optimization -module-name UnifiedSpotifyFeed \
  -I"$BUILD_DIR/protobuf" \
  -import-objc-header "$PROJECT_DIR/Sources/Transport/UnifiedSpotify-Bridging.h" \
  "$PROJECT_DIR/Sources/Eevee/Feed/BrowsitaSectionStripper.swift" \
  "$PROJECT_DIR/Sources/Eevee/Feed/USEeveeFeedModule.swift" \
  "$PROJECT_DIR/Sources/Eevee/Sharing/CleanShareLinks.swift" \
  "$PROJECT_DIR/Sources/Eevee/Sharing/USSharingBridge.swift" \
  "$PROJECT_DIR/Sources/Eevee/Premium/"*.swift "$PROJECT_DIR/build/generated/USConfigurationData.swift" \
  -o "$BUILD_DIR/FeedAdapter.o"
xcrun --sdk iphoneos ar rcs "$BUILD_DIR/libUnifiedSpotifyCore.a" \
  "$BUILD_DIR/USHookRegistry.o" "$BUILD_DIR/USPreferences.o" "$BUILD_DIR/USRuntimeState.o" \
  "$BUILD_DIR/USResponseTransaction.o" "$BUILD_DIR/Protobuf.o" "$BUILD_DIR/FeedAdapter.o" "$BUILD_DIR/protobuf/EeveeSwiftProtobuf.o"
printf '%s\n' "Built $BUILD_DIR/libUnifiedSpotifyCore.a (core library; scripts/build-unified.sh builds the integrated rendering target)."
