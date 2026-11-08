# Personal Spotify extension

User: one private iOS user. Target: Spotify 9.1.90 build 919002269, iOS 27, Sideloadly. Keep Spotify sign-in and the user's account unchanged. No Chroma account, Plus membership check or proprietary Chroma backend is used by the new modules. Scope is eventual functional coverage of all observed Chroma 1.0.1 features and compatible Eevee functionality, including player, redesigned Liquid Glass UI and NavBar, not only paid extras. The user explicitly excluded ambient playback and Sing/vocal separation; synced lyrics must remain.

This is a scoped extension of the existing UIKit settings/player project. Its native/Redesigned visual worlds and settings navigation are established in Integration/Chroma and remain the authority. No new visual identity or marketing surface is requested. New personal controls belong inside Settings/sidebar -> Unified Spotify, not in a floating overlay. Real runtime states and error feedback only.

Baseline provenance correction: the public Chroma reference fetched under tag v0.51.0 declares version 0.22.0 and its changelog stops there. It must not be represented as the complete 0.51.0 or 1.0.1 implementation. The user previously confirmed permission for private integration of that source; upstream notices stay intact. New modules are independently authored from functional requirements, not decompiled Plus code or authentication patches. Missing feature behavior, models and server components stay explicit in the inventory.

Author promotional UI is excluded as requested; attribution and licenses remain. Preserve original input packages, baseline v6 artifacts and user preferences. No mock features, guessed successful tests or claim of full parity. New Apple compilation/device tests remain necessary.
