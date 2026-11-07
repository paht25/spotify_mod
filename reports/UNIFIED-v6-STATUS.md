# Feature comparison and verification — personal-v6-9190

Target: Spotify 9.1.90 build 919002269, iOS 27, ARM64, Sideloadly.
User-supplied IPA SHA-256: `2c34a2ebadb71888682b8fde89a706916fb3b9e06318794d5b6b26198acb6a7c`.
The executable has encryption cryptid 0. Source/reference versions are Chroma 0.51.0 and Eevee 7.0.0. Matching tagged source does not establish byte equivalence to the original Debian binaries.

## Actual evidence

- Original 47 payload/staged files: hashes match; neither original extracted directory changed or original Debian re-extracted.
- Chroma source inventory: all 278 original files remain present. Donation, author release promotion and author usage modules are intentionally excluded from compilation as requested. Legal notices remain.
- Original ARM64 flag walker on the supplied 9.1.90 image: 547 initializer thunks; 2,523 keys; 2,361 typed; 162 unknown; zero reported walker failures. Unknown defaults remain unknown.
- Static class audit: 137 of 139 Spotify hook declarations have a class in the inspected main/shared images. The two missing declarations both reference `SPTBarOverlayPresentationTransition`; original player/bar morph is unresolved. This is class presence, not all-selector or behavior validation.
- Two original redesigned-playlist flag strings (`use_collection_view`, `pin_curation_actions` under `ios-feature-freetierplaylist`) are absent from the extracted table and raw main-image UTF-8 strings. Their old references are retained; equivalent 9.1.90 layout behavior is not established. Other literal redesign flag references are present in the extracted table; dynamically assembled names still need investigation.
- Eight ad-policy selector/type contracts match 9.1.90 metadata, including the initializer with its opaque scheduler pointer. Nine Eevee service targets have an own `load` selector; inherited/lazy/category methods still require runtime inspection.
- All 87 Logos source files preprocess; source layering passes; source conflict preflight passes. These do not compile or execute Objective-C/UIKit.
- In-memory header insertion on the actual supplied main/widget images: both dependencies fit verified padding; code sections stay identical; duplicate insertion is idempotent; nonzero padding is rejected. No IPA/signature/runtime result follows.
- User reports **v5**, not v6, starts but has broken Redesigned and audible ads. Prior counters 1/1/9/9 establish activity in selected paths only; the selected response may have been a feed response. V6 now counts response categories separately.

## Feature-by-feature checklist

Every row below still needs device verification on **9.1.90**. “Integrated source” means a real implementation is included, not that its runtime behavior passed.

| Feature/options | Implementation and reconciliation | V6 verification |
|---|---|---|
| Settings/sidebar entry, navigation | Original Chroma page protocol/entry; one Unified Spotify root; no floating button | Pending |
| Native/Redesigned selection | Separate original renderers/keys; switch default aligned; reset marker cleared on explicit enable; launch choice remains stable | Pending; v5 issue reported |
| Native AMOLED, accent, header/edge controls | Original Native source/settings retained | Pending |
| Redesigned Liquid Glass, black field, accent | Original Redesigned source/settings; real iOS glass APIs; host compatibility disabled at assembly | Pending; no visual pass |
| Tab layout/editor/custom navigation | Original Chroma native and redesigned models/settings | Pending; Eevee-exclusive tab options not fully ported |
| Glass mini-player/device button | Original Chroma mini-player, separate native/redesign settings | Pending |
| Player artwork, moving background, header/buttons/scrubber/cards | Original Chroma Player files/settings and shared state included | Pending; player-field creation now recorded |
| Mini-player/player artwork morph | Original transition implementation retained, referenced Spotify class absent | **Unresolved adapter** |
| Player declutter/queue/devices/context menu | Original implementations/flag controls retained | Pending |
| Home gradient/sections, redesigned shelves/shortcuts | Original two profiles retained | Pending |
| Search category glass and filtering | Original Redesigned implementation retained | Pending |
| Library header/search/artwork/rows | Original implementation and filter chip behavior retained | Pending |
| Playlist, liked songs, album layouts/hide options | Original Native/Redesigned pages retained | Pending |
| Artist layout/metadata/hiding | Original two profiles retained | Pending |
| Lyrics providers/order/cache/fallback | Chroma BiniLyrics, Unison, NetEase, Musixmatch, LRCLIB and TTML retained | Pending live provider/network tests |
| Lyrics donor request/card insertion | Actual Chroma transport retained; Eevee feed transform precedes Chroma card pass | Pending real responses |
| Word/line sync, duet/backing vocals | Original Chroma lyric timing/model/rendering | Pending |
| Translation/pronunciation/text sizes | Original lyrics model/settings retained | Pending |
| Lyrics meanings/annotations | Original Chroma meanings workflow retained | Pending |
| Lock-screen lyrics | Original shared system now-playing hook | Pending lock/unlock/track changes |
| Animated lock-screen Canvas/Apple artwork | Original providers/download/crop/cache/order | Pending provider/system behavior |
| Live Activity lyrics/queue/control/timer views | Actual extension and intents build path retained | Pending compile/embed/sign/device controls |
| Speed/pitch menu and audio processing | Original audio unit implementation retained | Pending playback/route changes |
| DSP chain/files/presets/effects | Actual vendor C and original processing/settings retained | Pending real audio/imports/CPU |
| Control/music haptics | Chroma owns one set of callbacks; duplicate Eevee haptic hook omitted to avoid double feedback | Pending |
| Gestures and zones | Original Chroma recognizer/actions/settings | Pending; Eevee-exclusive options incomplete |
| Artist blocking | Original storage/skip workflow | Pending |
| Privacy/telemetry/clutter | Original Chroma policy/settings | Pending; verify playback/session unaffected |
| Flag browser/overrides/Labs | Generated 9.1.90 table; original typed controls and profile precedence | Static extraction passed; runtime pending |
| Eevee bootstrap/customize patching | Real original algorithms/generated protobuf; one composed transaction; option to disable/overwrite | New build/runtime pending; backend rights not established |
| Audio ads between tracks | New narrowly activated ad-only product-state constructor/setters/getters and adsEnabled gate | **Not audibly tested; not verified fixed** |
| Eevee ad/upsell service loads | Reviewed original targets with registry/ABI checks and startup retries | Pending; v5 service counters did not prove audio blocking |
| Feed promotion filtering | Actual Eevee transformer composed ahead of Chroma | Pending 9.1.90 payload schema |
| True Shuffle/crossfade duration | Ported real service hooks with runtime checks | Pending |
| Share link cleaning/rating prompts | Actual Eevee cleaner/utility hooks | Pending |
| Settings export/import/reset/migration | Original namespaces retained; unified/Eevee allowlist included; reset remains stock | Pending persistence and relaunch |
| Author donate/update/Discord/usage | Removed from active product UI/build; attribution/licenses retained | Source exclusion verified; compiled/runtime inspection pending |
| Eevee-specific glass/UI/icon/flag-browser options | Not all represented in the unified settings | **Incomplete** |
| Eevee extra providers/karaoke/romanization | Not fully ported into the shared lyrics model | **Incomplete** |
| SponsorBlock skip/report/vote/stores | No completed integrated implementation | **Incomplete** |
| Eevee session protection/remaining premium behavior | Partial account patching exists; full workflow not reconciled | **Incomplete** |

## Build and runtime acceptance

New Foundation tests exercise production ad-policy code with test-only classes: immutable input, preserve country/streaming/offline/quality/account fields, only ad values changed, disabled forwarding, hook idempotence and original call paths. They are added to CI but **have not been executed on this Windows host**. Previous cloud component test passes are historical and cannot be carried forward as v6 passes.

V6 Apple compilation, new Foundation/Swift suite, `.deb` production, installation, startup, settings persistence, rendered UI, provider output, audio stability, live lock-screen behavior and audible ad blocking: **pending**. No v6 compiled artifact is fabricated. Source ZIP hashes/CRC are recorded separately when the ZIP is created.

On device, compare both looks and every enabled option against original behavior, cover offline/online/error states, local files/podcasts/remote playback, track changes and audio routes. Exercise switch-off paths and verify restart persistence. Export diagnostics after opening the player and encountering an ad opportunity. Increased hook/counter values alone are insufficient for acceptance.

To resolve the missing transition, identify the actual 9.1.90 transition object's context, artwork/bar geometry and progress lifecycle. The observed Swift transition methods do not supply the old API contract, so a name-based substitution is not justified. Remaining Eevee groups require source integration, reconciled settings/resources and their own device checks. The requested 100% combined functionality is **not complete**.
