# v5 source, build and runtime status

Target: user-supplied Spotify 9.1.88 build 918802209, iOS 27, private IPA injection with Sideloadly. This supersedes 9.1.90/rootless packaging for this artifact. No original .deb was re-extracted. User permission for private Chroma integration is recorded in the conversation; public redistribution rights are not inferred.

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

Chroma remains one visual owner with its native/redesigned separation. Eevee feed/account transforms share a bounded per-task collector in Chroma's actual delegate hooks. The first delegate that receives the response owns collection; subsequent delegates forwarding that same task pass through instead of swallowing its terminal callback. After release, callbacks re-enter the normal selector so Chroma's card-list handoff still works. Network errors retain original bytes/error; oversize bodies replay without Eevee transformation. New Foundation tests exercise these boundaries, including same-task delegate chaining; they have **not executed locally** because Apple Foundation/Xcode are unavailable.

As in upstream Chroma, response headers may have reached the consumer before body transformation. Normalized transaction headers are internal, not emitted as a duplicate response callback. Consumer assumptions about Content-Length/task.response require device testing. New service hooks address Objective-C-exposed methods, not guessed Swift vtable offsets. Late registration retries cannot undo services already started.

Live Activity requires the separate extension and host App Intents metadata. The assembly script embeds both. Signing must retain/sign the extension. App Groups require actual matching entitlements; the real shim cannot fabricate entitlement grants. Widget/App Group behavior remains unverified.

The `.deb` is an IPA-injection container. Rootless jailbreak installation needs separate packaging, a selected loader and validation; none is inferred here.

## Acceptance remains unmet

There is **no newly compiled v5 dylib/.deb locally**, no successful v5 cloud run, installation or runtime pass. The connector returns 404 for private `paht25/cloud`, preventing upload/run from this session. The source kit supplies pinned Theos, real protobuf and extension builds, Debian validation and composition/service tests for the user's runner.

Remaining source integration is real work, beyond QA: Eevee-only groups above still need porting/conflict resolution. A passing v5 build establishes compilation/linking, not 100% feature parity or ad-free playback.
