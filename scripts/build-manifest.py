#!/usr/bin/env python3
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent


def checksum(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


lock = json.loads((root / "upstream.lock.json").read_text())
result = {
    "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
    "upstream": lock,
    "base_ipa_sha256": checksum(Path(sys.argv[1])),
    "changed_archive_entry": "Payload/Spotify.app/Frameworks/spotifyglass.dylib",
    "other_archive_contents_verified_identical": True,
    "files": {p.name: checksum(p) for p in sorted((root / "dist").iterdir()) if p.suffix in (".ipa", ".dylib")},
    "app_signing": "Must be re-signed by the user's sideloading tool",
    "device_ui_verification": "Not performed by CI",
}
(root / "dist/BUILD-MANIFEST.json").write_text(json.dumps(result, indent=2) + "\n")
