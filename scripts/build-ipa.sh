#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
: "${THEOS:?Set THEOS to the Theos checkout}"
IPA="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve(strict=True))' "${1:?Pass the base IPA path}")"
VERSION="$(python3 -c 'import json; print(json.load(open("upstream.lock.json"))["mod_version"])')"
mkdir -p dist .build/logs
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
bash app/scripts/check-layers.sh app/tweak/Sources
python3 app/scripts/extract-flags.py "$IPA"
env -u MAKELEVEL gmake -C app/tweak clean all SG_VERSION="$VERSION" \
  TARGET_CODESIGN=codesign TARGET_CODESIGN_FLAGS="--force --sign -"
DYLIB="$(find app/tweak/.theos/obj -type f -name spotifyglass.dylib -print -quit)"
test -n "$DYLIB"
cp "$DYLIB" dist/spotifyglass.dylib
codesign --force --sign - dist/spotifyglass.dylib
codesign --verify dist/spotifyglass.dylib
otool -L dist/spotifyglass.dylib | tee .build/logs/dependencies.txt
if grep -q '/Library/Frameworks/CydiaSubstrate' .build/logs/dependencies.txt; then
  echo 'Absolute CydiaSubstrate dependency would prevent sideloading' >&2
  exit 1
fi
python3 app/scripts/repack-ui-ipa.py "$IPA" dist/spotifyglass.dylib \
  "dist/PwEevee-$VERSION-ui-fixes.ipa"
python3 scripts/build-manifest.py "$IPA"
