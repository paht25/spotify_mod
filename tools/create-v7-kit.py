"""Package the active private source candidate; exclude supplied apps and binaries."""
import hashlib
import json
import pathlib
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
revision = 'personal-independent-v7-9190'
trees = ['.github', 'Sources', 'Tests', 'scripts', 'tools', 'Resources', 'Licenses',
         'Compatibility', 'Generated', 'Integration/Chroma', 'Reference/EeveeSpotify-6.6.8']
files = ['README.md', 'BUILD-v7.vi.md', 'BUILD-REVISION.txt', 'target.json', 'PRODUCT.md', 'DESIGN.md',
         'BASELINE-v6-MANIFEST.json', 'reports/FEATURES-v7.md', 'reports/VERIFICATION-v7.md',
         'reports/verification-v7.json', 'reports/input-inventory.json', 'reports/feature-inventory-v7.json',
         'reports/shared-target-candidates-v7.json', 'reports/eevee-dependencies-v7.json',
         'reports/eevee-6.6.8-source-comparison.json']
selected = {root / p for p in files}
skip = {'.git', '.theos', 'build', '__pycache__', 'node_modules', '.agents', '.claude', '.codex'}
binary = {'.deb', '.dylib', '.ipa', '.o', '.a', '.pyc', '.zip', '.exe', '.dll'}
for name in trees:
    for file in (root / name).rglob('*'):
        if any(p in skip for p in file.relative_to(root).parts):
            continue
        if file.is_file() and file.suffix.lower() not in binary:
            selected.add(file)
records = []
output = root / (revision + '-source.zip')
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for file in sorted(selected):
        if file.is_symlink():
            raise ValueError('Unexpected source link: ' + str(file))
        name = file.relative_to(root).as_posix()
        data = file.read_bytes()
        item = zipfile.ZipInfo(name)
        item.create_system = 3
        executable = file.suffix in {'.sh', '.py'} or name.endswith('/scripts/install')
        item.external_attr = (0o100755 if executable else 0o100644) << 16
        item.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(item, data)
        records.append({'path': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    archive.writestr('SOURCE-KIT-MANIFEST.json', json.dumps({
        'revision': revision, 'compiledArtifact': False, 'appleBuildVerified': False,
        'runtimeVerified': False, 'fullFeatureParity': False,
        'excludedByUser': ['Ambient playback', 'Sing/vocal separation'], 'syncedLyricsRetained': True,
        'files': records}, indent=2))
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == len(set(archive.namelist()))
    for record in records:
        assert hashlib.sha256(archive.read(record['path'])).hexdigest() == record['sha256']
    assert not any(pathlib.PurePosixPath(name).suffix.lower() in binary for name in archive.namelist())
    assert not any('/USAmbient.' in name for name in archive.namelist())
report = {'revision': revision, 'path': str(output), 'files': len(records) + 1,
          'bytes': output.stat().st_size, 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
          'zipCRC': 'PASS', 'allMemberHashes': 'PASS', 'appleBuildVerified': False,
          'deviceVerified': False, 'fullFeatureParity': False}
(root / 'reports/v7-kit-verification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
