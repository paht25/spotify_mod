"""Exercise actual supplied Mach-O header edits in memory, without emitting an IPA."""
import importlib.util
import hashlib
import json
import pathlib
import struct
import sys
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('assembler', root / 'tools/assemble-personal-ipa.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
base = pathlib.Path(sys.argv[1])
results = []
with zipfile.ZipFile(base) as ipa:
    for name in ('Payload/Spotify.app/Spotify', 'Payload/Spotify.app/PlugIns/WidgetExtension.appex/WidgetExtension'):
        if name not in ipa.namelist():
            continue
        before = ipa.read(name)
        dependency = ('@executable_path/../../Frameworks/SpotifyGlassAppGroups.dylib' if '.appex/' in name
                      else '@executable_path/Frameworks/spotifyglass.dylib')
        after = module.insert_load(before, dependency)
        assert len(before) == len(after)
        assert struct.unpack_from('<I', after, 16)[0] == struct.unpack_from('<I', before, 16)[0] + 1
        assert module.insert_load(after, dependency) == after
        # All original sections, including executable code, retain their bytes.
        off = 32
        for _ in range(struct.unpack_from('<I', before, 16)[0]):
            command, size = struct.unpack_from('<II', before, off)
            if command == 0x19:
                for i in range(struct.unpack_from('<I', before, off + 64)[0]):
                    p = off + 72 + 80 * i
                    length = struct.unpack_from('<Q', before, p + 40)[0]
                    position = struct.unpack_from('<I', before, p + 48)[0]
                    if position:
                        assert before[position:position + length] == after[position:position + length]
            off += size
        if '.appex/' not in name:
            both = module.insert_load(after, '@executable_path/Frameworks/SpotifyGlassAppGroups.dylib')
            assert struct.unpack_from('<I', both, 16)[0] == struct.unpack_from('<I', before, 16)[0] + 2
        obstructed = bytearray(before)
        end = 32 + struct.unpack_from('<I', before, 20)[0]
        obstructed[end] = 1
        try:
            module.insert_load(obstructed, dependency)
            raise AssertionError('Nonzero header padding was accepted')
        except ValueError:
            pass
        results.append({'image': name, 'dependency': dependency, 'headerInsertion': 'PASS', 'idempotence': 'PASS', 'originalSectionsUnchanged': True, 'requiredDependenciesFit': True, 'nonzeroPaddingRejected': True})
assert results, 'No actual supplied image was tested'
report = {'revision': 'personal-v6-9190', 'inputSHA256': hashlib.sha256(base.read_bytes()).hexdigest(), 'checks': results, 'outputIPAProduced': False, 'signingTested': False, 'runtimeTested': False}
(root / 'reports/ipa-header-tests.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
