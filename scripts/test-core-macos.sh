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
