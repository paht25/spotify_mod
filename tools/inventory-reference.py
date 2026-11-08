"""Group observed binary interface evidence; never infer a successful feature test."""
import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
read = lambda p: json.loads((root / p).read_text(encoding='utf-8'))
save = lambda p, value: (root / p).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
keys = read('reports/chroma-preference-literals.json')
classes = read('reports/chroma-objc.json')['classes']
binary = read('reports/binary-details.json')
spec = '''sing|Sing / vocal separation / spatial voice|spotifyglass.sing,spotifyglass.redesign.sing,spotifyglass.redesign.spatialVoice|excluded_by_user
ambient|Ambient playback|spotifyglass.ambient|excluded_by_user
player|Full player, controls, cover, layout|spotifyglass.redesign.player.,spotifyglass.player,spotifyglass.hide.shuffle,spotifyglass.hide.repeat,spotifyglass.hide.queue,spotifyglass.hide.connect,spotifyglass.hide.share,spotifyglass.hide.addTo,spotifyglass.hide.videoSwitch|older_baseline_present_1_0_1_parity_pending
navbar|NavBar, custom tabs, inline mini-player|spotifyglass.navbar,spotifyglass.redesign.navbar,spotifyglass.redesign.inlinePlayer,spotifyglass.custom-tab,spotifyglass.tab.|older_baseline_present_inline_mini_player_pending
lyrics|Synced lyrics, word timing, translation, pronunciation, text styles|spotifyglass.redesign.lyrics,spotifyglass.lyrics,spotifyglass.karaoke,spotifyglass.neteaseWordTiming,spotifyglass.musixmatch,spotifyglass.spicyLyricsKey,spotifyglass.meanings.|older_baseline_partial_extra_providers_and_shaders_pending
lockscreen|Lock-screen lyrics, animated artwork, CSS styles|spotifyglass.lockscreen.,spotifyglass.lockScreenLyrics|older_baseline_partial_css_engine_missing
liveactivity|Live Activity, queue, controls, sleep timer|spotifyglass.liveActivity,spotifyglass.liveactivity,spotifyglass.redesign.liveActivity|older_baseline_present_signing_device_pending
visualizer|Audio-reactive shaders, parameters, shuffle|spotifyglass.visualizer|independent_spectrum_tests_passed_apple_build_device_pending
audio|DSP, headphone correction, per-output audio presets|spotifyglass.dsp|baseline_dsp_and_independent_local_import_device_pending
automix|Native AutoMix, crossfade, queue/context rules|spotifyglass.automix,spotifyglass.mixes_into,spotifyglass.queued_from,spotifyglass.replay|native_automix_adapter_missing_crossfade_only
font|App-wide font selection|spotifyglass.font|independent_registration_and_override_device_pending
gestures|Player taps, hold, head gestures, keyboard shortcuts|spotifyglass.gestures,spotifyglass.press,spotifyglass.keyboardShortcuts|older_tap_baseline_present_hold_head_shortcuts_pending
haptics|Control/music haptics, follow, latency|spotifyglass.haptics,spotifyglass.redesign.haptics,spotifyglass.music-haptics|older_baseline_present_extensions_pending
home|Home hero, shortcuts, top picks, suggestions, previews|spotifyglass.home,spotifyglass.redesign.home,spotifyglass.hide.home,spotifyglass.redesign.hero,spotifyglass.hero,spotifyglass.redesign.applehero|older_baseline_partial_new_hero_and_picks_pending
artist|Artist photos, logos, liked songs, hiding|spotifyglass.redesign.artist,spotifyglass.hide.artist,spotifyglass.artist|older_baseline_partial_logos_motion_pending
album|Album artwork, notes, play counts, controls|spotifyglass.redesign.album,spotifyglass.album,spotifyglass.hide.album|older_baseline_partial_new_options_pending
playlist|Playlist cover, find, pills, control menus|spotifyglass.redesign.playlist,spotifyglass.playlist,spotifyglass.hide.playlist|older_baseline_present_version_flags_pending
library|Library header, filters, sorting and artwork|spotifyglass.redesign.library,spotifyglass.library|older_baseline_partial
search|Search categories, videos, spacing and field|spotifyglass.redesign.search,spotifyglass.search|older_baseline_partial
web|Browser/TV display, lyrics, controls and layout|spotifyglass.webPlayer|independent_private_lan_source_apple_build_device_pending
localfiles|Local files, metadata, artwork and search|spotifyglass.localfiles|not_recreated
stats|Listening history, statistics and transfer|spotifyglass.stats|not_recreated
translation|Custom translation provider / Gemini configuration|spotifyglass.gemini,spotifyglass.translate|provider_embedded_translation_only_custom_service_pending
speedpitch|Speed/pitch, per-song persistence|spotifyglass.speedPitch,spotifyglass.playbackRate|session_baseline_present_per_song_pending
privacy|Privacy, telemetry, promotional clutter|spotifyglass.privacy,spotifyglass.adblock,spotifyglass.hideExplicit|baseline_and_composed_eevee_filters_present_device_pending
flags|Remote flags, experiments and overrides|spotifyglass.flag,spotifyglass.redesign.smoothFlags|baseline_table_regenerated_for_9_1_90_runtime_pending
appearance|Liquid Glass, accent, page looks and UI controls|spotifyglass.redesign.,spotifyglass.accent,spotifyglass.amoled,spotifyglass.reveal,spotifyglass.card.,spotifyglass.standin,spotifyglass.marquee|older_baseline_partial_1_0_1_controls_pending
artwork|Artwork lookups, source order and cache|spotifyglass.artwork,spotifyglass.applelookups|older_baseline_partial
infrastructure|Settings, caches, events, onboarding and diagnostics|spotifyglass.|evidence_only_not_all_literals_are_features'''
assigned = set()
features = []
for line in spec.splitlines():
    ident, title, patterns, status = line.split('|')
    prefixes = patterns.split(',')
    matched = [k for k in keys if k not in assigned and any(k.startswith(p) for p in prefixes)]
    assigned.update(matched)
    features.append({'id': ident, 'title': title, 'status': status,
                     'referencePreferenceLiterals': matched, 'deviceVerified': False})
assert assigned == set(keys)
report = {'scope': 'All observed families except ambient and Sing; synced lyrics explicitly retained',
          'referenceIPA': 'chroma-1.0.1.ipa', 'spotify': '9.1.90', 'build': '919002269',
          'preferenceLiterals': len(keys), 'objcClasses': len(classes), 'fullParity': False,
          'runtimeTests': 0, 'features': features,
          'caveat': 'Class/literal evidence is not exhaustive behavior, a verified Plus/free classification or proof of execution. Dynamic/hidden behavior remains unverified.'}
save('reports/feature-inventory-v7.json', report)

def normalize(name):
    m = re.fullmatch(r'_TtC(\d+)(.*)', name)
    if not m:
        return name
    size = int(m[1]); module = m[2][:size]; remainder = m[2][size:]
    n = re.match(r'(\d+)(.*)', remainder)
    return module + '.' + n[2][:int(n[1])] if n else name

chroma = binary['Payload/Spotify.app/Frameworks/spotifyglass.dylib']['slices'][0]
strings = [s for section in chroma['sections'] if section['name'] == '__cstring' for s in section.get('strings', [])]
targets = {normalize(s) for s in strings if re.fullmatch(r'(?:SPT[A-Za-z0-9_]+|_TtC[A-Za-z0-9_]+|[A-Za-z0-9_]+Impl\.[A-Za-z0-9_]+)', s)}
cross = []
for file in (root / 'Reference/EeveeSpotify-6.6.8/Sources').rglob('*.x.swift'):
    text = file.read_text(encoding='utf-8')
    candidates = set(re.findall(r'ClassHook<([\w.]+)>', text)) | set(re.findall(r'"((?:SPT|_TtC)[\w]+|[\w]+Impl\.[\w]+)"', text))
    shared = sorted(c for c in candidates if normalize(c) in targets)
    if shared:
        cross.append({'file': file.relative_to(root).as_posix(), 'sharedTargetCandidates': shared})
save('reports/shared-target-candidates-v7.json', {'files': cross, 'caveat': 'Lexical shared target only; runtime selector/ABI/version activation checks still required.'})
eevee = binary['var/jb/Library/MobileSubstrate/DynamicLibraries/EeveeSpotify.dylib']['slices'][0]
save('reports/eevee-dependencies-v7.json', {
    'version': '6.6.8', 'sourceCommit': '0d846646922231d5367e1625764835826f807e5d',
    'layout': 'rootless /var/jb', 'dependencies': eevee['deps'],
    'orionRequiredImports': len([i for i in eevee['imports'] if 'Orion.framework' in (i.get('library') or '')]),
    'orionIncludedInNewInputs': False,
    'strategy': 'One integrated source image; original Chroma 1.0.1/Eevee binaries are not loaded. No placeholder Orion.',
    'sameModelFilesAs668': ['Account.pb.swift', 'BootstrapMessage+Extension.swift', 'UcsResponse+Extension.swift', 'EeveePropertyReplacement.swift'],
    'newerFiltersRetained': True, 'full668Parity': False})
print(json.dumps({'families': len(features), 'literalsAssigned': len(assigned), 'sharedTargetFiles': len(cross), 'fullParity': False}, indent=2))
