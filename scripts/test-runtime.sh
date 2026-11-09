#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
: "${THEOS:?Set THEOS}"
HARNESS="$ROOT/app/harness/runtime"
SRC="$ROOT/app/tweak/Sources"
mkdir -p "$HARNESS/generated/hooks" .build/runtime-attachments
for path in Redesigned/Navbar/TabBar Redesigned/Navbar/NativeTabMotion Redesigned/Navbar/BottomGradient \
  Redesigned/Navbar/TabBarMinimize Redesigned/Navbar/ProfilePhoto Redesigned/NowPlayingBar/NowPlayingBar; do
  "$THEOS/bin/logos.pl" -c generator=internal "$SRC/$path.x" > "$HARNESS/generated/hooks/$(basename "$path").m"
done
(cd "$HARNESS" && xcodegen generate)
DEVICE="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)
for runtime,devices in sorted(d["devices"].items(),reverse=True):
 if "iOS-2" not in runtime: continue
 for device in devices:
  if "iPhone" in device["name"]:
   print(device["udid"]); sys.exit(0)
raise SystemExit("No iOS 26+ iPhone simulator is available")')"
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl io "$DEVICE" recordVideo --codec=h264 .build/runtime-motion.mp4 &
VIDEO_PID=$!
RESULT=0
xcodebuild test -project "$HARNESS/UIFixesRuntime.xcodeproj" -scheme UIFixesRuntime \
  -destination "platform=iOS Simulator,id=$DEVICE" -parallel-testing-enabled NO \
  -derivedDataPath .build/runtime-derived -resultBundlePath .build/runtime.xcresult \
  CODE_SIGNING_ALLOWED=NO || RESULT=$?
kill -INT "$VIDEO_PID" || true
wait "$VIDEO_PID" || true
xcrun xcresulttool export attachments --path .build/runtime.xcresult --output-path .build/runtime-attachments || true
exit "$RESULT"
