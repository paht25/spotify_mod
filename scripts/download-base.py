#!/usr/bin/env python3
"""Download a hash-verified base IPA. Custom URLs require an explicit SHA-256."""
import argparse
import hashlib
import json
import os
import re
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def configuration(url: str, sha: str) -> tuple[str, str]:
    lock = json.loads((ROOT / "upstream.lock.json").read_text())
    if not url and sha:
        raise ValueError("Provide both a custom URL and SHA-256, or leave both empty")
    if not url:
        url, sha = lock["base_ipa"]["url"], lock["base_ipa"]["sha256"]
    if urllib.parse.urlsplit(url).scheme != "https":
        raise ValueError("The IPA URL must use HTTPS")
    if not re.fullmatch(r"[0-9a-fA-F]{64}", sha):
        raise ValueError("A custom IPA URL requires its exact SHA-256")
    return url, sha.lower()


def download(url: str, expected: str, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "spotify_mod-ui-builder"})
    checksum = hashlib.sha256()
    with urllib.request.urlopen(request, timeout=60) as response, output.open("xb") as stream:
        while chunk := response.read(1024 * 1024):
            stream.write(chunk)
            checksum.update(chunk)
    actual = checksum.hexdigest()
    if actual != expected:
        output.unlink()
        raise ValueError(f"Base IPA checksum mismatch: {actual}")
    print(f"Verified base IPA SHA-256: {actual}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    url, checksum = configuration(os.environ.get("BASE_IPA_URL", ""), os.environ.get("BASE_IPA_SHA256", ""))
    download(url, checksum, args.output)
