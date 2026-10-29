#!/usr/bin/env python3
"""Build and install Vorssaint with emr, retaining the host's settings."""
import argparse
import copy
import datetime
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
HOST_ID = 'com.vorssaint.utils'
LEGACY_ID = 'local.emre.islandmonitor.dev'
EMR_KEYS = ('notchSystemUnknownColor', 'notchLauncherEntries', 'notchQuickAccessLayout')


def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)


def metadata(root=ROOT):
    data = json.loads((root / 'EMRPackage/package.json').read_text())
    if data.get('schemaVersion') != 1 or not re.fullmatch(r'\d+\.\d+\.\d+', data.get('version', '')):
        raise ValueError('Unsupported package metadata')
    if data.get('architecture') != 'integrated-source-addon' or data.get('app') != {
        'name': 'Vorssaint', 'executable': 'Vorssaint', 'bundleIdentifier': HOST_ID
    }:
        raise ValueError('Expected the integrated Vorssaint source package, not a companion')
    if data['upstream']['repository'] != 'vorssaint/vorssaint-utils':
        raise ValueError('Unexpected upstream repository')
    ids = [feature['id'] for feature in data['features']]
    if len(ids) != len(set(ids)) or any(not re.fullmatch(r'[a-z0-9-]+', value) for value in ids):
        raise ValueError('Feature identifiers must be unique and stable')
    return data


def app_info(app):
    return plistlib.loads((app / 'Contents/Info.plist').read_bytes())


def check_identity(app, expected):
    if app.exists() and app_info(app).get('CFBundleIdentifier') != expected:
        raise ValueError('An unrelated application occupies ' + str(app))


def ensure_stopped(app, executable):
    pattern = '^' + re.escape(str(app / 'Contents/MacOS' / executable)) + r'([[:space:]]|$)'
    result = subprocess.run(['/usr/bin/pgrep', '-f', pattern], capture_output=True)
    if result.returncode == 0:
        raise ValueError('Quit ' + app.stem + ' completely, then rerun this command. No installation changes were made.')
    if result.returncode != 1:
        raise ValueError('Could not check whether ' + app.stem + ' is running')


def missing_domain(stderr, domain):
    diagnostic = stderr.lower()
    return (b'does not exist' in diagnostic or
            ("domain '" + domain.lower() + "' not found").encode() in diagnostic)


def read_preferences(domain):
    # macOS may export a nonexistent domain as an empty plist with exit 0.
    # Probe existence separately so backups and rollback record it correctly.
    probe = subprocess.run(['/usr/bin/defaults', 'read', domain], capture_output=True)
    if probe.returncode:
        if missing_domain(probe.stderr, domain):
            return None
        raise ValueError('Cannot inspect preferences for ' + domain)
    result = subprocess.run(['/usr/bin/defaults', 'export', domain, '-'], capture_output=True)
    if result.returncode:
        raise ValueError('Cannot back up preferences for ' + domain)
    return plistlib.loads(result.stdout)


def write_preferences(domain, settings, directory):
    if settings is None:
        result = subprocess.run(['/usr/bin/defaults', 'delete', domain], capture_output=True)
        if result.returncode and not missing_domain(result.stderr, domain):
            raise ValueError('Cannot restore the absent preferences domain')
        return
    path = directory / (domain + '.import.plist')
    path.write_bytes(plistlib.dumps(settings))
    run(['/usr/bin/defaults', 'import', domain, path], capture_output=True)


def migrated_preferences(current, legacy):
    """Host choices win. Never import the legacy monitor-only feature profile."""
    result = copy.deepcopy(current or {})
    for key in EMR_KEYS:
        if key not in result and key in legacy:
            result[key] = copy.deepcopy(legacy[key])
    return result


def preflight(folder, migrate):
    host, legacy = folder / 'Vorssaint.app', folder / 'Island Monitor.app'
    check_identity(host, HOST_ID)
    check_identity(legacy, LEGACY_ID)
    if legacy.exists() and not migrate:
        raise ValueError('Island Monitor is installed. Use --migrate-island-monitor to back up and retire it while importing emr choices.')
    ensure_stopped(host, 'Vorssaint')
    ensure_stopped(legacy, 'IslandMonitor')


def install_app(source, folder, data, *, migrate=False, backup_root=None):
    preflight(folder, migrate)
    host, legacy = folder / 'Vorssaint.app', folder / 'Island Monitor.app'
    info = app_info(source)
    if info.get('CFBundleIdentifier') != HOST_ID or info.get('EMRPackageVersion') != data['version']:
        raise ValueError('The built app does not match this integrated package')
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', source])
    current = read_preferences(HOST_ID)
    old_choices = (read_preferences(LEGACY_ID) or {}) if migrate and legacy.exists() else {}
    updated = migrated_preferences(current, old_choices) if migrate else current
    backup_root = backup_root or Path.home() / 'Library/Application Support/emr/backups.noindex'
    backup = backup_root / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ-') + uuid.uuid4().hex[:8])
    backup.mkdir(parents=True, mode=0o700)
    os.chmod(backup, 0o700)
    (backup / 'preferences.plist').write_bytes(plistlib.dumps(current or {}))
    (backup / 'preferences-state.json').write_text(json.dumps({'domainExisted': current is not None}))
    if old_choices:
        (backup / 'island-monitor-preferences.plist').write_bytes(plistlib.dumps(old_choices))
    for app in [host] + ([legacy] if migrate else []):
        if app.exists():
            run(['/usr/bin/ditto', '--noextattr', '--noqtn', app, backup / app.name])
    folder.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.emr-install-', dir=folder) as temporary:
        temporary = Path(temporary)
        staged, previous, retired = temporary / host.name, temporary / 'previous.app', temporary / 'retired.app'
        run(['/usr/bin/ditto', '--noextattr', '--noqtn', source, staged])
        run(['/usr/bin/codesign', '--verify', '--deep', '--strict', staged])
        if host.exists():
            host.rename(previous)
        try:
            staged.rename(host)
            run(['/usr/bin/codesign', '--verify', '--deep', '--strict', host])
            if updated != current:
                write_preferences(HOST_ID, updated, backup)
            if migrate and legacy.exists():
                legacy.rename(retired)
        except Exception:
            if host.exists():
                shutil.rmtree(host)
            if previous.exists():
                previous.rename(host)
            if retired.exists():
                retired.rename(legacy)
            write_preferences(HOST_ID, current, backup)
            raise
    print('Backup:', backup)
    print('Installed:', host)
    if migrate:
        print('Island Monitor retired. Host settings retained; existing emr choices take priority.')
    return host


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--migrate-island-monitor', action='store_true')
    parser.add_argument('--no-launch', action='store_true')
    parser.add_argument('--build-only', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    data = metadata()
    system, user = Path('/Applications'), Path.home() / 'Applications'
    def has_app(directory):
        return any((directory / name).exists() for name in ('Vorssaint.app', 'Island Monitor.app'))
    folder = system if has_app(system) else user if has_app(user) else system if os.access(system, os.W_OK) else user
    other = Path.home() / 'Applications' if folder == Path('/Applications') else Path('/Applications')
    if (other / 'Vorssaint.app').exists() or (other / 'Island Monitor.app').exists():
        raise ValueError('A host or legacy app exists in the other Applications folder. Consolidate installations before updating.')
    print('emr package', data['version'], 'inside Vorssaint; destination:', folder / 'Vorssaint.app', flush=True)
    if args.dry_run:
        print('Migration:', args.migrate_island_monitor, '; no apps or settings will be changed.')
        return
    if platform.system() != 'Darwin' or platform.machine() != 'arm64' or int(platform.mac_ver()[0].split('.')[0]) < 14:
        raise ValueError('Requires an Apple Silicon Mac running macOS 14 or newer')
    if not args.build_only:
        preflight(folder, args.migrate_island_monitor)
    run(['/bin/zsh', ROOT / 'build-emr.sh'], cwd=ROOT)
    source = ROOT / 'build/stage.noindex/Vorssaint.app'
    run([source / 'Contents/MacOS/Vorssaint', '--selftest'])
    if args.build_only:
        print('Built:', source)
        return
    installed = install_app(source, folder, data, migrate=args.migrate_island_monitor)
    print('Use emr source updates to retain your additions; official binary installation would remove them.')
    if not args.no_launch:
        run(['/usr/bin/open', installed])


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit('Installation stopped: ' + str(error))
