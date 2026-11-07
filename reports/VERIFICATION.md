# Verification report

## Full Chroma source integration candidate v5

Latest authored target includes all 278 original Chroma source files, composes Eevee feed/account transforms into Chroma's delegate ownership and ports selected Eevee service/True Shuffle/crossfade hooks. All 86 Logos sources passed actual preprocessing and the layer checker passes. See `UNIFIED-v5-STATUS.md` for full status, unported features, unexecuted Apple tests and signing/device requirements. No v5 Apple build, new `.deb`, install or runtime pass is claimed. Earlier sections describe earlier milestones.

## Authored sidebar/configuration v4 for 9.1.88

Latest user steering supersedes the 9.1.90 target with 9.1.88 and requests no floating entry. New source ports Settings/sidebar row placement, uses actual native UIGlassEffect for the row and adds original Eevee bootstrap/customize account/configuration modifiers with a real statically built SwiftProtobuf 1.29.0 runtime. Original configuration snapshots are embedded without changing their bytes. New tests cover wire-message transforms, entitlement preservation, disabled mode and malformed response fallback. Full redesign/player/lyrics/animated lock screen are not integrated.

Local Bash syntax checks, Node syntax/generator checks, payload hash checks and mechanical UI detector ran successfully. Apple compilation, new tests, target app/selector compatibility, UI rendering and ad behavior on Spotify 9.1.88 remain UNVERIFIED. No v4 binary or `.deb` was produced locally. Prior user-reported v3 operation does not validate these changes.

## Authored personal menu v3, awaiting cloud/device validation

The next milestone adds UIKit settings/diagnostics, Foundation runtime state counters, persistent toggles, an adapted copy of Eevee's pure share-link algorithm with C ownership bridges, native sharing/rating/control-haptic hooks and bounded bootstrap retries. New Foundation tests cover concurrent counters and sharing behavior. Bash and Node syntax checks passed locally. The mechanical design detector returned no findings for the UIKit source, which does not establish visual QA. Native compilation, new test execution and on-device rendering/feature behavior are NOT VERIFIED. All 47 original payload hashes still match their original manifest. Full Chroma/Eevee integration and feature parity remain unachieved.

## Received cloud artifact: feed-c-bridge-v2

The user supplied `experimental-feed-only-Sideloadly-test.zip` after workflow run #5 succeeded. The artifact was inspected locally without loading any executable code. `tools/verify-received-artifact.mjs` verified the manifest hashes, Debian ar member structure, gzip/tar header checksums, exact file list/modes, bundle filter and identical standalone/packaged dylib bytes. The dylib is genuine thin ARM64 iOS MH_DYLIB with minimum OS 27.0, SDK 27.1, an initializer section and embedded code signature command. Direct load dependencies are Apple system/Swift libraries; no missing third-party framework is named for this isolated feed build. Cryptographic signing verification and target-device runtime behavior remain untested.

The experimental `.deb` now genuinely exists in `received-artifact`. Its SHA-256 is `cccb806f6f2ac0ad11e85338f30521de5dbfe77adf3ade3bee0615295a25058b`. Its standalone dylib SHA-256 is `20ffeade9fc23d8f21b8a48c632e7e835b8a8e9d9342197f08e476f3483d81cf`. Full static results are in `received-artifact/STATIC-VERIFICATION.json`. This is not evidence that the remaining Chroma/Eevee features are integrated or that Spotify starts successfully with the injected dylib.

## Cloud and experimental-hook update

User screenshot of workflow run #3 shows the core/transport/Chroma codec/Eevee integration test step, ARM64 core compilation and artifact upload succeeded. This verifies the prior component milestone at workflow-step level; full logs and artifact hashes were not supplied. It does not verify Spotify runtime behavior.

New code now adds the isolated feed delegate hook, hook integration tests, iOS dylib linker/bootstrap, Debian archive writer and cloud package validation. Bash and Node syntax checks passed locally, and the 47 payload hashes still pass. The NEW hook tests, dylib link and `.deb` packaging have not run on Apple tooling yet; no compiled experimental artifact is present locally. See `EXPERIMENTAL-TEST.vi.md`. This is not a full unified tweak or rootless installation validation.

## Independent core implementation update

New Objective-C infrastructure exists in `Sources/Core`: a registry that checks hook ownership, method ABI and original implementation before installation, and typed preference copying that preserves source keys and existing destination values. These primitives do not implement the original Spotify features or reconcile their hook bodies. Tests for inheritance isolation, duplicate ownership, ABI mismatch and settings preservation are supplied in `Tests/CoreTests.m`.

Both shell scripts passed Bash syntax checking on this host. Actual core compilation was attempted through `scripts/build-core.sh` and stopped with `Build blocked: Xcode with an iPhoneOS SDK is required.` The macOS runtime-test script also stops because the Apple toolchain is unavailable. The Objective-C implementation and its tests remain UNCOMPILED / NOT RUNTIME TESTED. No `.deb` was created. The source/payload verification checks were rerun after these additions.

## Successfully executed host checks

Run `node unified-spotify/tools/verify.mjs` from the workspace root. The machine-readable result is `host-verification.json`.

- All 47 original payload files still match the sizes and SHA-256 hashes recorded in the earlier staging manifest.
- All 47 staged copies match current original bytes.
- Both decoded injection filters select `com.spotify.client`.
- All 31 binary plist files decode, including all 27 localized dictionaries.
- The two tweak binaries are ARM64; EeveeSwiftProtobuf has two architecture slices.
- The recorded deployment targets and Orion required-import/dependency facts pass the explicit assertions.
- Source and binary inventories regenerate successfully using the local Node runtime. The source scanner's output is lexical evidence, not compiler validation.

No archive was re-extracted. Original directories and staged payloads were only read. Reference source repositories were downloaded into the new project and are unmodified. These checks do not recover Unix permissions/owners or establish target-device compatibility.

## Not tested

| Acceptance item | Status | Evidence needed |
|---|---|---|
| Chroma + Eevee unified source implementation | NOT IMPLEMENTED | Licensed integration with real hook ownership and feature modules |
| Every feature represented and preserved | NOT ESTABLISHED | Complete trace from each setting/runtime path to integration code and device test |
| Hook conflict resolution | NOT IMPLEMENTED | Runtime class/selector map and single-owner merged hooks |
| Orion build and symbol compatibility | NOT TESTED | Genuine framework built with pinned compiler, exported-symbol comparison and activation logs |
| iOS 27 / Spotify 9.1.90 / rootless startup | NOT TESTED | Exact jailbreak, loader and target device |
| Settings persistence/migration | NOT IMPLEMENTED / NOT TESTED | Test old defaults, profiles, export/import, restart and rollback |
| Settings UI/navigation | NOT INTEGRATED / NOT TESTED | Every source menu row and interaction tested in the combined app |
| Lyrics services/timing/rendering | NOT TESTED | Network responses for every provider, language, fallback, error and timing mode |
| Playback, queue, gestures, haptics and audio | NOT TESTED | Real track transitions, seek/pause/background behavior and audio route changes |
| SponsorBlock | NOT TESTED | Fetch/skip and reporting workflows, persisted stores and API responses |
| Lock screen and Live Activity | NOT TESTED | Extension/signing/entitlement evidence and device interaction logs |
| Privacy/patching/session interactions | NOT TESTED | Fresh login, expired session, reset, relaunch, free/subscribed account behavior and network fixtures |
| Rootless resource/dependency loading | NOT TESTED | Loader dyld logs, all bundle lookups, shader creation and file metadata checks |
| Unified build | NOT BUILT | Licensed integrated source, Theos/Xcode/iPhoneOS SDK and full dependency graph |
| Unified .deb installation | NOT PRODUCED / NOT TESTED | Genuine build, metadata inspection, install/upgrade/remove tests on target |

## Feature-by-feature device worksheet

Start with every row in `FEATURES.md`, each candidate in `source/feature-verification.csv`, and each localized option/message in `binary/feature-candidates.json`. Deduplicate only after mapping defaults, type, behavior and visibility conditions. Candidate rows are discovery aids, not an exhaustive certified feature list. Record any additional dynamically generated option or runtime path found during testing.

For every actual feature, record: source tag/file/line, original setting key/type/default, activation conditions, Spotify class/selector/type encoding, integrated owner/module, selected appearance profile, prerequisite account/network/OS state, original-only baseline result, unified result, restart/persistence result, error/fallback result, interaction tests, device/build identifiers and attached logs/screenshots. Mark PASS only after execution on the target; source presence and unit-test success do not substitute for runtime evidence.

Required cross-feature scenarios include native/redesigned mode changes with both preference sets populated; every lyric provider with SponsorBlock disabled/enabled on music/podcasts; manual seek during timed lyrics and podcast skipping; mini-player and tab editing during navigation; Home/page/remote-flag precedence; cache clearing versus full data reset; offline/cancelled/redirected/304 responses; foreground/background/lock/unlock; audio route changes; and explicit logout versus session protection. Do not submit test votes/reports to public services without a deliberate approved test procedure.

## Remaining blockers

1. RESOLVED FOR PRIVATE TESTING: the user has confirmed separate Chroma integration permission. No public redistribution permission is inferred. Feature integration is still incomplete.
2. Requested OS/Spotify/rootless parameters are recorded; jailbreak and injection loader remain unspecified. No compatible connected device or target runtime is available.
3. An iOS build toolchain and compiled genuine Orion framework are unavailable here. Public source availability improves reproducibility but is not dependency resolution or a successful build.
4. Runtime behavior and source-to-binary equivalence remain unverified. The integration design and review indexes require further implementation once the blocking inputs are available.
