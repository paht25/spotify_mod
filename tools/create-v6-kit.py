"""Create a verified private source kit; never include Spotify or compiled tweaks."""
import hashlib
import json
import pathlib
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
revision = 'personal-v6-9190'
trees = ['.github', 'Sources', 'Tests', 'scripts', 'tools', 'Resources', 'Licenses',
         'Compatibility', 'Generated', 'Integration/Chroma', 'reports']
required = ['README.md', 'PERSONAL-v6.vi.md', 'BUILD-ON-GITHUB.vi.md',
            'BUILD-REVISION.txt', 'target.json', 'PRODUCT.md', 'DESIGN.md']
excluded_dirs = {'.git', '.theos', 'build', '__pycache__', 'node_modules'}
excluded_suffixes = {'.deb', '.dylib', '.ipa', '.o', '.a', '.pyc', '.zip'}
selected = {root / name for name in required}
for name in trees:
    for file in (root / name).rglob('*'):
        relative = file.relative_to(root)
        if any(part in excluded_dirs for part in relative.parts):
            continue
        if file.is_file() and file.suffix.lower() not in excluded_suffixes:
            if relative.as_posix().startswith('reports/v6-kit-'):
                continue  # A kit cannot contain its own final hash.
            selected.add(file)
records = []
output = root / (revision + '-source.zip')
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for file in sorted(selected):
        if file.is_symlink():
            raise ValueError('Unexpected source link: ' + str(file))
        relative = file.relative_to(root).as_posix()
        data = file.read_bytes()
        info = zipfile.ZipInfo(relative)
        info.create_system = 3
        executable = file.suffix in {'.sh', '.py'} or relative.endswith('/scripts/install')
        info.external_attr = (0o100755 if executable else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, data)
        records.append({'path': relative, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
    archive.writestr('SOURCE-KIT-MANIFEST.json', json.dumps({
        'revision': revision, 'compiledArtifact': False, 'appleCompilationVerified': False,
        'runtimeVerified': False, 'files': records}, indent=2))
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == len(set(archive.namelist()))
    for record in records:
        assert hashlib.sha256(archive.read(record['path'])).hexdigest() == record['sha256']
    assert all(pathlib.PurePosixPath(name).suffix.lower() not in excluded_suffixes for name in archive.namelist())
    for name in required:
        assert name in archive.namelist()
report = {'revision': revision, 'path': str(output), 'files': len(records) + 1,
          'bytes': output.stat().st_size, 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
          'zipCRC': 'PASS', 'allMemberHashes': 'PASS', 'compiledArtifact': False,
          'appleCompilationVerified': False, 'runtimeVerified': False}
(root / 'reports/v6-kit-verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
