# Current v6 design context

Spotify 9.1.90/iOS 27. The integrated Chroma settings/page framework owns navigation and renders the native/redesigned profiles with separate keys; it replaces the earlier v4 settings surface described below. Original Chroma player, lyrics, glass UI and settings implementations are included, but have not received a v6 visual/device pass. One Unified Spotify entry is inside Settings/sidebar. Author promotions are removed, legal notices retained. Runtime diagnostics report actual mode, method implementation origin and player field creation rather than inferring success from class presence. An unsupported exact host build leaves hooks inactive.

The missing legacy player transition adapter is unresolved. Preserve one visual owner and native Dynamic Type/accessibility behavior. Confirm layout, tap targets, large text, dark/light appearance, player transitions and lyrics on a device before claiming UI correctness.

## Historical v4 context (superseded)

# Private mod settings surface

Operate mode, UIKit-native inset-grouped table inside UINavigationController. System semantic colors and Dynamic Type accommodate the device appearance, which has not been specified by the user. No custom brand fonts, gradients, animated decoration or invented status data.

Navigation as of v4: Unified Spotify row in Spotify's Settings root and side drawer; the floating button is removed by explicit user instruction. The row uses a native UIGlassEffect pane. Done dismisses the managed settings sheet, Refresh reads a fresh snapshot, Export opens the native share sheet. Hit targets are at least 44pt; multiline system text supports larger type and VoiceOver labels name the entry and each switch. This does not claim that Chroma's redesigned player or all Eevee glass surfaces have been ported. Row visibility, collection insets and sidebar presentation require device QA on 9.1.88.

Content hierarchy: implemented feature switches first, actual runtime state and counters second, diagnostic export last. Unsupported app versions or conflicting original dylibs leave the menu available with feature controls disabled and a reason in status. No placeholder rows for unfinished features. A footer states missing original feature families honestly.

QA: native render has not been observed for this iteration. Compilation and the user device screenshot must verify row wrapping, sheet behavior, dark/light appearance, VoiceOver and entry placement. Foundation tests cover sharing algorithms, C ownership bridges and concurrent counters; they do not establish UIKit visual correctness.
