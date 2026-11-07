#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_NAME="${1:?Supply macosx or iphoneos}"
TRIPLE="${2:?Supply the actual compiler target triple}"
OUT_DIR="${3:?Supply output directory within project build}"
SOURCE_DIR="$PROJECT_DIR/build/vendor/swift-protobuf-1.29.0"
if [ ! -d "$SOURCE_DIR/.git" ]; then
  mkdir -p "$PROJECT_DIR/build/vendor"
  git clone --depth 1 --branch 1.29.0 https://github.com/apple/swift-protobuf.git "$SOURCE_DIR"
fi
VERSION="$(git -C "$SOURCE_DIR" describe --tags --exact-match)"
[ "$VERSION" = '1.29.0' ] || { printf '%s\n' 'Unexpected protobuf source version'; exit 1; }
mkdir -p "$OUT_DIR"
git -C "$SOURCE_DIR" rev-parse HEAD > "$OUT_DIR/protobuf-source-commit.txt"
# Match Eevee's renamed module while linking its real implementation statically,
# so Sideloadly does not need to discover an external rootless framework path.
find "$SOURCE_DIR/Sources/SwiftProtobuf" -name '*.swift' -not -path '*/CMakeFiles/*' -print | sort > "$OUT_DIR/protobuf-sources.txt"
xcrun --sdk "$SDK_NAME" swiftc -O -parse-as-library -whole-module-optimization \
  -target "$TRIPLE" -sdk "$(xcrun --sdk "$SDK_NAME" --show-sdk-path)" \
  -module-name EeveeSwiftProtobuf -enable-library-evolution \
  -emit-object -emit-module -emit-module-path "$OUT_DIR/EeveeSwiftProtobuf.swiftmodule" \
  -o "$OUT_DIR/EeveeSwiftProtobuf.o" @"$OUT_DIR/protobuf-sources.txt"
cp "$SOURCE_DIR/LICENSE.txt" "$OUT_DIR/SwiftProtobuf-LICENSE.txt"
