# v5 source, build and runtime status

Target: user-supplied Spotify 9.1.88 build 918802209, iOS 27, private IPA injection with Sideloadly. This supersedes 9.1.90/rootless packaging for this artifact. No original .deb was re-extracted. User permission for private Chroma integration is recorded in the conversation; public redistribution rights are not inferred.

## Supplied cloud run and build fix1

Latest supplied log records commit `8729d5860233f836a6b2cfcb112e1a6e7e3875f2`: preflight, component tests and core compilation passed; the previous trait-callback error is absent. Compilation stops at `Redesigned/Library/LibraryRows.x:55` because mainScreen is deprecated under SDK 27.1. A target-wide search found three global-screen calls. Fix6 uses displayScale from each view in Library/DSP, refreshes DSP hairlines for layout/scale changes, and resolves the morph screen from its transition container once per transition, preserving guarded private corner-radius lookup and fallback. Two modified Logos hooks pass preprocessing and layers pass locally. The fixed target still needs an Apple build and device checks; see `BUILD-FIX6.vi.md` and `cloud-v5-build-fix6.json`.

Latest log `job-logs.txt` now records commit `1732aa3f04744f5bc823080d5cc3906fb8604afa`: source preflight, all nine component test groups and ARM64 core library compilation passed. Full tweak compilation stops at `SGRDownload.m:215`, a deprecated `traitCollectionDidChange:` super call promoted to an error by `-Werror` on SDK 27.1. Fix5 preserves initial paint, uses UIKit's color-appearance trait registration to invoke the existing repaint method, and removes the deprecated override. Animation/progress logic is unchanged; the fixed source still needs cloud compilation and device validation. Details: `cloud-v5-build-fix5.json`, `BUILD-FIX5.vi.md`.

Latest evidence is `job-logs.txt`, repository `paht25/spotify_mod`, commit `1e4bcde03ee71d9b8762d6918ebb55c4a37039af`. The workflow now parses and source preflight executes, but identifies 11 additional conflicted Swift/configuration files and stops before tests. Fix4 supplies all reported paths together with previous fixes and an optional hash-checked source-copy helper with backups. The GitHub connector returns 404 for the new private repository as well; no remote update or corrected build is claimed. Details: `cloud-v5-build-fix4.json`, `BUILD-FIX4.vi.md`.

Latest screenshot (run #10, displayed commit `295b1a0`) shows unresolved conflict markers in the workflow itself, mixing v5 and v3. YAML parsing fails before any job can run. Fix3 provides a clean workflow, includes all earlier fixes, and adds a named source preflight step immediately after checkout. The screenshot is evidence about that run's snapshot, not the current private main branch. No corrected cloud build has been observed.

Latest run `logs_114798257368.zip`, commit `27c586269e139f8e31b9bc7fe7c97f478e479487`, stops earlier: unresolved Git conflict markers in `Sources/Chroma/Wire/Protobuf.h` and `.m`. Only CoreTests reports PASS in that run. Fix2 ships canonical codec files byte-identical to original Chroma, retains fix1, and runs source-conflict preflight before tests/build. The local source tree passes preflight, including a negative fixture verifying marker rejection. See `cloud-v5-build-fix2.json` and `BUILD-FIX2.vi.md`. No corrected full cloud build or runtime pass is claimed.

`logs_114796457459.zip` records commit `9a63499e9585ceae0405883cb07f513d9ecd4593`, Xcode 27.1 / SDK 27.1. Core, transport/wire, feed, delegate, sharing, premium, composition and service-hook tests report PASS; the ARM64 core library build completed. The full tweak build failed because `App/UnifiedSettings.m` called `SGTopController()` without importing its declaring header. Fix1 adds `Settings/SGPageStyle.h`, consistent with other original Chroma pages. See `cloud-v5-build-fix1.json` and `BUILD-FIX1.vi.md`.

These logs establish the component test run, not Spotify runtime behavior. The fixed source has not yet completed a cloud rebuild. Full dylib, extension, `.deb`, installation and device acceptance remain unverified. Earlier statements about unavailable local Apple execution still apply; the new supplied cloud evidence supersedes any earlier statement that the component tests had never run anywhere.

## Successful local checks

- All **278 original Chroma source files** present; per-file before/after hashes in `unified-source-audit.json`. Target guards account for most changes. Source inclusion does not establish execution.
- All **86 Logos sources** passed the official internal-generator preprocessor, including the actual modified network hooks. This checks Logos syntax, not Apple SDK compilation.
- Chroma layer checker passes; no Native/Redesigned cross-imports added.
- Original Chroma ARM64 flag walker with supplied executable metadata: 2,496 unique keys, 2,306 typed, 190 unknown; zero walker failures. Unknown types not guessed.
- All 47 original payload and staged-copy hashes still match. Original IPA inputs unchanged.
- Bash, Node and Python syntax checks pass. Negative packaging test rejects the old experimental dylib instead of relabelling it as this build.
- Workflow YAML parsed successfully with duplicate-key rejection (including the earlier duplicate `on` failure class). This does not establish runner availability or successful workflow execution.
- Actual clean 9.1.88 executable tested in memory: both new load commands fit existing zero padding, original sections remain byte-identical, reinsertion is idempotent, nonzero padding is rejected. No IPA was produced or signed in this test; the clean input has no `WidgetExtension.appex/WidgetExtension` at the original upstream path.
- Static metadata: 25 selected Eevee service/playback target classes; 9 have own `load` methods. Missing own methods do not establish absence of inherited/runtime methods. Activation checks actual runtime ABI and records failures.

## Feature checklist

Every v5 device test below is **NOT RUN**. “Original source” means implementations selected by the new build target, not a verified feature or proof of source/binary equivalence.

| Feature / workflow | v5 implementation | Required device check |
|---|---|---|
| Chroma native/redesigned modes | Original source; saved profile retained | Restart between profiles, one renderer active |
| Settings/sidebar | Original row, unified title/Eevee page | Both entries, navigation/back, no floating control |
| Tabs/editor/custom navigation | Original mode-specific source | Reorder, hide labels, custom URI, persistence |
| Mini/full player, queue/devices | Original source | Transitions, controls, scrub, queue, remote playback |
| Home/Search/Library/playlist/album/artist | Original source | Layout/scroll/menu/hide options in both modes |
| Lyrics providers/TTML/timing | Original Chroma pipeline/codec | Providers/fallback, missing lyrics, donor requests |
| Lyrics rendering/meanings/translation/pronunciation | Original source | Seek, overlapping vocals, gaps, attribution |
| Lock-screen lyrics/artwork | Original Canvas/Apple artwork and lyrics | Timing, source order, cache, background, pause/resume |
| Live Activity/intents/timer | Original source, real extension build and IPA assembly | Signing, three views, round trips and timer |
| DSP/speed/pitch | Original engine and real vendor source | Every effect, presets/import, route changes |
| Music/control haptics | Original Chroma owner, duplicate Eevee callback excluded | Strength/follows, lifecycle, no doubled feedback |
| Gestures/blocked artists | Original source | Zone priority, seek/skip, list persistence |
| Privacy/remote flags | Original source + actual 9.1.88 table | Counters, typed overrides, forced flags, reset |
| Backup/reset | Original Chroma + integration allowlist | Export/import types, stock reset, account retained |
| Eevee bootstrap/customize | Original message types/modifiers/SwiftProtobuf | Free/paid account, schema fallback, config reload |
| Eevee feed filtering | Original transformer before Chroma lyric-card handling | Both transformations, no data loss/double completion |
| Eevee ad/upsell services | Adapted original checked runtime hooks | Startup activation, ad breaks, playback stability |
| True Shuffle/crossfade | Adapted original algorithms, exact selector evidence | Recommendation insertion, zero/positive duration |
| Clean sharing/rating block | Original pure cleaner + runtime adapters | Clipboard/share/deep links, prompts, persistence |
| Eevee-only glass profile/options | **NOT fully ported** | Preserve extra gradient/tab/header/customization choices |
| Eevee-only providers/karaoke options | **NOT fully ported** | Genius/SpicyLyrics/PetitLyrics, normalization/romanization/options |
| SponsorBlock/reporting | **NOT ported** | Categories, timing/skips, overlays, drafts/votes/submission |
| Remaining Eevee premium/session/ad/network/UI hooks | **NOT fully ported** | Explicit logout/invalidation, caches, popups, premium flags |
| Eevee icons/localization/experiments/diagnostics | **NOT fully represented** | Resource loading, original options/reset scopes |

## Architecture and limits

Chroma remains one visual owner with its native/redesigned separation. Eevee feed/account transforms share a bounded per-task collector in Chroma's actual delegate hooks. The first delegate that receives the response owns collection; subsequent delegates forwarding that same task pass through instead of swallowing its terminal callback. After release, callbacks re-enter the normal selector so Chroma's card-list handoff still works. Network errors retain original bytes/error; oversize bodies replay without Eevee transformation. Foundation boundary tests, including same-task delegate chaining, passed in the supplied cloud log. They have not executed locally because Apple Foundation/Xcode are unavailable; actual Spotify behavior is not established.

As in upstream Chroma, response headers may have reached the consumer before body transformation. Normalized transaction headers are internal, not emitted as a duplicate response callback. Consumer assumptions about Content-Length/task.response require device testing. New service hooks address Objective-C-exposed methods, not guessed Swift vtable offsets. Late registration retries cannot undo services already started.

Live Activity requires the separate extension and host App Intents metadata. The assembly script embeds both. Signing must retain/sign the extension. App Groups require actual matching entitlements; the real shim cannot fabricate entitlement grants. Widget/App Group behavior remains unverified.

The `.deb` is an IPA-injection container. Rootless jailbreak installation needs separate packaging, a selected loader and validation; none is inferred here.

## Acceptance remains unmet

There is **no newly compiled v5 dylib/.deb locally**, no successful v5 cloud run, installation or runtime pass. The connector returns 404 for private `paht25/cloud`, preventing upload/run from this session. The source kit supplies pinned Theos, real protobuf and extension builds, Debian validation and composition/service tests for the user's runner.

Remaining source integration is real work, beyond QA: Eevee-only groups above still need porting/conflict resolution. A passing v5 build establishes compilation/linking, not 100% feature parity or ad-free playback.
