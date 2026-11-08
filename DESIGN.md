# Existing native settings and player world

Extend the established Chroma-derived UIKit surface already present in this project. Mode: Operate for settings; Experience for the music player. Keep the native/Redesigned split, layer boundaries, system text sizes, dark glass panes and existing section/row interactions. Settings use SGModPage/SGPage to stay inside Spotify navigation. No separate dashboard, additional sign-in page or floating mod button.

New visualizer draws from real output samples and stays behind controls. Zero/absent audio must not be replaced by fake beats. Honor Reduce Motion, pause/background state, heat and low-power conditions; GPU work stops when the view leaves its window. Shader compile/import errors are visible and leave the built-in renderer available. Controls must keep normal tap targets and VoiceOver labels.

No iPhone visual preview is available locally. Record visual QA as pending; Logos preprocessing and C tests cannot verify layout or native glass rendering.
