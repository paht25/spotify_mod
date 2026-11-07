"""Package only source/resources/instructions needed by the private cloud build."""
import hashlib
import json
import pathlib
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
trees = ['.github', 'Sources', 'Tests', 'scripts', 'tools', 'Resources', 'Licenses', 'Compatibility', 'Generated', 'Integration/Chroma']
files = ['README.md', 'CHROMA-CORE-v5.vi.md', 'BUILD-ON-GITHUB.vi.md', 'BUILD-REVISION.txt', 'target.json', 'PRODUCT.md', 'DESIGN.md', 'BUILD-FIX1.vi.md', 'reports/cloud-v5-build-fix1.json', 'BUILD-FIX2.vi.md', 'reports/cloud-v5-build-fix2.json', 'reports/conflict-preflight-verification.json', 'BUILD-FIX3.vi.md', 'BUILD-FIX4.vi.md', 'reports/cloud-v5-build-fix4.json', 'reports/fix4-application-verification.json', 'BUILD-FIX5.vi.md', 'reports/cloud-v5-build-fix5.json', 'BUILD-FIX6.vi.md', 'reports/cloud-v5-build-fix6.json',
         'reports/UNIFIED-v5-STATUS.md', 'reports/unified-source-audit.json', 'reports/ipa-header-tests.json',
         'reports/FEATURES.md', 'reports/VERIFICATION.md', 'reports/DEPENDENCIES.md', 'reports/host-verification.json', 'reports/workflow-v5-validation.json']
selected = {root / f for f in files}
for tree in trees:
    selected.update(p for p in (root / tree).rglob('*') if p.is_file() and p.suffix.lower() not in {'.deb', '.dylib', '.ipa'} and not any(part in {'.git', '__pycache__', '.theos', 'build'} for part in p.relative_to(root).parts))
records = []
output = root / 'chroma-core-v5-9188.zip'
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for file in sorted(selected):
        if file.is_symlink():
            raise ValueError('Unexpected link in source kit: ' + str(file))
        relative = file.relative_to(root).as_posix()
        data = file.read_bytes()
        info = zipfile.ZipInfo(relative)
        info.create_system = 3
        executable = file.suffix in {'.sh', '.py'} or relative.endswith('/scripts/install')
        info.external_attr = (0o100755 if executable else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        package.writestr(info, data)
        records.append({'path': relative, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
    package.writestr('SOURCE-KIT-MANIFEST.json', json.dumps({'revision': 'chroma-core-v5-9188', 'compiledArtifact': False, 'runtimeVerified': False, 'files': records}, indent=2))
with zipfile.ZipFile(output) as package:
    assert package.testzip() is None
    manifest = json.loads(package.read('SOURCE-KIT-MANIFEST.json'))
    for item in manifest['files']:
        assert hashlib.sha256(package.read(item['path'])).hexdigest() == item['sha256']
    assert all(not name.endswith(('.ipa', '.deb', '.dylib')) for name in package.namelist())
report = {'file': str(output), 'files': len(records) + 1, 'bytes': output.stat().st_size,
          'sha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'zipCRC': 'PASS', 'allMemberHashes': 'PASS',
          'compiledArtifact': False, 'runtimeVerified': False}
(root / 'reports/v5-kit-verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
