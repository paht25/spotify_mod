#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$PROJECT_DIR/scripts/build-core.sh"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
BUILD_DIR="$PROJECT_DIR/build/experimental"
CORE_DIR="$PROJECT_DIR/build/core-ios"
mkdir -p "$BUILD_DIR"
for NAME in USFeedHooks USBootstrap USUtilityHooks USDiagnosticsUI; do
  xcrun --sdk iphoneos clang -target arm64-apple-ios27.0 -isysroot "$SDK_PATH" \
    -fobjc-arc -O2 -Wall -Wextra -Werror \
    -I"$PROJECT_DIR/Sources/Core" -I"$PROJECT_DIR/Sources/Transport" \
    -c "$PROJECT_DIR/Sources/Injection/$NAME.m" -o "$BUILD_DIR/$NAME.o"
done
xcrun --sdk iphoneos swiftc -target arm64-apple-ios27.0 -sdk "$SDK_PATH" \
  -emit-library -o "$BUILD_DIR/UnifiedSpotifyExperimental.dylib" \
  "$CORE_DIR/USHookRegistry.o" "$CORE_DIR/USRuntimeState.o" "$CORE_DIR/USResponseTransaction.o" "$CORE_DIR/FeedAdapter.o" \
  "$CORE_DIR/protobuf/EeveeSwiftProtobuf.o" \
  "$BUILD_DIR/USFeedHooks.o" "$BUILD_DIR/USBootstrap.o" "$BUILD_DIR/USUtilityHooks.o" "$BUILD_DIR/USDiagnosticsUI.o" \
  -framework Foundation -framework UIKit -framework QuartzCore -framework StoreKit \
  -Xlinker -install_name -Xlinker @rpath/UnifiedSpotifyExperimental.dylib \
  -Xlinker -rpath -Xlinker @executable_path/Frameworks
codesign --force --sign - --timestamp=none "$BUILD_DIR/UnifiedSpotifyExperimental.dylib"
xcrun lipo -verify_arch arm64 "$BUILD_DIR/UnifiedSpotifyExperimental.dylib"
xcrun otool -L "$BUILD_DIR/UnifiedSpotifyExperimental.dylib" > "$BUILD_DIR/dependencies.txt"
node "$PROJECT_DIR/tools/package-experimental.mjs" "$BUILD_DIR/UnifiedSpotifyExperimental.dylib"
