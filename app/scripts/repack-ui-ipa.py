#!/usr/bin/env python3
"""Replace only spotifyglass.dylib in an existing IPA; signing is a separate step."""
import argparse
import copy
import hashlib
import re
import shutil
import struct
import zipfile
from pathlib import Path


def repack(ipa: Path, dylib: Path, output: Path) -> str:
    if output.resolve() in (ipa.resolve(), dylib.resolve()):
        raise ValueError("Output must be a new file, separate from both inputs")
    replacement = dylib.read_bytes()
    if len(replacement) < 32:
        raise ValueError("The replacement is not a compiled dylib")
    magic, cpu, _, kind = struct.unpack_from("<IIII", replacement)
    if (magic, cpu, kind) != (0xFEEDFACF, 0x0100000C, 6):
        raise ValueError("Expected a 64-bit ARM64 Mach-O dylib from the tweak build")
    with zipfile.ZipFile(ipa) as source:
        names = source.namelist()
        if len(set(names)) != len(names):
            raise ValueError("The input IPA has duplicate archive entries")
        targets = [n for n in names if re.fullmatch(r"Payload/[^/]+\.app/Frameworks/spotifyglass\.dylib", n)]
        if len(targets) != 1:
            raise ValueError("Expected exactly one existing spotifyglass.dylib in the IPA")
        target = targets[0]
        # Exclusive creation preserves the original IPA and any previous build.
        with output.open("xb") as stream:
            try:
                with zipfile.ZipFile(stream, "w") as result:
                    result.comment = source.comment
                    for entry in source.infolist():
                        info = copy.copy(entry)
                        if info.filename == target:
                            result.writestr(info, replacement)
                        else:
                            with source.open(entry) as old, result.open(info, "w") as new:
                                shutil.copyfileobj(old, new, length=1024 * 1024)
                # Audit all contents after repacking, including the executable, icons and extensions.
                with zipfile.ZipFile(output) as result:
                    if result.namelist() != names:
                        raise ValueError("Archive entry list changed unexpectedly")
                    for name in names:
                        expected = hashlib.sha256(replacement).digest() if name == target else digest(source, name)
                        if digest(result, name) != expected:
                            raise ValueError(f"Content verification failed: {name}")
            except BaseException:
                stream.close()
                output.unlink(missing_ok=True)
                raise
    return target


def digest(archive: zipfile.ZipFile, name: str) -> bytes:
    with archive.open(name) as stream:
        return hashlib.file_digest(stream, "sha256").digest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("dylib", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    target = repack(args.ipa, args.dylib, args.output)
    print(f"Replaced: {target}")
    print("Verified: every other archive entry has identical contents")
    print(f"Output: {args.output}")
    print("Re-sign this IPA with your normal sideloading tool before installing.")


if __name__ == "__main__":
    main()
