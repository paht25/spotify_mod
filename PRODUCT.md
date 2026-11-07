# Product context

User-requested private Spotify iOS integration of Chroma v0.51.0 and EeveeSpotify v7.0.0, preserving their full feature sets over the complete project. The user confirms permission for private Chroma integration. Public redistribution is not authorized by that confirmation.

Current target explicitly supplied by the user: iOS 27, Spotify 9.1.88, injection with Sideloadly. The earlier 9.1.90 target is superseded. Rootless was initially requested, but the immediate tested workflow is IPA injection. The user has a working cloud build runner and no local Apple toolchain.

The current native settings surface is an Operate surface: identify actual injection/hook state, enable implemented features, inspect counters and export diagnostics without account secrets. Native UIKit controls and Vietnamese labels match the user's conversation. No claim of completed Chroma UI, premium patching, lyrics or full integration is permitted until implementation and device testing exist.

The user now explicitly requests the entry inside Spotify Settings/sidebar and no external floating button. Chroma Liquid Glass redesign/player/lyrics/animated lock screen plus Eevee Premium patching remain required for the full goal. v4 ports the entry and configuration transform portion; it does not establish the full combined interface or feature set. Native Dynamic Type and system appearance are retained for the incremental settings surface, with actual iOS glass where available. Visual/runtime validation on 9.1.88 is outstanding.
