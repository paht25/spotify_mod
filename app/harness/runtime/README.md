# UIKit runtime regression suite

`scripts/test-runtime.sh` runs real touch gestures in an iPhone simulator using XCTest UI tests.
Only Spotify's data and navigation objects are fixtures. The bar, expanded player, native motion
driver, fade/profile hooks, appearance rows, SGModPage switch actions and Auto Layout are production
source files. No screenshot of this fixture proves the real Spotify hierarchy; device validation
remains required.

The suite checks the failure modes missed by compilation-only checks:

- Repeated Auto Layout passes preserve the card content and glass edges at the navbar width.
- UISwitch actions still persist and apply Appearance settings after leaving their table cells.
- Spotify's separately rendered TabBarGradientView stays transparent with the fade off.
- A genuine vertical drag moves the UIKit accessory and drives the existing navbar/player collapse;
  reversing the drag restores them. The original SGRSystemTabBar object and its four items survive.

The motion mechanism is cross-checked against the supplied evexpw 0.23.0 IPA and the upstream
v0.23.0-beta source at 49e02e204f397b1e4197876dd622d4ee1663188e. Its native controller is used
as an invisible geometry driver so the user's original expanded navbar is not substituted.
