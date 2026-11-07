# Unified Spotify — private v6 candidate

Target: **Spotify 9.1.90 build 919002269 / iOS 27 / ARM64 / Sideloadly**.
Current revision: `personal-v6-9190`. Earlier v4/v5 instructions and binaries are historical.

This integrates Chroma/spoti.pw 0.51.0 source with selected real EeveeSpotify 7.0.0 implementations. One Chroma renderer owns each visual surface; Eevee transformations compose inside the same network task. The original tweak binaries are never loaded together. All 278 original Chroma source files remain present; author donation/update/usage modules are excluded from compilation at the user's request. Licenses and attribution are retained.

The user reports v5 starts, but Redesigned does not work and audio ads remain. That is evidence of v5 problems, not a v6 runtime pass. V6 adds a targeted playback product-state ad policy, fixes inconsistent Redesigned switch defaults, restores profile defaults when enabling the redesign after a stock reset, adds runtime implementation diagnostics, and regenerates flags from the supplied 9.1.90 executable.

**V6 has not been compiled with Xcode or tested on a device. No v6 `.deb` or `.ipa` has been produced locally.** A legacy transition class is absent in 9.1.90, leaving the original mini-player/player morph unresolved. Eevee-only UI, additional lyrics/karaoke, SponsorBlock and remaining session behavior are incomplete. Source inclusion and static ABI checks do not establish full feature parity.

- [Build and installation instructions in Vietnamese](PERSONAL-v6.vi.md)
- [Current feature comparison and verification checklist](reports/UNIFIED-v6-STATUS.md)
- [Detailed original inventory](reports/FEATURES.md)
- [Current dependency route](reports/DEPENDENCIES-v6.md)

Upload the contents of `personal-v6-9190-source.zip` to the private build repository, preserving directories. Run **Chroma source integration - v6-9190** on the existing working `xcode-27` runner. A successful run must pass component tests, including the new ad-policy boundary tests, compile the integrated image and Live Activity, and validate its Debian container. Download `personal-v6-9190-Sideloadly-test` only after that run succeeds.

The provided IPA and original extracted Debian payloads stay unchanged. IPA assembly requires the exact inspected clean 9.1.90 executable and a genuinely compiled v6 artifact. It rejects old experiments rather than relabelling them. Live Activity requires extension embedding and signing; see the assembly instructions. The `.deb` is an IPA injection container, not a validated rootless jailbreak installer.

The Windows host can run hash, metadata, Logos preprocessing, layer and archive checks. Foundation/Swift tests and iOS compilation require the Apple cloud runner; installation, UI, playback and signing require the device. See the report for performed versus pending checks.

Chroma reference: `425d68bc1761e90a6b5828864720511bcef79fa9`; Eevee reference: `d1da1d69715935e41d1dc97a25d11bcc42ebd170`. The user confirms permission for this private Chroma integration. Original PolyForm Strict, GPL-3.0, SwiftProtobuf and audio vendor notices are preserved. This is a derivative integration, not a claim of sole authorship of upstream implementations.
