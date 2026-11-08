import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("download_base", ROOT / "scripts/download-base.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DownloadConfigTests(unittest.TestCase):
    def test_default_matches_pinned_release(self):
        expected = json.loads((ROOT / "upstream.lock.json").read_text())["base_ipa"]
        self.assertEqual(module.configuration("", ""), (expected["url"], expected["sha256"]))

    def test_custom_requires_checksum_and_https(self):
        for url, sha in (("https://example.com/base.ipa", ""), ("http://example.com/base.ipa", "a" * 64), ("", "a" * 64)):
            with self.assertRaises(ValueError):
                module.configuration(url, sha)

    def test_custom_checksum_normalized(self):
        self.assertEqual(module.configuration("https://example.com/base.ipa", "A" * 64),
                         ("https://example.com/base.ipa", "a" * 64))
