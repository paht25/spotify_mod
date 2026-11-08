#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$PROJECT_DIR/Integration/Chroma/tweak/Sources/Core"
mkdir -p "$PROJECT_DIR/build/personal-tests"
xcrun --sdk macosx clang -std=c11 -O2 -Wall -Wextra -Werror -I"$CORE" \
  "$CORE/USAudioSpectrum.c" "$PROJECT_DIR/Tests/AudioSpectrumTests.c" \
  -o "$PROJECT_DIR/build/personal-tests/AudioSpectrumTests"
"$PROJECT_DIR/build/personal-tests/AudioSpectrumTests"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror -I"$CORE" -framework Foundation \
  "$CORE/USAssetValidation.m" "$PROJECT_DIR/Tests/PersonalAssetTests.m" \
  -o "$PROJECT_DIR/build/personal-tests/PersonalAssetTests"
"$PROJECT_DIR/build/personal-tests/PersonalAssetTests"
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror -I"$CORE" -framework Foundation \
  "$CORE/USLocalHTTP.m" "$PROJECT_DIR/Tests/LocalHTTPTests.m" \
  -o "$PROJECT_DIR/build/personal-tests/LocalHTTPTests"
"$PROJECT_DIR/build/personal-tests/LocalHTTPTests"
