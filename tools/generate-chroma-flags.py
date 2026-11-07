"""Run Chroma's actual ARM64 Walker on the supplied 9.1.88 image.

Only its Binary input adapter is replaced: Objective-C metadata substitutes for
Apple nm, and Mach-O sections substitute for otool/strings on this Windows host.
Unknown types remain Unknown; no undocumented defaults are invented.
"""
import importlib.util, json, pathlib, re, struct, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
source = ROOT / 'upstream/Chroma-reference/scripts/extract-flags.py'
spec = importlib.util.spec_from_file_location('chroma_extractor', source)
upstream = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upstream)

class ProvidedBinary(upstream.Binary):
    def __init__(self):
        self.data = (ROOT / 'ipa-analysis/no-eevee/Payload/Spotify.app/Spotify').read_bytes()
        self.segs = []
        strings = []
        offset = 32
        for _ in range(struct.unpack_from('<I', self.data, 16)[0]):
            command, size = struct.unpack_from('<II', self.data, offset)
            if command == 25:
                vm, _, file, length = struct.unpack_from('<QQQQ', self.data, offset + 24)
                self.segs.append((vm, file, length))
                for j in range(struct.unpack_from('<I', self.data, offset + 64)[0]):
                    section = offset + 72 + 80 * j
                    if self.data[section:section+16].split(b'\0')[0] == b'__cstring':
                        addr, count = struct.unpack_from('<QQ', self.data, section + 32)
                        start = struct.unpack_from('<I', self.data, section + 48)[0]
                        strings.append((addr, start, count))
            offset += size
        self.keys = {}
        for vm, start, count in strings:
            pos = 0
            while pos < count:
                end = self.data.find(b'\0', start + pos, start + count)
                if end < 0: break
                raw = self.data[start+pos:end]
                if re.fullmatch(rb'ios-[a-z0-9-]+\.[A-Za-z0-9_.-]+', raw):
                    self.keys[vm+pos] = raw.decode('ascii')
                pos = end - start + 1
        records = json.loads((ROOT / 'ipa-analysis/reports/objc-properties.json').read_text())
        self.thunks = [int(method['implementationVM'], 16)
                       for cls in records['focused'] if 'Properties' in cls['name']
                       for method in cls.get('methods', [])
                       if method['selector'] == 'initWithConfigurationProvider:']

binary = ProvidedBinary()
flags, failures = {}, []
for thunk in binary.thunks:
    try:
        target = upstream.swift_init(binary, thunk)
        if not target: continue
        walker = upstream.Walker(binary)
        walker.run(target)
        for key, kind, a, b, c in walker.found:
            flags[key] = ((kind, a or 0, 0, 0) if kind == 'Bool' else
                          (kind, c or 0, a or 0, b or 0) if kind == 'Int' else
                          (kind, 0, 0, 0))
    except (struct.error, IndexError, ValueError) as error:
        failures.append({'thunk':hex(thunk), 'error':str(error)})
for key in binary.keys.values(): flags.setdefault(key, ('Unknown', 0, 0, 0))
out = ROOT / 'Generated/SGFlagList.m'
out.parent.mkdir(parents=True, exist_ok=True)
lines = ['// Generated from user-provided Spotify 9.1.88, build 918802209.',
         '// Chroma original ARM64 Walker; unknown defaults remain SGFlagUnknown.',
         '#import "Flags.h"', 'const SGFlagDef SGFlagTable[] = {']
for key, (kind, value, lower, upper) in sorted(flags.items()):
    lines.append(f'    {{"{key}", SGFlag{kind}, {upstream.signed(value)}, {upstream.signed(lower)}, {upstream.signed(upper)}}},')
lines += ['};', 'const NSUInteger SGFlagCount = sizeof(SGFlagTable) / sizeof(*SGFlagTable);', '']
out.write_text('\n'.join(lines), encoding='utf8')
report = {'spotify':'9.1.88', 'build':'918802209', 'flagKeys':len(flags),
          'typed':sum(value[0]!='Unknown' for value in flags.values()),
          'initializerThunks':len(binary.thunks), 'walkerFailures':failures,
          'method':'Original Chroma Walker with metadata-fed binary adapter',
          'runtimeVerified':False}
(out.parent / 'flag-extraction.json').write_text(json.dumps(report, indent=2), encoding='utf8')
print(json.dumps(report, indent=2))
