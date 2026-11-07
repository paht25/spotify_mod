#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
: "${THEOS:?Set THEOS to an official recursive checkout of theos/theos}"
command -v gmake >/dev/null || { echo 'GNU make (brew install make) is required.' >&2; exit 1; }
bash "$PROJECT_DIR/scripts/build-core.sh"
bash "$PROJECT_DIR/Integration/Chroma/scripts/check-layers.sh" "$PROJECT_DIR/Integration/Chroma/tweak/Sources"
# ZIP uploads do not preserve shell executable bits. Invoke scripts explicitly.
chmod +x "$PROJECT_DIR/Integration/Chroma/scripts/check-layers.sh"
env -u MAKELEVEL gmake -C "$PROJECT_DIR/Integration/Chroma/tweak" clean all
OUT="$PROJECT_DIR/build/unified"
mkdir -p "$OUT"
DYLIB="$PROJECT_DIR/Integration/Chroma/tweak/.theos/obj/spotifyglass.dylib"
test -f "$DYLIB" || { echo 'Theos did not produce the unified dylib.' >&2; exit 1; }
cp "$DYLIB" "$OUT/spotifyglass.dylib"
codesign --force --sign - --timestamp=none "$OUT/spotifyglass.dylib"
xcrun lipo -verify_arch arm64 "$OUT/spotifyglass.dylib"
xcrun otool -L "$OUT/spotifyglass.dylib" > "$OUT/dependencies.txt"
xcrun nm -g "$OUT/spotifyglass.dylib" > "$OUT/symbols.txt"
for NAME in USAttachEeveeFeed USAttachEeveePremium USCleanSharedObject USUnifiedComplete; do
  awk -v symbol="_$NAME" '$NF == symbol && $(NF-1) != "U" { found=1 } END { exit !found }' "$OUT/symbols.txt" || {
    echo "Missing unified symbol: $NAME" >&2; exit 1;
  }
done
bash "$PROJECT_DIR/Integration/Chroma/scripts/build-extension.sh" "$PROJECT_DIR/Resources/HostInfo-9.1.88.plist" "$OUT/live-activity"
xcrun --sdk iphoneos clang -target arm64-apple-ios27.0 -dynamiclib -fobjc-arc -Os \
  -framework Foundation -framework Security -install_name @rpath/SpotifyGlassAppGroups.dylib \
  -o "$OUT/SpotifyGlassAppGroups.dylib" "$PROJECT_DIR/Integration/Chroma/extension/AppGroups/AppGroups.m"
codesign --force --sign - --timestamp=none "$OUT/SpotifyGlassAppGroups.dylib"
node "$PROJECT_DIR/tools/package-unified.mjs" "$OUT/spotifyglass.dylib"
printf '%s\n' 'Built unified source candidate. This is not a device test or proof of full Eevee feature parity.'
