# Proposed integration architecture

This is a design awaiting licensed implementation and testing. No module below is claimed to exist as a unified iOS implementation.

## Initialization and hook ownership

Use one dylib, one Spotify bundle filter and one initialization path. Resolve the exact Spotify version/build, device OS and loader before activation. Inspect runtime class identities and Objective-C method type encodings before installing hooks. Resolve Swift-qualified and mangled aliases to the same Class identity. The compatibility layer owns each `(Class, selector, instance/class method)` once. Feature modules register behavior with that owner rather than installing independent hooks or constructors.

The owner calls the original implementation according to a documented contract, then applies ordered feature operations. A generic chain that lets two interceptors both own response replay is insufficient. Different behaviors need domain-specific composition. Unsupported targets must be reported to the user and recorded as unavailable, never treated as passing acceptance or silently omitted.

## Proposed ownership contracts

| Service | Shared owner responsibility | Preservation rules |
|---|---|---|
| Spotify session/transport | Per-task response state machine, buffering, cancellation, redirects, completion disposition and exactly-once completion | Keep bootstrap/account/configuration, lyrics and privacy policies distinct; order transformations by response type; retain original bytes for diagnostic comparison |
| Lyrics | Track identity, source selection/fallback, timed lines/words, language, attribution, error state and caching | Retain every provider, timing and display choice; render from one model; no cross-track stale response delivery |
| Playback | One track/position/queue state stream with explicit main/audio/thread contracts | Lyrics, haptics, SponsorBlock and lock screen consume the stream; seek actions preserve user intent |
| Navigation/tab model | One tab descriptor store and URI navigation adapter | Preserve original custom tabs, titles/icons/order, launch-tab and hidden-tab options in distinct appearance profiles |
| Surface rendering | One selected renderer for player, mini player, tabs and page headers | Preserve Chroma native/redesigned and Eevee appearance option sets as explicit profiles; incompatible renderers are selectable alternatives rather than simultaneous overlays |
| Remote flags | Typed override registry with provenance, default/forced/user values and scope | Conflicts remain visible; precedence must be specified per setting rather than silently dropping one source |
| Preferences | Versioned schema, idempotent migrations, original namespaces and lossless backup | Do not flatten same-named keys until defaults, types and effects match; preserve secrets and SponsorBlock data separately |
| Settings UI | Single Spotify settings entry and navigator | Retain every original option and help/error workflow; explain mode/version restrictions; existing advanced/diagnostic pages remain reachable |
| Packaging/paths | One rootless path resolver, bundle lookup and dependency map | Avoid double `/var/jb`; preserve resource/module identities; RootHide must be a separate future configuration |

## Source integration steps

1. Resolve permission for Chroma v0.51.0 and a compatible distribution license with Eevee GPL obligations. Keep original copyright and vendor notices. Do not replace it with an earlier feature subset and call preservation complete.
2. Verify release-source-to-payload correspondence through version markers, resource comparisons and reproducible builds where possible. Obtain Spotify 9.1.90 class/selector/type-encoding evidence on the intended device. The original sources are not Spotify's own source.
3. Convert both sets of constructors/activation groups to explicit module registration. Audit manually installed swizzles, C rebinding, delayed initialization, generated Orion glue and global UIView hooks as well as indexed ClassHook/Logos declarations.
4. Implement the shared transport first, with real captured response fixtures and cancellation/304/error cases. Port existing transformation logic to it without altering options. Implement the lyrics and playback models next, then UI profiles and their shared navigation services.
5. Implement transactional settings migration and verify each legacy setting against the previous implementation. Keep Chroma's mode-specific keys distinct. Preserve defaults, restart requirements, import/export semantics, error presentation and reset scopes.
6. Stage one rootless dylib, filter, resource bundle, Metal shaders and genuine dependency frameworks. Live Activity needs its own extension entitlement and signing workflow; a jailbreak .deb alone must not be assumed to reproduce a sideloaded extension setup.
7. Require every feature and interaction checklist to pass before setting `releaseReady` or producing a release package. Record exact hashes, compiler/SDK/loader versions and device logs.

The design avoids simultaneous injection but does not itself resolve the conflicts. No conflict is marked fixed until actual merged code and runtime evidence support it.
