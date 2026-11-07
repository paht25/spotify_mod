#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
printf '%s\n' 'BUILD REVISION: chroma-core-v5-9188'
git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || true
shasum -a 256 "$PROJECT_DIR/Sources/Injection/USFeedHooks.m" "$PROJECT_DIR/Sources/Eevee/Feed/USEeveeFeedModule.swift"
command -v xcrun >/dev/null 2>&1 || { printf '%s\n' 'Tests blocked: Xcode command line tools and macOS Foundation are required.' >&2; exit 1; }
BUILD_DIR="$PROJECT_DIR/build/core-tests"
mkdir -p "$BUILD_DIR"
bash "$PROJECT_DIR/scripts/build-protobuf.sh" macosx "$(uname -m)-apple-macosx14.0" "$BUILD_DIR/protobuf"
node "$PROJECT_DIR/tools/embed-configuration.mjs"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
  -I"$PROJECT_DIR/Sources/Core" -framework Foundation \
  "$PROJECT_DIR/Sources/Core/USHookRegistry.m" "$PROJECT_DIR/Sources/Core/USPreferences.m" "$PROJECT_DIR/Sources/Core/USRuntimeState.m" \
  "$PROJECT_DIR/Tests/CoreTests.m" -o "$BUILD_DIR/CoreTests"
"$BUILD_DIR/CoreTests"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
  -I"$PROJECT_DIR/Sources/Transport" -I"$PROJECT_DIR/Sources/Chroma/Wire" -framework Foundation \
  "$PROJECT_DIR/Sources/Transport/USResponseTransaction.m" \
  "$PROJECT_DIR/Sources/Chroma/Wire/Protobuf.m" \
  "$PROJECT_DIR/Tests/TransportTests.m" -o "$BUILD_DIR/TransportTests"
"$BUILD_DIR/TransportTests"
xcrun --sdk macosx swiftc \
  "$PROJECT_DIR/Sources/Eevee/Feed/BrowsitaSectionStripper.swift" \
  "$PROJECT_DIR/Tests/EeveeFeed/main.swift" -o "$BUILD_DIR/EeveeFeedTests"
"$BUILD_DIR/EeveeFeedTests"
# Compile the production Swift-to-Objective-C adapter as well as its standalone
# algorithm tests, so missing bridge declarations fail the job.
xcrun --sdk macosx swiftc -emit-object -whole-module-optimization \
  -module-name UnifiedSpotifyFeed \
  -import-objc-header "$PROJECT_DIR/Sources/Transport/UnifiedSpotify-Bridging.h" \
  "$PROJECT_DIR/Sources/Eevee/Feed/BrowsitaSectionStripper.swift" \
  "$PROJECT_DIR/Sources/Eevee/Feed/USEeveeFeedModule.swift" \
  -o "$BUILD_DIR/FeedAdapter.o"
# Record the actual emitted C bridge before linking any hook. If this symbol
# is absent, report the boundary failure instead of requesting an ObjC class.
xcrun nm -g "$BUILD_DIR/FeedAdapter.o" > "$BUILD_DIR/feed-symbols.txt"
if ! awk '$NF == "_USAttachEeveeFeed" && $(NF-1) != "U" { found=1 } END { exit !found }' "$BUILD_DIR/feed-symbols.txt"; then
  printf '%s\n' 'Swift did not emit the required USAttachEeveeFeed C bridge.' >&2
  exit 1
fi
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
  -c "$PROJECT_DIR/Sources/Transport/USResponseTransaction.m" -o "$BUILD_DIR/Transaction.o"
xcrun --sdk macosx swiftc -import-objc-header "$PROJECT_DIR/Sources/Transport/UnifiedSpotify-Bridging.h" \
  "$PROJECT_DIR/Sources/Eevee/Feed/BrowsitaSectionStripper.swift" \
  "$PROJECT_DIR/Sources/Eevee/Feed/USEeveeFeedModule.swift" \
  "$PROJECT_DIR/Tests/FeedIntegration/main.swift" "$BUILD_DIR/Transaction.o" \
  -o "$BUILD_DIR/FeedIntegrationTests"
"$BUILD_DIR/FeedIntegrationTests"
for SOURCE_FILE in "$PROJECT_DIR/Sources/Core/USHookRegistry.m" "$PROJECT_DIR/Sources/Core/USRuntimeState.m" "$PROJECT_DIR/Sources/Injection/USFeedHooks.m" "$PROJECT_DIR/Tests/HookTests.m"; do
  OBJECT_NAME="$(basename "$SOURCE_FILE" .m)"
  xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
    -I"$PROJECT_DIR/Sources/Core" -I"$PROJECT_DIR/Sources/Transport" -I"$PROJECT_DIR/Sources/Injection" \
    -c "$SOURCE_FILE" -o "$BUILD_DIR/$OBJECT_NAME.o"
done
xcrun --sdk macosx swiftc -parse-as-library \
  -I"$BUILD_DIR/protobuf" \
  -import-objc-header "$PROJECT_DIR/Sources/Transport/UnifiedSpotify-Bridging.h" \
  "$PROJECT_DIR/Sources/Eevee/Feed/BrowsitaSectionStripper.swift" \
  "$PROJECT_DIR/Sources/Eevee/Feed/USEeveeFeedModule.swift" \
  "$PROJECT_DIR/Sources/Eevee/Premium/"*.swift "$PROJECT_DIR/build/generated/USConfigurationData.swift" \
  "$BUILD_DIR/USHookRegistry.o" "$BUILD_DIR/USRuntimeState.o" "$BUILD_DIR/Transaction.o" "$BUILD_DIR/USFeedHooks.o" "$BUILD_DIR/HookTests.o" \
  "$BUILD_DIR/protobuf/EeveeSwiftProtobuf.o" \
  -o "$BUILD_DIR/HookTests"
"$BUILD_DIR/HookTests"
xcrun --sdk macosx swiftc \
  "$PROJECT_DIR/Sources/Eevee/Sharing/CleanShareLinks.swift" \
  "$PROJECT_DIR/Sources/Eevee/Sharing/USSharingBridge.swift" \
  "$PROJECT_DIR/Tests/Sharing/main.swift" -o "$BUILD_DIR/SharingTests"
"$BUILD_DIR/SharingTests"
xcrun --sdk macosx swiftc -I"$BUILD_DIR/protobuf" \
  -import-objc-header "$PROJECT_DIR/Sources/Transport/UnifiedSpotify-Bridging.h" \
  "$PROJECT_DIR/Sources/Eevee/Feed/BrowsitaSectionStripper.swift" "$PROJECT_DIR/Sources/Eevee/Feed/USEeveeFeedModule.swift" \
  "$PROJECT_DIR/Sources/Eevee/Premium/"*.swift "$PROJECT_DIR/build/generated/USConfigurationData.swift" \
  "$PROJECT_DIR/Tests/Premium/main.swift" "$BUILD_DIR/Transaction.o" "$BUILD_DIR/protobuf/EeveeSwiftProtobuf.o" \
  -o "$BUILD_DIR/PremiumTests"
"$BUILD_DIR/PremiumTests"
