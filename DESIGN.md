# Private mod settings surface

Operate mode, UIKit-native inset-grouped table inside UINavigationController. System semantic colors and Dynamic Type accommodate the device appearance, which has not been specified by the user. No custom brand fonts, gradients, animated decoration or invented status data.

Navigation: visible Mod button in the active application window; Done dismisses settings, Refresh reads a fresh snapshot, Export opens the native share sheet. Hit targets are at least 44pt; multiline system text supports larger type and VoiceOver labels name the entry and each switch. The floating entry must be assessed on the actual Spotify screen for obstruction.

Content hierarchy: implemented feature switches first, actual runtime state and counters second, diagnostic export last. Unsupported app versions or conflicting original dylibs leave the menu available with feature controls disabled and a reason in status. No placeholder rows for unfinished features. A footer states missing original feature families honestly.

QA: native render has not been observed for this iteration. Compilation and the user device screenshot must verify row wrapping, sheet behavior, dark/light appearance, VoiceOver and entry placement. Foundation tests cover sharing algorithms, C ownership bridges and concurrent counters; they do not establish UIKit visual correctness.
