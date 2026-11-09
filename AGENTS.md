# spotify_mod

The editable product source is under app/. It comes from PwEevee v3.1.6.1's
taurus-rc/source tree; upstream.lock.json records the exact origin.
Read app/docs/tweaks.md before changing hooks. Keep Native and Redesigned separate.
The user authorized importing the entire 0.23.0 Navbar option in r4. Preserve the existing
Now Playing and navbar dimensions, and every UI element outside this navbar/player option.
Do not replace the app executable, extensions, icons or other libraries when packaging.

Checks: bash scripts/check.sh. Full build: THEOS=/path/to/theos bash scripts/build-ipa.sh /path/base.ipa
Build automation is .github/workflows/build-ipa.yml. Keep the Actions token read-only.
Do not commit generated flag tables, IPA files, credentials, compiled libraries or build caches.
Report whether compilation, packaging and device UI checks actually ran.
