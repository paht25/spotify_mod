"""Embed a genuinely built v5 artifact into the supplied clean Spotify 9.1.88.

This prepares an UNSIGNED IPA for Sideloadly. It never signs, installs, downloads
Spotify, modifies the input, or extracts either original Debian package.
"""
import argparse
import copy
import hashlib
import json
import pathlib
import plistlib
import struct
import zipfile


def load_dylib(data, name):
    if len(data) < 32 or struct.unpack_from('<I', data)[0] != 0xFEEDFACF:
        raise ValueError(f'{name}: expected thin Mach-O')
    if struct.unpack_from('<I', data, 4)[0] != 0x100000C or struct.unpack_from('<I', data, 12)[0] != 6:
        raise ValueError(f'{name}: expected ARM64 MH_DYLIB')


def insert_load(data, name):
    """Add a strong dependency in verified zero padding, preserving ordinals.

    Unlike silently skipping a missing library, a required dependency fails to
    load visibly. Existing dependency ordinals are retained by appending only.
    """
    data = bytearray(data)
    if len(data) < 32 or struct.unpack_from('<I', data)[0] != 0xFEEDFACF:
        raise ValueError('Unsupported executable format')
    ncmds, sizeofcmds = struct.unpack_from('<II', data, 16)
    end = 32 + sizeofcmds
    if end > len(data):
        raise ValueError('Invalid Mach-O load-command region')
    first = len(data)
    off = 32
    for _ in range(ncmds):
        if off + 8 > end:
            raise ValueError('Truncated Mach-O command')
        cmd, size = struct.unpack_from('<II', data, off)
        if size < 8 or off + size > end:
            raise ValueError('Invalid Mach-O command size')
        if cmd in (0xC, 0x80000018, 0x8000001F):
            string_off = struct.unpack_from('<I', data, off + 8)[0]
            if data[off + string_off:off + size].split(b'\0')[0] == name.encode():
                return bytes(data)
        if cmd == 0x19:
            count = struct.unpack_from('<I', data, off + 64)[0]
            if 72 + count * 80 > size:
                raise ValueError('Truncated section table')
            for j in range(count):
                at = struct.unpack_from('<I', data, off + 72 + j * 80 + 48)[0]
                if at:
                    first = min(first, at)
        if cmd in (0x21, 0x2C) and struct.unpack_from('<I', data, off + 16)[0] != 0:
            raise ValueError('Encrypted input cannot be modified')
        off += size
    if off != end:
        raise ValueError('Load-command count/size mismatch')
    raw = name.encode() + b'\0'
    size = (24 + len(raw) + 7) & ~7
    if end + size > first or any(data[end:end + size]):
        raise ValueError('Not enough verified zero header padding for injection')
    command = struct.pack('<IIIIII', 0xC, size, 24, 2, 0x10000, 0x10000) + raw
    data[end:end + size] = command.ljust(size, b'\0')
    struct.pack_into('<II', data, 16, ncmds + 1, sizeofcmds + size)
    return bytes(data)


def assemble(base, artifact, output):
    if base.resolve() == output.resolve() or output.exists() or output.with_suffix('.json').exists():
        raise ValueError('Choose a new output path; existing files are not overwritten')
    # Artifacts can be an extracted directory or the downloaded GitHub ZIP.
    archive = zipfile.ZipFile(artifact) if artifact.is_file() else None

    def get(relative):
        key = pathlib.PurePosixPath(relative)
        if key.is_absolute() or '..' in key.parts:
            raise ValueError('Unsafe artifact member')
        if archive:
            return archive.read(relative)
        file = (artifact / relative).resolve()
        if not file.is_relative_to(artifact.resolve()):
            raise ValueError('Artifact member escapes the selected directory')
        return file.read_bytes()

    try:
        main = get('spotifyglass.dylib')
        groups = get('SpotifyGlassAppGroups.dylib')
        load_dylib(main, 'spotifyglass'); load_dylib(groups, 'AppGroups')
        for marker in (b'USUnifiedComplete', b'SGRKaraokeView'):
            if marker not in main:
                raise ValueError('This is not the full-source Chroma integration artifact')
        manifest = json.loads(get('package-manifest.json'))
        if manifest['revision'] != 'chroma-core-v5-9188':
            raise ValueError('Artifact revision mismatch')
        for item in manifest['supportFiles']:
            if hashlib.sha256(get(item['name'])).hexdigest() != item['sha256']:
                raise ValueError('Live Activity/support artifact hash mismatch: ' + item['name'])
        hashes = {item['name'].rsplit('/', 1)[-1]: item['sha256'] for item in manifest['files']}
        for name, data in [('spotifyglass.dylib', main), ('SpotifyGlassAppGroups.dylib', groups)]:
            if hashlib.sha256(data).hexdigest() != hashes[name]:
                raise ValueError(f'Artifact hash mismatch: {name}')
        prefix = 'live-activity/SpotifyGlassLiveActivity.appex/'
        names = archive.namelist() if archive else [p.relative_to(artifact).as_posix() for p in artifact.rglob('*') if p.is_file()]
        extension = {n[len(prefix):]: get(n) for n in names if n.startswith(prefix) and not n.endswith('/')}
        ext_info = plistlib.loads(extension['Info.plist'])
        if ext_info['CFBundleIdentifier'] != 'com.spotify.client.liveactivity':
            raise ValueError('Live Activity host bundle mismatch')
        if 'SpotifyGlassLiveActivity' not in extension:
            raise ValueError('Live Activity executable is missing')
        with zipfile.ZipFile(base) as src:
            names = src.namelist()
            infos = [n for n in names if n.startswith('Payload/') and n.count('/') == 2 and n.endswith('.app/Info.plist')]
            if len(infos) != 1 or len(names) != len(set(names)):
                raise ValueError('Expected one app and no ambiguous duplicate ZIP paths')
            info_path = infos[0]; app = info_path[:-len('Info.plist')]
            info = plistlib.loads(src.read(info_path))
            if (info['CFBundleIdentifier'], info['CFBundleShortVersionString'], info['CFBundleVersion']) != ('com.spotify.client', '9.1.88', '918802209'):
                raise ValueError('Expected the supplied Spotify 9.1.88 build 918802209')
            if any(any(x in n.lower() for x in ['eeveespotify.dylib', 'spotifyglass.dylib', 'orion.framework', 'unifiedspotifyexperimental.dylib']) for n in names):
                raise ValueError('Use the clean NoEevee input, not a previously injected IPA')
            executable = app + info['CFBundleExecutable']
            original = src.read(executable)
            if hashlib.sha256(original).hexdigest() != '350486650016ca445c296d97411e0466f495eb1d4edf040afe927b850aa30128':
                raise ValueError('Main executable differs from the inspected clean IPA')
            patched = insert_load(original, '@executable_path/Frameworks/spotifyglass.dylib')
            patched = insert_load(patched, '@executable_path/Frameworks/SpotifyGlassAppGroups.dylib')
            info['UIDesignRequiresCompatibility'] = False
            info['NSSupportsLiveActivities'] = True
            changes = {info_path: plistlib.dumps(info, fmt=plistlib.FMT_BINARY), executable: patched,
                       app + 'Frameworks/spotifyglass.dylib': main, app + 'Frameworks/SpotifyGlassAppGroups.dylib': groups}
            modes = {executable: 0o755, app + 'Frameworks/spotifyglass.dylib': 0o755, app + 'Frameworks/SpotifyGlassAppGroups.dylib': 0o755}
            for name, data in extension.items():
                if name.startswith('/') or '..' in pathlib.PurePosixPath(name).parts:
                    raise ValueError('Unsafe extension member')
                target = app + 'PlugIns/SpotifyGlassLiveActivity.appex/' + name
                changes[target] = data
                modes[target] = 0o755 if name == ext_info['CFBundleExecutable'] else 0o644
            metadata = app + 'Metadata.appintents/extract.actionsdata'
            added = json.loads(get('live-activity/app/Metadata.appintents/extract.actionsdata'))
            if metadata in names:
                original_meta = json.loads(src.read(metadata))
                original_meta['actions'] = {**original_meta['actions'], **added['actions']}
                changes[metadata] = json.dumps(original_meta).encode()
            else:
                changes[metadata] = json.dumps(added).encode()
                changes[app + 'Metadata.appintents/version.json'] = get('live-activity/app/Metadata.appintents/version.json')
            widget = app + 'PlugIns/WidgetExtension.appex/WidgetExtension'
            if widget in names:
                # An extension's Frameworks directory is not the host's. Use an
                # executable-relative path to the real companion in the host.
                changes[widget] = insert_load(src.read(widget), '@executable_path/../../Frameworks/SpotifyGlassAppGroups.dylib')
                modes[widget] = 0o755
            output.parent.mkdir(parents=True, exist_ok=True)
            created = False
            try:
                # Atomic exclusive creation: failure cannot remove a pre-existing
                # output that another process created after the initial check.
                with output.open('xb') as stream, zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as dst:
                    created = True
                    for item in src.infolist():
                        entry = copy.copy(item)
                        if item.filename in changes:
                            data = changes.pop(item.filename)
                            if item.filename in modes:
                                entry.create_system = 3; entry.external_attr = (0o100000 | modes[item.filename]) << 16
                            dst.writestr(entry, data)
                        else:
                            dst.writestr(entry, src.read(item))
                    for name, data in changes.items():
                        entry = zipfile.ZipInfo(name); entry.create_system = 3
                        entry.external_attr = (0o100000 | modes.get(name, 0o644)) << 16
                        entry.compress_type = zipfile.ZIP_DEFLATED
                        dst.writestr(entry, data)
                with zipfile.ZipFile(output) as checked:
                    if checked.testzip() is not None:
                        raise ValueError('Output ZIP CRC validation failed')
            except BaseException:
                if created and output.exists():
                    output.unlink()  # Only the new partial output created above.
                raise
            report = {'output': str(output), 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
                      'baseSHA256': hashlib.sha256(base.read_bytes()).hexdigest(), 'revision': manifest['revision'],
                      'signedForInstallation': False, 'runtimeTested': False,
                      'next': 'Sign the prepared IPA with Sideloadly; retain and sign the Live Activity extension. Do not inject the same dylib/deb again.'}
            output.with_suffix('.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
            print(json.dumps(report, indent=2))
    finally:
        if archive:
            archive.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=pathlib.Path, required=True)
    parser.add_argument('--artifact', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    options = parser.parse_args()
    assemble(options.base, options.artifact, options.output)
