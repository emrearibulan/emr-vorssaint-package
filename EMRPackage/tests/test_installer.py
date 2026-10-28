import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("emr_install", Path(__file__).parents[1] / "tools/install.py")
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.data = installer.metadata()

    def tearDown(self):
        self.temp.cleanup()

    def app(self, folder, identity, marker):
        (folder / "Contents").mkdir(parents=True)
        (folder / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": identity}))
        (folder / "Contents/version.txt").write_text(marker)
        return folder

    def checked(self, args, **kwargs):
        if args[0] == "/usr/bin/ditto":
            shutil.copytree(args[1], args[2], dirs_exist_ok=True)
        return subprocess.CompletedProcess(args, 0)

    def test_real_catalog_is_valid(self):
        self.assertEqual(self.data["features"][0]["name"], "Sys Performance - emr")
        self.assertEqual(len(self.data["upstream"]["commit"]), 40)

    def test_only_official_release_asset_origin_is_accepted(self):
        good = "https://github.com/vorssaint/vorssaint-utils/releases/download/v3.4.2/Vorssaint-3.4.2.dmg"
        self.assertEqual(installer.validate_asset_url(good), good)
        for bad in [good.replace("https:", "http:"), good.replace("github.com", "github.com.evil.test"),
                    good.replace("vorssaint/vorssaint-utils", "somebody/other"),
                    good.replace(".dmg", ".sh"), good.replace("github.com", "user:password@github.com")]:
            with self.subTest(url=bad), self.assertRaises(ValueError):
                installer.validate_asset_url(bad)

    def test_metadata_prevents_app_path_escape(self):
        data = copy.deepcopy(self.data)
        data["app"]["name"] = "../../Other"
        self.write_metadata(data)
        with self.assertRaises(ValueError):
            installer.metadata(self.root)

    def test_metadata_rejects_duplicate_feature_identifiers(self):
        data = copy.deepcopy(self.data)
        data["features"].append(data["features"][0])
        self.write_metadata(data)
        with self.assertRaises(ValueError):
            installer.metadata(self.root)

    def write_metadata(self, data):
        (self.root / "EMRPackage").mkdir(exist_ok=True)
        (self.root / "EMRPackage/package.json").write_text(json.dumps(data))

    def test_dry_run_never_builds_or_downloads(self):
        with patch.object(installer, "application_directory", return_value=self.root), \
             patch.object(installer, "official_installed", return_value=True), \
             patch.object(installer, "run", side_effect=AssertionError("unexpected mutation")), \
             patch.object(installer, "urlopen", side_effect=AssertionError("unexpected network")), \
             patch("sys.argv", ["install.py", "--dry-run", "--with-vorssaint"]), contextlib.redirect_stdout(io.StringIO()):
            installer.main()
        self.assertEqual(list(self.root.iterdir()), [])

    def test_existing_official_app_is_never_replaced(self):
        with patch.object(installer, "official_installed", return_value=True), \
             patch.object(installer, "urlopen", side_effect=AssertionError("unexpected download")), \
             contextlib.redirect_stdout(io.StringIO()):
            installer.install_official(self.root, self.data)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_an_unrelated_destination_is_protected(self):
        folder = self.root / "Applications"
        destination = self.app(folder / "Island Monitor.app", "someone.elses.app", "keep")
        with self.assertRaises(ValueError):
            installer.install_companion(self.root / "source.app", folder, self.data)
        self.assertEqual((destination / "Contents/version.txt").read_text(), "keep")

    def test_successful_upgrade_keeps_unrelated_settings(self):
        folder = self.root / "Applications"
        self.app(folder / "Island Monitor.app", self.data["app"]["bundleIdentifier"], "old")
        settings = folder / "user-settings.json"
        settings.write_text('{"colour":"#45D1FF"}')
        source = self.app(self.root / "source.app", self.data["app"]["bundleIdentifier"], "new")
        with patch.object(installer, "run", side_effect=self.checked), \
             patch.object(installer.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)):
            destination = installer.install_companion(source, folder, self.data)
        self.assertEqual((destination / "Contents/version.txt").read_text(), "new")
        self.assertEqual(settings.read_text(), '{"colour":"#45D1FF"}')

    def test_failed_post_install_verification_restores_previous_app(self):
        folder = self.root / "Applications"
        destination = self.app(folder / "Island Monitor.app", self.data["app"]["bundleIdentifier"], "old")
        source = self.app(self.root / "source.app", self.data["app"]["bundleIdentifier"], "new")
        def failing(args, **kwargs):
            if args[0] == "/usr/bin/codesign" and Path(args[-1]) == destination:
                raise subprocess.CalledProcessError(1, args)
            return self.checked(args, **kwargs)
        with patch.object(installer, "run", side_effect=failing), \
             patch.object(installer.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)), \
             self.assertRaises(subprocess.CalledProcessError):
            installer.install_companion(source, folder, self.data)
        self.assertEqual((destination / "Contents/version.txt").read_text(), "old")

    def test_running_companion_is_not_overwritten(self):
        folder = self.root / "Applications"
        destination = self.app(folder / "Island Monitor.app", self.data["app"]["bundleIdentifier"], "old")
        with patch.object(installer.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), \
             self.assertRaisesRegex(ValueError, "Quit Island Monitor"):
            installer.install_companion(self.root / "source.app", folder, self.data)
        self.assertEqual((destination / "Contents/version.txt").read_text(), "old")


if __name__ == "__main__":
    unittest.main()
