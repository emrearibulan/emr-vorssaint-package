import copy
import importlib.util
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('emr_install', Path(__file__).parents[1] / 'tools/install.py')
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / 'Applications'
        self.folder.mkdir()
        self.backups = self.root / 'backups'
        self.data = installer.metadata()
        self.settings = {installer.HOST_ID: {'otherFeature': True, 'notchEnabled': False},
                         installer.LEGACY_ID: {'notchSystemUnknownColor': '#45D1FF',
                             'notchLauncherEntries': b'[]', 'notchQuickAccessLayout': b'{}',
                             'feature.available.mixer': False, 'notchEnabled': True}}
        self.source = self.app(self.root / 'source.app', installer.HOST_ID, 'new', version=self.data['version'])
        self.host = self.app(self.folder / 'Vorssaint.app', installer.HOST_ID, 'old')
        self.legacy = self.app(self.folder / 'Island Monitor.app', installer.LEGACY_ID, 'legacy')

    def app(self, path, identity, marker, version=None):
        (path / 'Contents').mkdir(parents=True)
        info = {'CFBundleIdentifier': identity}
        if version:
            info['EMRPackageVersion'] = version
        (path / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        (path / 'Contents/marker').write_text(marker)
        return path

    def checked(self, args, **kwargs):
        if args[0] == '/usr/bin/ditto':
            shutil.copytree(args[-2], args[-1], dirs_exist_ok=True)
        return subprocess.CompletedProcess(args, 0)

    def write_settings(self, domain, settings, directory):
        self.settings[domain] = copy.deepcopy(settings)

    def install(self, runner=None):
        with patch.object(installer, 'run', side_effect=runner or self.checked), \
             patch.object(installer, 'ensure_stopped'), \
             patch.object(installer, 'read_preferences', side_effect=lambda domain: copy.deepcopy(self.settings[domain])), \
             patch.object(installer, 'write_preferences', side_effect=self.write_settings):
            return installer.install_app(self.source, self.folder, self.data, migrate=True, backup_root=self.backups)

    def test_catalog_has_one_vorssaint_identity(self):
        self.assertEqual(self.data['app']['bundleIdentifier'], installer.HOST_ID)
        self.assertEqual(self.data['architecture'], 'integrated-source-addon')

    def test_migration_keeps_host_profile_and_imports_only_emr_choices(self):
        self.install()
        self.assertEqual(self.settings[installer.HOST_ID]['notchSystemUnknownColor'], '#45D1FF')
        self.assertFalse(self.settings[installer.HOST_ID]['notchEnabled'])
        self.assertNotIn('feature.available.mixer', self.settings[installer.HOST_ID])
        self.assertEqual((self.host / 'Contents/marker').read_text(), 'new')
        self.assertFalse(self.legacy.exists())
        backup = next(self.backups.iterdir())
        self.assertEqual((backup / 'Vorssaint.app/Contents/marker').read_text(), 'old')
        self.assertEqual((backup / 'Island Monitor.app/Contents/marker').read_text(), 'legacy')
        self.assertFalse(backup.stat().st_mode & 0o077)

    def test_existing_host_emr_choices_win(self):
        current = {'notchSystemUnknownColor': '#AABBCC', 'notchLauncherEntries': b'host', 'notchQuickAccessLayout': b'host-layout'}
        result = installer.migrated_preferences(current, self.settings[installer.LEGACY_ID])
        self.assertEqual(result, current)
        self.assertIsNot(result, current)

    def test_default_migration_does_not_import_onboarding_or_feature_gates(self):
        self.assertEqual(installer.migrated_preferences(None, {'hasOnboarded': True, 'notchEnabled': True}), {})

    def test_post_install_failure_restores_app_and_preferences(self):
        before = copy.deepcopy(self.settings)
        def failing(args, **kwargs):
            if args[0] == '/usr/bin/codesign' and Path(args[-1]) == self.host:
                raise subprocess.CalledProcessError(1, args)
            return self.checked(args, **kwargs)
        with self.assertRaises(subprocess.CalledProcessError):
            self.install(failing)
        self.assertEqual((self.host / 'Contents/marker').read_text(), 'old')
        self.assertEqual((self.legacy / 'Contents/marker').read_text(), 'legacy')
        self.assertEqual(self.settings, before)

    def test_preference_import_failure_restores_both_apps(self):
        calls = []
        def failing(domain, settings, directory):
            calls.append(settings)
            if len(calls) == 1:
                raise OSError('preference write failed')
        with patch.object(self, 'write_settings', side_effect=failing), self.assertRaises(OSError):
            self.install()
        self.assertEqual((self.host / 'Contents/marker').read_text(), 'old')
        self.assertTrue(self.legacy.exists())
        self.assertEqual(calls[-1], self.settings[installer.HOST_ID])

    def test_legacy_retirement_needs_explicit_migration_flag(self):
        with self.assertRaisesRegex(ValueError, 'migrate-island-monitor'):
            installer.preflight(self.folder, False)
        self.assertTrue(self.host.exists())
        self.assertTrue(self.legacy.exists())

    def test_foreign_app_is_not_replaced(self):
        (self.host / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'other.app'}))
        with self.assertRaisesRegex(ValueError, 'unrelated'):
            self.install()
        self.assertFalse(self.backups.exists())

    def test_wrong_built_version_is_rejected(self):
        self.data['version'] = '9.9.9'
        with self.assertRaisesRegex(ValueError, 'does not match'):
            self.install()
        self.assertFalse(self.backups.exists())

    def test_running_host_blocks_before_replacement(self):
        with patch.object(installer.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)), \
             self.assertRaisesRegex(ValueError, 'Quit Vorssaint'):
            installer.ensure_stopped(self.host, 'Vorssaint')

    def test_process_inspection_failure_does_not_count_as_stopped(self):
        with patch.object(installer.subprocess, 'run', return_value=subprocess.CompletedProcess([], 3)), \
             self.assertRaisesRegex(ValueError, 'Could not check'):
            installer.ensure_stopped(self.host, 'Vorssaint')

    def test_metadata_rejects_path_escape(self):
        data = copy.deepcopy(self.data)
        data['app']['name'] = '../../Other'
        (self.root / 'EMRPackage').mkdir()
        (self.root / 'EMRPackage/package.json').write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            installer.metadata(self.root)

    def test_missing_domain_is_allowed_but_other_export_failures_abort(self):
        missing = subprocess.CompletedProcess([], 1, stdout=b'', stderr=b'Domain does not exist')
        with patch.object(installer.subprocess, 'run', return_value=missing):
            self.assertIsNone(installer.read_preferences('test'))
        denied = subprocess.CompletedProcess([], 1, stdout=b'', stderr=b'Permission denied')
        with patch.object(installer.subprocess, 'run', return_value=denied), self.assertRaises(ValueError):
            installer.read_preferences('test')

    def test_mac_empty_export_does_not_turn_missing_domain_into_existing_domain(self):
        missing = subprocess.CompletedProcess([], 1, stdout=b'', stderr=b'Domain does not exist')
        with patch.object(installer.subprocess, 'run', return_value=missing) as command:
            self.assertIsNone(installer.read_preferences('missing'))
            self.assertEqual(command.call_count, 1)
            self.assertEqual(command.call_args.args[0][1], 'read')

    def test_existing_domain_is_exported_after_existence_probe(self):
        results = [subprocess.CompletedProcess([], 0, stdout=b'{existing = 1;}', stderr=b''),
                   subprocess.CompletedProcess([], 0, stdout=plistlib.dumps({'existing': True}), stderr=b'')]
        with patch.object(installer.subprocess, 'run', side_effect=results):
            self.assertEqual(installer.read_preferences('existing'), {'existing': True})

    def test_new_install_with_no_host_or_legacy(self):
        shutil.rmtree(self.host)
        shutil.rmtree(self.legacy)
        self.settings[installer.HOST_ID] = None
        self.install()
        self.assertTrue(self.host.is_dir())
        self.assertEqual(self.settings[installer.HOST_ID], {})


if __name__ == '__main__':
    unittest.main()
