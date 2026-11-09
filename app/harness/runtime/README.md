# UIKit runtime regression suite

`scripts/test-runtime.sh` runs real touch gestures in an iPhone simulator using XCTest UI tests.
Only Spotify's data and navigation objects are fixtures. The native tab controller and accessory,
fade/profile hooks, Navbar/Appearance rows, SGModPage switch actions and Auto Layout are production
source files. No screenshot of this fixture proves the real Spotify hierarchy; device validation
remains required.

The suite checks the failure modes missed by compilation-only checks:

- Repeated Auto Layout passes preserve the card content and glass edges at the navbar width.
- UISwitch actions still persist and apply Appearance settings after leaving their table cells.
- Spotify's separately rendered TabBarGradientView stays transparent with the fade off.
- The complete Navbar option persists across restart and selects the corresponding implementation.
- A genuine vertical drag collapses the visible native navbar and moves the same UIKit accessory
  between its tabs; reversing the drag restores the original expanded dimensions.
- Player taps, swipes and tab selection reach Spotify's fixture data/navigation objects.

The motion mechanism is cross-checked against the supplied evexpw 0.23.0 IPA and the upstream
v0.23.0-beta source at 49e02e204f397b1e4197876dd622d4ee1663188e. Its native controller is used
as the visible navbar and player, including its settings, gestures and native scroll transition.
The hidden standalone navbar supplies only the existing size baseline; it does not drive motion.
