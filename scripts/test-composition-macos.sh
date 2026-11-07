#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$PROJECT_DIR/build/composition-tests"
CORE="$PROJECT_DIR/Integration/Chroma/tweak/Sources/Core"
mkdir -p "$OUT"
test -f "$PROJECT_DIR/build/core-tests/protobuf/EeveeSwiftProtobuf.o" || {
  echo 'Run scripts/test-core-macos.sh first.' >&2; exit 1;
}
for FILE in "$CORE/USUnifiedTransport.m" "$CORE/USResponseTransaction.m" "$CORE/USRuntimeState.m" "$PROJECT_DIR/Tests/CompositionTests.m"; do
  xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror -I"$CORE" -c "$FILE" -o "$OUT/$(basename "$FILE" .m).o"
done
xcrun --sdk macosx swiftc -parse-as-library -I"$PROJECT_DIR/build/core-tests/protobuf" \
  -import-objc-header "$PROJECT_DIR/Sources/Transport/UnifiedSpotify-Bridging.h" \
  "$PROJECT_DIR/Sources/Eevee/Feed/"*.swift "$PROJECT_DIR/Sources/Eevee/Premium/"*.swift \
  "$PROJECT_DIR/build/generated/USConfigurationData.swift" "$OUT/"*.o \
  "$PROJECT_DIR/build/core-tests/protobuf/EeveeSwiftProtobuf.o" -o "$OUT/CompositionTests"
"$OUT/CompositionTests"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror -I"$CORE" -framework Foundation \
  "$CORE/USEeveeServices.m" "$CORE/USHookRegistry.m" "$CORE/USRuntimeState.m" \
  "$PROJECT_DIR/Tests/ServiceHooksTests.m" -o "$OUT/ServiceHooksTests"
"$OUT/ServiceHooksTests"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror -I"$CORE" -framework Foundation \
  "$CORE/USAudioAdHooks.m" "$CORE/USHookRegistry.m" "$CORE/USRuntimeState.m" \
  "$PROJECT_DIR/Tests/AudioAdHooksTests.m" -o "$OUT/AudioAdHooksTests"
"$OUT/AudioAdHooksTests"
