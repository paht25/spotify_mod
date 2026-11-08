import importlib.util
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/repack-ui-ipa.py"
spec = importlib.util.spec_from_file_location("repack_ui", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RepackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ipa = self.root / "original.ipa"
        self.dylib = self.root / "built.dylib"
        self.output = self.root / "updated.ipa"
        self.dylib.write_bytes(struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 6, 0, 0, 0, 0))
        self.entries = {
            "Payload/Spotify.app/Spotify": b"original executable",
            "Payload/Spotify.app/Info.plist": b"original plist",
            "Payload/Spotify.app/Frameworks/spotifyglass.dylib": b"old UI library",
            "Payload/Spotify.app/PlugIns/Widget.appex/Widget": b"original extension",
            "Payload/Spotify.app/icon.png": b"original icon",
        }
        with zipfile.ZipFile(self.ipa, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.comment = b"original archive comment"
            for name, data in self.entries.items():
                archive.writestr(name, data)

    def test_only_ui_library_changes(self):
        original = self.ipa.read_bytes()
        target = module.repack(self.ipa, self.dylib, self.output)
        self.assertEqual(self.ipa.read_bytes(), original)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.namelist(), list(self.entries))
            self.assertEqual(archive.comment, b"original archive comment")
            for name, data in self.entries.items():
                self.assertEqual(archive.read(name), self.dylib.read_bytes() if name == target else data)

    def test_refuses_to_overwrite_inputs_or_existing_output(self):
        with self.assertRaises(ValueError):
            module.repack(self.ipa, self.dylib, self.ipa)
        self.output.write_bytes(b"previous build")
        with self.assertRaises(FileExistsError):
            module.repack(self.ipa, self.dylib, self.output)
        self.assertEqual(self.output.read_bytes(), b"previous build")

    def test_rejects_uncompiled_or_wrong_platform_replacement(self):
        for invalid in (b"source code", struct.pack("<8I", 0xFEEDFACF, 7, 0, 6, 0, 0, 0, 0)):
            self.dylib.write_bytes(invalid)
            with self.assertRaises(ValueError):
                module.repack(self.ipa, self.dylib, self.output)
            self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
