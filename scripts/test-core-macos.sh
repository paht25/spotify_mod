#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v xcrun >/dev/null 2>&1 || { printf '%s\n' 'Tests blocked: Xcode command line tools and macOS Foundation are required.' >&2; exit 1; }
BUILD_DIR="$PROJECT_DIR/build/core-tests"
mkdir -p "$BUILD_DIR"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
  -I"$PROJECT_DIR/Sources/Core" -framework Foundation \
  "$PROJECT_DIR/Sources/Core/USHookRegistry.m" "$PROJECT_DIR/Sources/Core/USPreferences.m" \
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
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
  -c "$PROJECT_DIR/Sources/Transport/USResponseTransaction.m" -o "$BUILD_DIR/Transaction.o"
xcrun --sdk macosx swiftc -import-objc-header "$PROJECT_DIR/Sources/Transport/UnifiedSpotify-Bridging.h" \
  "$PROJECT_DIR/Sources/Eevee/Feed/BrowsitaSectionStripper.swift" \
  "$PROJECT_DIR/Sources/Eevee/Feed/USEeveeFeedModule.swift" \
  "$PROJECT_DIR/Tests/FeedIntegration/main.swift" "$BUILD_DIR/Transaction.o" \
  -o "$BUILD_DIR/FeedIntegrationTests"
"$BUILD_DIR/FeedIntegrationTests"
