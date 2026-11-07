# Product context

User-requested private Spotify iOS integration of Chroma v0.51.0 and EeveeSpotify v7.0.0, preserving their full feature sets over the complete project. The user confirms permission for private Chroma integration. Public redistribution is not authorized by that confirmation.

Target explicitly supplied by the user: iOS 27, Spotify 9.1.90, injection with Sideloadly. Rootless was initially requested, but the immediate tested workflow is IPA injection. The user has a working cloud build runner and no local Apple toolchain.

The current native settings surface is an Operate surface: identify actual injection/hook state, enable implemented features, inspect counters and export diagnostics without account secrets. Native UIKit controls and Vietnamese labels match the user's conversation. No claim of completed Chroma UI, premium patching, lyrics or full integration is permitted until implementation and device testing exist.

Assumptions for this iteration: system light/dark appearance, Dynamic Type and the app's existing scene/window are used. A temporary visible Mod button provides access because the Spotify settings integration is not yet ported. Its placement is subject to user device QA, not claimed validated visually here.
