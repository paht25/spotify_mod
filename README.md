# Unified Spotify — private integration candidate

Current target: **Spotify 9.1.88 build 918802209 / iOS 27 / Sideloadly**.

The v5 target compiles all 278 original Chroma source files plus selected Eevee feed/account/service/sharing modules into one main image. Chroma retains both native and redesigned profiles, its player/lyrics/artwork/audio implementations, and the original settings workflow. Live Activity has a separate extension and IPA assembly step. Both original tweak binaries are not loaded together.

**This project is not complete:** Eevee-only UI options, providers/karaoke, SponsorBlock/reporting and remaining session/premium/ad hooks are not fully ported. No v5 Apple compilation, installation or runtime pass has been obtained. Original source inclusion is not proof that every feature works on 9.1.88.

- [Vietnamese build and installation guide](CHROMA-CORE-v5.vi.md)
- [Feature-by-feature status and verification limits](reports/UNIFIED-v5-STATUS.md)
- [Original feature inventory](reports/FEATURES.md)
- [Original input/dependency investigation](reports/DEPENDENCIES.md)

## Build and install

Upload the contents of `chroma-core-v5-9188.zip` to the existing private repository. Run **Chroma source integration - v5-9188** with the user's working `xcode-27` runner. It executes Foundation/Swift tests, builds the real protobuf runtime, builds Chroma and the composed modules with pinned Theos, builds the extension, and validates the Debian container.

On a successful run download **chroma-core-v5-9188-Sideloadly-test**. Follow the Vietnamese guide to prepare a new unsigned IPA from the supplied clean NoEevee 9.1.88 input, then sign/install with Sideloadly. The assembly step is required to include Live Activity metadata/extension. A dylib alone does not install that extension. The `.deb` is an IPA-injection container, not a verified rootless jailbreak installer.

The local machine lacks Xcode/iPhoneOS SDK and cannot compile the new target. The GitHub connector currently returns 404 for `paht25/cloud`; no remote build was initiated here. Original payloads and IPA files are read only.

## Project contents

- `Integration/Chroma`: integrated copy of Chroma v0.51.0, including audio vendor source, extension, license and layer guidance. Source commit: `425d68bc1761e90a6b5828864720511bcef79fa9`.
- `Sources/Eevee`: adapted real v7.0.0 implementations, source commit `d1da1d69715935e41d1dc97a25d11bcc42ebd170`.
- `Sources/Core`, `Sources/Transport`: ownership/preferences/transport infrastructure. Earlier injection targets remain for regression tests; they are not linked into the new main image.
- `scripts/build-unified.sh`: actual full-source build. It uses the real Eevee Swift object/protobuf runtime and compiles Core/transport/Chroma wire code only once.
- `tools/assemble-personal-ipa.py`: non-destructive unsigned IPA assembly with input hash, Mach-O padding and artifact checks.
- `Tests`, `reports`: authored test cases, static evidence, and explicit build/device status.
- `upstream`: unchanged reference checkouts (not included in the upload ZIP); not build outputs.

## Reproduce local input checks

Requires Node.js and the existing sibling `data-pw`, `data-eve`, `unified-staging` directories:

```powershell
node tools/verify.mjs
node tools/audit-unified-source.mjs
```

The second command also needs the unchanged upstream Chroma checkout and existing IPA metadata reports. All 47 original payload/staged hashes match. All 86 Logos files passed preprocessing; the layer checker passes. These checks do not verify signatures, device behavior or full functionality.

## Licenses and earlier milestones

The user confirms separate permission for private Chroma integration. Original notices/vendor licenses are retained; public redistribution rights are not assumed. Eevee code remains under its original GPL-3.0 terms. SwiftProtobuf is built from official source and includes its license. No empty dependency framework is fabricated.

<<<<<<< HEAD
`personal-sidebar-v4-9188.zip`, `personal-menu-v3.zip`, earlier feed artifacts, and their reports are historical milestones. User-reported startup/menu operation applies to those earlier builds and is not verification of v5. The original 9.1.90/rootless request is superseded by the current 9.1.88/Sideloadly workflow.
=======
`personal-sidebar-v4-9188.zip`, `personal-menu-v3.zip`, earlier feed artifacts, and their reports are historical milestones. User-reported startup/menu operation applies to those earlier builds and is not verification of v5. The original 9.1.90/rootless request is superseded by the current 9.1.88/Sideloadly workflow.
>>>>>>> 696afedd902c1a3976110c952a8f1a45a39bf9c2
