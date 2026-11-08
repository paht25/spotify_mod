# Verification — independent v7

This report distinguishes actual local checks from pending Apple/device work. No Chroma 1.0.1 parity, full Eevee parity, ad-free playback or stable UI claim is made.

## Passed locally

- Production stereo spectrum C code compiled with Windows GCC, C11, optimization and warnings as errors. Its executable passed silence, sine placement at four rates/frequencies, RMS/peak, clipping, NaN/Infinity, circular-buffer wrap, unsupported rate, concurrent publication/read and antiphase-stereo tests. Stereo power is combined without cancelling opposite-phase channels. These are algorithm/publication tests, not a Spotify audio-hook test.
- All 87 Logos files preprocess with the real Logos internal generator. The source-layer checker and shell syntax checks pass. This does not compile UIKit or private Spotify ABI calls.
- Source conflict preflight passes. Python syntax, Node packaging/shader-extraction syntax, embedded browser JavaScript syntax and duplicate-key-aware workflow parsing pass.
- Mechanical UI detector returned no remaining findings. The original missing-image finding was fixed by creating an image only after real cover data arrives. No design finding was suppressed. Native render/device UX has not been observed.
- Original 47 extracted/staged payload hashes still match. Both new input SHA-256 values are unchanged. Selected analysis copies live separately; no original `.deb`, `.ipa`, extracted directory or previous v6 output was edited.
- Ambient source/control/import support added during this turn was removed after the user's instruction. No Sing/tách-giọng module is added. The synced-lyrics engine and renderer remain present; their internal `Karaoke` class names refer to synchronized lyric presentation, not vocal separation.

Machine-readable evidence: [verification-v7.json](verification-v7.json).

## Not run

- New native UIKit/CoreText/Network/Metal Objective-C code has not been compiled with the Apple toolchain. CI runs Foundation validators and the local HTTP/capability parser tests before building. Those new Foundation tests have not run on this Windows host.
- The built-in MSL shader can be extracted from the exact production string. CI compiles it if `xcrun metal` exists; otherwise the skip is explicit. No Metal execution or screenshot pass is asserted locally.
- A static browser preview was attempted, but the browser could not reach the localhost preview server (connection timed out). No browser visual pass is recorded; the temporary preview server was stopped.
- New v7 `.deb`/dylib/IPA production, signing, installation, startup, runtime hooks, custom fonts, local asset application, network sharing/control, provider output, lock-screen behavior, thermal/battery performance and audible ad blocking remain pending.
- Earlier v6 build and user-reported startup are historical. They cannot be counted as passes for new v7 code or 1.0.1 features.

## Device checklist

1. Confirm Personal v7 and Spotify 9.1.90. Test Spotify account sign-in/logout normally; no Chroma account flow should be added.
2. Test both native and Redesigned looks, navbar tab order/custom URI/icons, player artwork/controls/scrubber, queue/devices, content pages and restart persistence. Record screenshots/view diagnostics where geometry differs; several newer options are still missing.
3. Play/pause/switch tracks and audio routes. Enable the optional visualizer and check no fabricated movement during silence, no dropout, sensible response to stereo material, GPU suspension in background/off-screen and low-power/heat behavior.
4. Import valid/invalid shaders/fonts/presets/EQ. Apply/delete/reset, restart and verify DSP/user preferences survive. Confirm file errors leave existing settings usable, aliases are not treated as account keys and no source file is overwritten.
5. Confirm synced word/line lyrics, pronunciation/translation where providers supply them, missing-lyrics fallback, track seeking and lock screen. There must be no ambient player or Sing/vocal-removal control.
6. Embed/sign Live Activity and exercise controls, queue, timer and reopening Spotify from the lock screen.
7. Enable Web Display only on trusted private Wi-Fi. Open the copied per-start link on a browser/TV, verify actual metadata/lyrics, test read-only default, optional previous/play/next/seek, no audio streaming, old-link rejection after stop/restart, background behavior and permission denial. Local HTTP is not an encrypted Internet relay.
8. Test Eevee-derived transforms/services and actual ad opportunities across tracks. A hook counter increasing is not proof that an audible ad was blocked. Confirm account/session/playback remain usable with each switch off.

All requested feature families remain in [the comparison](FEATURES-v7.md), including unimplemented items. Ambient and Sing are excluded rather than counted as missing requirements. Full acceptance requires completing the remaining independent modules and validating their real interactions on the target device.
