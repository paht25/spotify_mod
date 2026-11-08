# Personal Spotify — independent v8 work in progress

Target: Spotify 9.1.90 build 919002269, iOS 27, ARM64, Sideloadly.
Revision: `personal-independent-v8-9190`.

The scope includes player, Liquid Glass Redesigned, NavBar, content pages, synced lyrics, lock-screen behavior and the remaining observed Chroma 1.0.1 features. The user explicitly excluded ambient playback and Sing/vocal separation. Synced lyrics are retained. This project does not patch the protected Chroma binary, forge Plus access or use the Chroma account/backend for the new modules.

**This is not a completed Chroma 1.0.1 replica.** The public baseline previously labelled 0.51.0 actually declares version 0.22.0. Its source is retained under the user's previously confirmed private integration permission, with notices intact. Its presence does not establish newer player/UI/NavBar parity. Missing 1.0.1 implementations and untested behavior are tracked explicitly.

Independently authored additions in this branch:

- Read-only audio output observer and a lock-free 2,048-sample spectrum/FFT pipeline. Production C tests run on Windows, including silence, tone placement, RMS, clipping, malformed input, wrap and simultaneous producer/consumer access.
- Three actual Metal spectrum/orbit/wave backgrounds plus local user shader import. No invented audio levels. GPU drawing pauses off-screen/background, lowers work for low-power/heat/Reduce Motion and compiles shaders off the UI thread.
- Local asset library: user fonts, audio-preset JSON and GraphicEQ headphone correction files; strict allowlists/ranges; no paid Workshop download impersonation. Font registration/overrides and actual existing DSP APIs are connected.
- Opt-in Web Display on private Wi-Fi: actual now-playing metadata/artwork/lyrics and optional whitelisted playback controls. Per-start random private link, request limits and no account/audio/credential relay. Apple Network runtime behavior still needs device verification.

The older renderer baseline retains its native and redesigned modes, NavBar editors, player controls, lyrics providers, artwork, Live Activity, haptics, gestures, speed/pitch and DSP source. Selected Eevee transformations are composed into the existing single transport owner. The exact 6.6.8 source is included for reference/comparison; some newer v7-derived filters are intentionally retained. The original Chroma 1.0.1 and Eevee dylibs are not loaded together.

The v8 candidate built successfully with Xcode 27.1 on GitHub Actions, including ARM64, the built-in Metal shader, Live Activity and Debian structure validation. Foundation/transport/ad-policy/spectrum/asset/HTTP tests passed. This is not a device playback or UI test. See [v8 verification](reports/VERIFICATION-v8.vi.md), [feature inventory](reports/FEATURES-v7.md) and [build instructions](BUILD-v8.vi.md). Full Chroma 1.0.1 parity and audible ad blocking remain unverified. Old artifacts are rejected by the v8 packager.
